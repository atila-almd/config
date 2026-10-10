#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
python3 - "$repo_dir" <<'PY'
import importlib.util,pathlib,sys,tempfile,shutil
root=pathlib.Path(sys.argv[1])
spec=importlib.util.spec_from_file_location('profiles',root/'scripts/render-system-definition.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
vm=m.compose('vm');physical=m.compose('physical')
assert 'virtualbox-guest-utils' in vm['packages'] and 'vboxservice' in vm['services']
assert 'virtualbox-guest-utils' not in physical['packages'] and 'vboxservice' not in physical['services']
assert 'amd-ucode' in physical['packages'] and 'nvidia-open-dkms' in physical['packages']
assert not any(p.startswith('nvidia') for p in vm['packages'])
assert len(physical['packages'])==len(set(physical['packages']))
with tempfile.TemporaryDirectory() as t:
    m.ROOT=pathlib.Path(t);(m.ROOT/'profiles').mkdir()
    shutil.copy(root/'system.yaml',m.ROOT/'system.yaml')
    shutil.copy(root/'profiles/physical.yaml.example',m.ROOT/'profiles/physical.yaml')
    for name in ['physical','../physical','unknown']:
        try:m.compose(name)
        except ValueError:pass
        else:raise AssertionError('accepted unapproved/invalid profile '+name)
    (m.ROOT/'profiles/physical.yaml').write_text('profile: physical\nready: true\nready: false\nhardware: {cpu: example}\n')
    try:m.compose('physical')
    except ValueError as e:assert 'duplicate YAML key' in str(e)
    else:raise AssertionError('accepted duplicate-key profile')
print('Machine Profile isolation and fail-closed input tests passed.')
PY
