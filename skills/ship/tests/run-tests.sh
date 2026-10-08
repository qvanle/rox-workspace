#!/usr/bin/env bash
set -euo pipefail
skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$skill_dir" <<'PY'
import os, sys, subprocess, tempfile, time
from pathlib import Path
script=Path(sys.argv[1])/'scripts/ship-status.sh'
passed=failed=0
sha='a'*40; digest='sha256:'+'b'*64
with tempfile.TemporaryDirectory(prefix='ship-test-') as temporary:
    root=Path(temporary); fake=root/'roxctl'; log=root/'calls.log'
    fake.write_text('''#!/usr/bin/env python3
import os,sys,json,time
args=sys.argv[1:]
with open(os.environ['TEST_LOG'],'a') as log: log.write(' '.join(args)+'\\n')
assert args[0]=='platform'
scenario=os.environ.get('TEST_SCENARIO','green')
commands={'codebase':['status --repo --commit --remote --json'],
          'ci':['pipeline list --repo --commit --json'],
          'registry':['image digest --service --commit --json'],
          'cd':['app show APP --json'],
          'kube':['pod list -n --not-ready --json']}
if args[-1]=='--help':
    if scenario=='unknown':
        print('Usage: roxctl platform '+args[1]+' [FLAGS]\\n--help')
    else:
        for command in commands[args[1]]:
            if scenario=='unknown_flag': command=command.replace('--commit','')
            print('Usage: roxctl platform '+args[1]+' '+command+'\\n--help')
    sys.exit(0)
if scenario=='unknown' or (scenario=='unknown_flag' and args[1] in ('codebase','ci','registry')): raise AssertionError('unknown contract executed')
sha='a'*40; digest='sha256:'+'b'*64
if scenario=='timeout': time.sleep(.3)
if args[1]=='codebase':
    data={'landed':scenario!='remote_only','commit':sha,'remote':'internal'}
elif args[1]=='ci':
    data={'repo':os.environ.get('ROX_SHIP_REPO','iap'),'commit':sha,
          'status':'running' if scenario=='running' else 'none' if scenario=='no_pipeline' else 'failure' if scenario=='pipeline_fail' else 'success'}
elif args[1]=='registry': data={'digest':None if scenario=='no_image' else digest,'commit':sha}
elif args[1]=='cd':
    data={'status':{'sync':{'status':'OutOfSync' if scenario=='hook_fail' else 'Synced'},
                   'health':{'status':'Progressing' if scenario=='argo_running' else 'Healthy'},
                   'operationState':{'phase':'Running' if scenario=='argo_running' else 'Failed' if scenario=='hook_fail' else 'Succeeded'}}}
elif args[1]=='kube': data={'items':[{'status':{'reason':'CrashLoopBackOff'}}] if scenario=='pod_fail' else []}
else: raise AssertionError('unapproved command')
if scenario=='malformed': print('DO_NOT_EMIT_test_secret_92863')
elif scenario=='wrong_commit':
    if isinstance(data,dict) and 'commit' in data: data['commit']='c'*40
    print(json.dumps(data))
else: print(json.dumps(data))
''')
    fake.chmod(0o755)
    manifest=root/'manifest'
    for service in ('iap','agent'):
        for suffix in ('','-staging'):
            overlay=manifest/'clusters/rum'/(service+suffix)
            overlay.mkdir(parents=True)
            (overlay/'kustomization.yaml').write_text('images:\n  - name: app\n    digest: '+digest+'\n')
    def check(name, scenario='green', expected=0, includes=(), args=('iap',), override=None, absent=()):
        global passed,failed
        log.write_text('')
        env=dict(os.environ,ROXCTL_BIN=str(fake),ROX_MANIFEST_DIR=str(manifest),ROX_SHIP_COMMIT=sha,
                 TEST_SCENARIO=scenario,TEST_LOG=str(log),ROX_SHIP_PIPELINE_WAIT='0',ROX_SHIP_ARGO_WAIT='0',
                 ROX_SHIP_POLL_SECONDS='.01',ROX_SHIP_COMMAND_TIMEOUT='1')
        if override: env.update(override)
        start=time.monotonic()
        p=subprocess.run(['bash',str(script),*args],env=env,capture_output=True,text=True,timeout=8)
        output=p.stdout+p.stderr
        ok=p.returncode==expected and all(x in output for x in includes) and all(x not in log.read_text() for x in absent)
        ok &= 'DO_NOT_EMIT_test_secret_92863' not in output and time.monotonic()-start<8
        if args and args[0] in ('iap','agent') and len(args) in (1,3) and expected!=2:
            ok &= all('| '+str(i)+' |' in output for i in range(1,10))
        print(('OK' if ok else 'FAIL')+' '+name+('' if ok else ' -- inspect fixture assertions'))
        passed+=ok;failed+=not ok
    check('nine rows and staging digest equality',includes=('staging digest matches registry','smoke convention unresolved'))
    check('tracked remote only stops at checkpoint 1','remote_only',1,('push internal too',),absent=('ci pipeline',))
    check('absent matching pipeline','no_pipeline',1,('pipeline failed or absent',))
    check('missing commit image','no_image',1,('commit image absent',))
    check('failed pipeline stops before registry','pipeline_fail',1,('pipeline failed',),absent=('registry image',))
    path=manifest/'clusters/rum/iap-staging/kustomization.yaml'
    path.write_text('images:\n  - name: app\n    digest: sha256:'+'c'*64+'\n')
    check('green pipeline stale staging digest','green',1,('staging digest mismatch',))
    path.write_text('images:\n  - name: app\n    digest: '+digest+'\n')
    check('failed hook Argo','hook_fail',1,('force-resync',))
    check('distroless pod crash','pod_fail',1,('numeric runAsUser',))
    check('running agent bounded wait','running',0,('WAIT','elapsed','35 minutes'),args=('agent',),override={'ROX_SHIP_REPO':'agent'})
    check('Argo bounded wait','argo_running',0,('ceiling reached',))
    check('unknown help skips reads','unknown',0,('flags unknown',))
    # Only codebase/ci/registry require --commit; cd/kube reads can still run with known contracts.
    check('unknown flag never guessed','unknown_flag',0,('lacks required flags',),absent=('status --repo iap', 'pipeline list --repo iap','image digest --service iap'))
    check('malformed tool output never echoed','malformed',0,('schema unknown',))
    check('wrong commit never accepted','wrong_commit',1,('expected commit not on internal',))
    check('production same digest and health',includes=('production pins equal staging','| 9 | Production | OK'),args=('iap','--env','production'))
    prod=manifest/'clusters/rum/iap/kustomization.yaml'
    prod.write_text('images:\n  - name: app\n    digest: sha256:'+'c'*64+'\n')
    check('production mismatch','green',1,('production digest differs',),args=('iap','--env','production'))
    check('usage no args',expected=2,args=())
    check('usage invalid environment',expected=2,args=('iap','--env','qa'))
    check('missing roxctl',expected=1,includes=('roxctl missing',),override={'ROXCTL_BIN':str(root/'missing')})
    check('bounded slow command','timeout',0,('command wait ceiling',),override={'ROX_SHIP_COMMAND_TIMEOUT':'.08'})
    for line in log.read_text().splitlines():
        assert line.startswith('platform ')
print(f'{passed} passed; {failed} failed (fake ROXCTL_BIN only; no live cluster commands)')
sys.exit(bool(failed))
PY
