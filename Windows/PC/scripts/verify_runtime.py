from pathlib import Path
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent/'src'))
import tkinter
import tkinterdnd2
import anisette
import srp
import pymobiledevice3
from ipaside_engine import gsa, signing, apps
binary = signing.resolve_zsign()
subprocess.run([binary, '-v'], check=True)
print('SoulSign runtime import and zsign verification passed.')
