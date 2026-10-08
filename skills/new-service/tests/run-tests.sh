#!/usr/bin/env bash
set -euo pipefail
skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$skill_dir" <<'PY'
import sys, os, subprocess, tempfile, shutil, re
from pathlib import Path
import yaml
skill=Path(sys.argv[1]); script=skill/'scripts/syncwave-plan.sh'
passed=failed=0
sentinel='DO_NOT_EMIT_test_secret_92863'
with tempfile.TemporaryDirectory(prefix='new-service-test-') as temporary:
    root=Path(temporary); directory=root/'service'; directory.mkdir()
    fake=root/'kubectl'; log=root/'calls.log'
    fake.write_text('''#!/usr/bin/env python3
import sys,os
from pathlib import Path
args=sys.argv[1:]
assert args[0]=='kustomize' and args[2:]==['--load-restrictor','LoadRestrictionsNone']
Path(os.environ['TEST_LOG']).write_text(' '.join(args))
if os.environ.get('TEST_RENDER_FAIL')=='1':
    print('DO_NOT_EMIT_test_secret_92863',file=sys.stderr)
    sys.exit(1)
print(Path(args[1],'fixture.yaml').read_text())
''')
    fake.chmod(0o755)
    def resource(kind,name,wave=None,namespace='demo',annotations=None,spec=None):
        meta={'name':name,'namespace':namespace,'annotations':annotations or {}}
        if wave is not None: meta['annotations']['argocd.argoproj.io/sync-wave']=str(wave)
        return {'apiVersion':'v1','kind':kind,'metadata':meta,'spec':spec or {}}
    def workload(wave=40,claim='data'):
        return resource('Deployment','demo',wave,spec={'template':{'spec':{'volumes':[{'name':'data','persistentVolumeClaim':{'claimName':claim}}]}}})
    def check(name,docs,code=0,includes=(),render=False,override=None):
        global passed,failed
        (directory/'fixture.yaml').write_text(yaml.safe_dump_all(docs))
        env=dict(os.environ,KUBECTL_BIN=str(fake) if render else str(root/'absent'),TEST_LOG=str(log))
        env.pop('ROX_MANIFEST_DIR',None)
        if override: env.update(override)
        p=subprocess.run(['bash',str(script),str(directory)],env=env,capture_output=True,text=True)
        output=p.stdout+p.stderr
        ok=p.returncode==code and all(x in output for x in includes) and sentinel not in output
        if render and code==0:
            ok &= '--load-restrictor LoadRestrictionsNone' in log.read_text()
        print(('OK' if ok else 'FAIL')+' '+name+('' if ok else ' -- inspect sanitized fixture assertions'))
        passed+=ok;failed+=not ok
    check('PVC later than workload must exit 1',[resource('PersistentVolumeClaim','data',50),workload(40)],1,('FAIL deadlock','move PVC before'))
    check('correct dependency ordering',[resource('PersistentVolumeClaim','data',20),workload()],includes=('no deadlock',))
    check('equal waves need review',[resource('PersistentVolumeClaim','data',40),workload()],includes=('shares workload wave',))
    check('missing wave gets proposed class',[resource('ConfigMap','config')],includes=('has no wave','| 10 | configuration'))
    check('BeforeHookCreation and phase warning',[resource('Job','migration',30,annotations={'argocd.argoproj.io/hook':'PreSync','argocd.argoproj.io/hook-delete-policy':'BeforeHookCreation'})],includes=('BeforeHookCreation','PreSync phase','| 30 | pre-sync-hook'))
    check('PostSync class',[resource('Job','smoke',60,annotations={'argocd.argoproj.io/hook':'PostSync'})],includes=('| 60 | post-sync-hook',))
    check('claims scoped by namespace',[resource('PersistentVolumeClaim','data',50,namespace='other'),workload()],includes=('PVC reference unresolved',))
    check('StatefulSet managed claims',[resource('StatefulSet','db',40,spec={'volumeClaimTemplates':[{'metadata':{'name':'data'},'spec':{'resources':{'requests':{'storage':'1Gi'}}}}]})],includes=('controller-created','workload-managed'))
    check('unknown resource class',[resource('CustomThing','custom',1)],includes=('unknown dependency class',))
    check('invalid wave',[resource('Deployment','demo','invalid')],1,('invalid sync-wave',))
    check('Secret fails without leaking',[resource('Secret','unsafe',10,spec={'value':sentinel})],1,('plaintext Secret',))
    check('ConfigMap values never output',[resource('ConfigMap','config',10,spec={'value':sentinel})])
    check('kubectl renders locally',[resource('PersistentVolumeClaim','data',20),workload()],render=True,includes=('OK local kubectl',))
    check('render failure cannot fall back',[workload()],1,('FAIL local kustomize',),render=True,override={'TEST_RENDER_FAIL':'1'})
    check('empty resource list',[],1,('no resources',))
    # A local kustomization fallback must follow relative base references, not miss the PVC.
    base=root/'base'; base.mkdir()
    (base/'resources.yaml').write_text(yaml.safe_dump_all([resource('PersistentVolumeClaim','data',50),workload()]))
    (base/'kustomization.yaml').write_text('resources:\n  - resources.yaml\n')
    (directory/'kustomization.yaml').write_text('resources:\n  - ../base\nnamespace: demo-staging\n')
    check('fallback follows base and namespace',[],1,('FAIL deadlock','demo-staging'))
    (directory/'kustomization.yaml').unlink()
    # Comparison reads only identities and annotated waves.
    manifest=root/'manifest'; other=manifest/'services/existing'; other.mkdir(parents=True)
    (manifest/'clusters/rum').mkdir(parents=True)
    (other/'resources.yaml').write_text(yaml.safe_dump(resource('ConfigMap','existing',7,spec={'secret':sentinel})))
    original=(other/'resources.yaml').read_bytes()
    check('existing waves comparison read only',[workload()],includes=('services/existing/resources.yaml','| 7 |'),override={'ROX_MANIFEST_DIR':str(manifest)})
    assert (other/'resources.yaml').read_bytes()==original
    p=subprocess.run(['bash',str(script)],capture_output=True,text=True)
    ok=p.returncode==2; passed+=ok;failed+=not ok
    print(('OK' if ok else 'FAIL')+' usage exit 2')
    # Instantiate templates and locally render both overlays when real kubectl is installed.
    replacements={'service':'trace','image-path':'trace','port':'8080','numeric-uid':'1000','numeric-gid':'1000',
                  'staging-image-digest':'b'*64,'production-image-digest':'b'*64,'staging-replicas':'1','production-replicas':'2',
                  'cpu-request':'50m','cpu-limit':'200m','memory-request':'64Mi','memory-limit':'128Mi',
                  'readiness-path':'/health','liveness-path':'/health','storage-size':'1Gi','storage-class':'local-path',
                  'data-mount-path':'/data','hook-phase':'PostSync','hook-wave':'60','hook-executable':'/app/smoke',
                  'hook-purpose':'smoke','purpose':'config','additional-caller-namespace':'monitoring','staging-host':'staging-trace','production-host':'trace'}
    tree=root/'rendered'
    for path in (skill/'templates').rglob('*'):
        if not path.is_file():continue
        rel=str(path.relative_to(skill/'templates')).replace('<service>','trace')
        content=re.sub(r'<([^>]+)>',lambda m:replacements[m[1]],path.read_text())
        dest=tree/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(content)
        if dest.suffix=='.yaml': list(yaml.safe_load_all(content))
    kubectl=shutil.which('kubectl')
    if kubectl:
        for overlay in ('trace','trace-staging'):
            env=dict(os.environ,KUBECTL_BIN=kubectl,ROX_MANIFEST_DIR=str(tree))
            p=subprocess.run(['bash',str(script),str(tree/'clusters/rum'/overlay)],env=env,capture_output=True,text=True,timeout=20)
            ok=p.returncode==0 and 'FAIL' not in p.stdout and 'has no wave' not in p.stdout
            print(('OK' if ok else 'FAIL')+' instantiated '+overlay+' local render and wave plan')
            passed+=ok;failed+=not ok
        kfile=tree/'services/trace/kustomization.yaml'
        kfile.write_text(kfile.read_text().replace('  - deployment.yaml','  - statefulset.yaml\n  - headless-service.yaml'))
        for overlay in ('trace','trace-staging'):
            patch=tree/'clusters/rum'/overlay/'deployment-patch.yaml'
            patch.write_text(patch.read_text().replace('kind: Deployment','kind: StatefulSet'))
            env=dict(os.environ,KUBECTL_BIN=kubectl,ROX_MANIFEST_DIR=str(tree))
            p=subprocess.run(['bash',str(script),str(tree/'clusters/rum'/overlay)],env=env,capture_output=True,text=True,timeout=20)
            ok=p.returncode==0 and 'FAIL' not in p.stdout and 'volumeClaimTemplate/data' in p.stdout
            print(('OK' if ok else 'FAIL')+' instantiated stateful '+overlay+' local render and claims')
            passed+=ok;failed+=not ok
    else:
        print('SKIP instantiated template render: kubectl unavailable; YAML syntax checked')
print(f'{passed} passed; {failed} failed (includes deadlocked PVC exit 1; renders are local only)')
sys.exit(bool(failed))
PY
