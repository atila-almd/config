"""Inspect an Arch artifact without extracting or executing its contents."""
import pathlib
import subprocess
import sys


def validate(read):
    info = read('.PKGINFO').decode()
    fields = {}
    for line in info.splitlines():
        if ' = ' in line:
            key, value = line.split(' = ', 1)
            fields.setdefault(key, []).append(value)
    assert fields.get('pkgname') == ['rustdesk-unattended-wayland'], 'wrong package name'
    assert fields.get('arch') == ['x86_64'], 'wrong architecture'
    for dep in ('libdrm', 'libglvnd', 'libcap', 'libseccomp', 'libpulse'):
        assert dep in fields.get('depend', []), f'missing dependency: {dep}'
    assert 'rustdesk' in fields.get('provides', []), 'missing rustdesk provide'
    assert 'rustdesk-bin' in fields.get('conflict', []), 'missing stock conflict'
    assert read('usr/share/rustdesk/rustdesk').startswith(b'\x7fELF'), 'missing Flutter executable'
    binary = read('usr/share/rustdesk/lib/librustdesk.so')
    assert binary.startswith(b'\x7fELF'), 'RustDesk is not ELF'
    for marker in (b'/usr/lib/rustdesk/libdrmtap.so.0', b'enable-drm-display-wake'):
        assert marker in binary, f'missing compiled feature: {marker!r}'
    library = read('usr/lib/rustdesk/libdrmtap.so.0.5.4')
    assert library.startswith(b'\x7fELF'), 'libdrmtap is not ELF'
    for marker in (b'libEGL.so.1', b'eglCreateImageKHR'):
        assert marker in library, 'libdrmtap lacks EGL backend'
    service = read('usr/lib/systemd/system/rustdesk.service').decode()
    assert 'ExecStart=/usr/bin/rustdesk --service' in service, 'wrong service'
    assert 'User=root' in service, 'capture service must be root'
    assert b'Exec=' in read('usr/share/applications/rustdesk.desktop'), 'missing launcher'


if __name__ == '__main__':
    package = pathlib.Path(sys.argv[1]).resolve(strict=True)
    try:
        validate(lambda name: subprocess.check_output(['bsdtar', '-xOf', str(package), name]))
        links = subprocess.check_output(['bsdtar', '-tvf', str(package),
            'usr/bin/rustdesk', 'usr/lib/rustdesk/libdrmtap.so.0'], text=True)
        assert 'usr/bin/rustdesk -> /usr/share/rustdesk/rustdesk' in links, 'wrong executable link'
        assert 'usr/lib/rustdesk/libdrmtap.so.0 -> libdrmtap.so.0.5.4' in links, 'wrong private library link'
    except (AssertionError, subprocess.CalledProcessError, UnicodeError) as error:
        raise SystemExit(f'Invalid RustDesk package: {error}')
    print('RustDesk package content checks passed (live capture remains unverified).')
