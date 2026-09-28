"""Archive tracked working-tree files only, including CI version edits."""
import subprocess, sys, zipfile
from pathlib import Path
root = Path(__file__).resolve().parents[1]
files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode('utf-8').split('\0')
out = Path(sys.argv[1]).resolve()
out.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for name in sorted(set(filter(None, files))):
        path = root / name
        if not path.is_file():
            raise RuntimeError(f'Missing tracked source: {name}')
        if path.resolve() == out:
            raise RuntimeError('Archive output must not be a tracked input')
        archive.write(path, 'SoulSign-source/' + name)
print(f'{out.name}: {out.stat().st_size:,} bytes; no untracked build caches')
