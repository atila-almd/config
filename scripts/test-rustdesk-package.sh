#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root" <<'PY'
import importlib.util, pathlib, sys
sys.dont_write_bytecode = True
root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('package_check', root / 'services/rustdesk/check-package.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
fixture = {
    'usr/share/rustdesk/rustdesk': b'\x7fELF',
    '.PKGINFO': b'pkgname = rustdesk-unattended-wayland\narch = x86_64\ndepend = libdrm\ndepend = libglvnd\ndepend = libcap\ndepend = libseccomp\ndepend = libpulse\nprovides = rustdesk\nconflict = rustdesk-bin\n',
    'usr/share/rustdesk/lib/librustdesk.so': b'\x7fELF /usr/lib/rustdesk/libdrmtap.so.0 enable-drm-display-wake',
    'usr/lib/rustdesk/libdrmtap.so.0.5.4': b'\x7fELF libEGL.so.1 eglCreateImageKHR',
    'usr/lib/systemd/system/rustdesk.service': b'ExecStart=/usr/bin/rustdesk --service\nUser=root\n',
    'usr/share/applications/rustdesk.desktop': b'Exec=rustdesk %u',
}
module.validate(fixture.__getitem__)
cases = [
    ('usr/share/rustdesk/rustdesk', b'\x7fELF', b'not an executable'),
    ('.PKGINFO', b'rustdesk-unattended-wayland', b'rustdesk-bin'),
    ('.PKGINFO', b'arch = x86_64', b'arch = aarch64'),
    ('.PKGINFO', b'depend = libglvnd', b'depend = unrelated'),
    ('.PKGINFO', b'depend = libpulse', b'depend = unrelated'),
    ('usr/share/rustdesk/lib/librustdesk.so', b'enable-drm-display-wake', b''),
    ('usr/share/rustdesk/lib/librustdesk.so', b'/usr/lib/rustdesk/libdrmtap.so.0', b''),
    ('usr/lib/rustdesk/libdrmtap.so.0.5.4', b'eglCreateImageKHR', b''),
    ('usr/lib/systemd/system/rustdesk.service', b'User=root', b'User=desktop'),
]
for name, old, new in cases:
    broken = dict(fixture)
    broken[name] = broken[name].replace(old, new)
    try:
        module.validate(broken.__getitem__)
    except AssertionError:
        continue
    raise AssertionError(f'accepted broken artifact: {name}: {old!r}')
print(f'RustDesk artifact rejection tests passed ({len(cases)} failure cases).')
PY
