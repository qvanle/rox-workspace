#!/usr/bin/env bash
set -euo pipefail
skill_dir="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$skill_dir" <<'PY'
import sys, subprocess, tempfile
from pathlib import Path
script=Path(sys.argv[1])/'scripts/seal-diff.sh'
passed=failed=0
sentinel='DO_NOT_EMIT_test_secret_92863'
with tempfile.TemporaryDirectory(prefix='seal-secret-test-') as temporary:
    root=Path(temporary)
    source=root/'source.env'; target=root/'output.yaml'
    sealed='kind: SealedSecret\nspec:\n  encryptedData:\n    KEEP: '+sentinel+'\n    ORPHAN: '+sentinel+'\n'
    def check(name, env, yaml=sealed, code=0, includes=()):
        global passed, failed
        source.write_text(env)
        if yaml is None:
            target.unlink(missing_ok=True)
        else:
            target.write_text(yaml)
        p=subprocess.run(['bash',str(script),str(source),str(target)],capture_output=True,text=True)
        output=p.stdout+p.stderr
        ok=p.returncode==code and sentinel not in output and all(x in output for x in includes)
        print(('OK' if ok else 'FAIL')+' '+name+('' if ok else ' -- inspect sanitized assertion'))
        passed+=ok; failed+=not ok
    check('added removed unchanged names',f'KEEP={sentinel}\nADDED={sentinel}\n',includes=('Added','ADDED','Removed','ORPHAN','Unchanged','KEEP'))
    check('first seal',f'NEW={sentinel}\n',None,includes=('first seal','NEW'))
    check('empty assignment',f'KEEP={sentinel}\nEMPTY=\n',code=1,includes=('empty value','EMPTY'))
    check('empty quoted assignment',f'KEEP={sentinel}\nEMPTY=""\n',code=1)
    check('empty single quotes',f"KEEP={sentinel}\nEMPTY=''\n",code=1)
    check('whitespace-only value',f'KEEP={sentinel}\nEMPTY=   \n',code=1)
    check('duplicate',f'KEEP={sentinel}\nKEEP={sentinel}\n',code=1,includes=('duplicate key','KEEP'))
    check('whitespace key',f'BAD KEY={sentinel}\n',code=1,includes=('whitespace',))
    check('leading whitespace key',f' KEEP={sentinel}\n',code=1)
    check('unsafe key hidden',f'{sentinel}!=value\n',code=1)
    check('no assignment hidden',sentinel+'\n',code=1)
    check('comments exports embedded equals',f'# {sentinel}\nexport KEEP="{sentinel}=suffix" # comment\n',includes=('KEEP',))
    check('literal leading hash',f'KEEP=#{sentinel}\n')
    check('escaped quote remains literal',f'KEEP="{sentinel}\\\"suffix"\n')
    check('comment is empty',f'EMPTY= # {sentinel}\n',code=1)
    check('no keys',f'# {sentinel}\n',code=1)
    check('malformed YAML sanitized',f'KEEP={sentinel}\n','spec: ['+sentinel+'\n',code=1)
    check('plaintext YAML refused',f'KEEP={sentinel}\n','kind: Secret\ndata:\n  KEEP: '+sentinel+'\n',code=1)
    check('duplicate YAML mapping rejected',f'KEEP={sentinel}\n','kind: SealedSecret\nspec:\n  encryptedData:\n    KEEP: '+sentinel+'\n    KEEP: '+sentinel+'\n',code=1)
    check('encrypted key invalid hidden',f'KEEP={sentinel}\n','kind: SealedSecret\nspec:\n  encryptedData:\n    "'+sentinel+'!": ciphertext\n',code=1)
    source.unlink()
    p=subprocess.run(['bash',str(script),str(source),str(target)],capture_output=True,text=True)
    ok=p.returncode==1 and sentinel not in p.stdout+p.stderr
    passed+=ok; failed+=not ok
    print(('OK' if ok else 'FAIL')+' unreadable env')
    p=subprocess.run(['bash',str(script)],capture_output=True,text=True)
    ok=p.returncode==2
    passed+=ok; failed+=not ok
    print(('OK' if ok else 'FAIL')+' usage exit 2')
print(f'{passed} passed; {failed} failed (all cases assert no secret value in stdout/stderr)')
sys.exit(bool(failed))
PY
