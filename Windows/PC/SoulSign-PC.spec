from PyInstaller.utils.hooks import collect_all, collect_submodules
from pathlib import Path
root = Path(SPECPATH)
datas = [(str(root/'assets'), 'assets'), (str(root/'scripts/task.ps1'), 'scripts'),
         (str(root/'src/ipaside_engine/certs'), 'ipaside_engine/certs')]
binaries = [(str(root/'src/ipaside_engine/vendor/zsign.exe'), 'ipaside_engine/vendor')]
hiddenimports = collect_submodules('ipaside_engine')
for package in ('tkinterdnd2', 'pymobiledevice3', 'pytun_pmd3', 'anisette', 'unicorn', 'srp'):
    d, b, h = collect_all(package)
    datas += d; binaries += b; hiddenimports += h
a = Analysis([str(root/'src/soulsign.py')], pathex=[str(root/'src')], binaries=binaries,
             datas=datas, hiddenimports=hiddenimports, excludes=['pytest', 'IPython'])
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name='SoulSign-PC',
          console=False, icon=str(root/'assets/SoulSign.ico'))
coll = COLLECT(exe, a.binaries, a.datas, name='SoulSign-PC')
