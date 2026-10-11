"""Godot may exit zero despite script parse errors: inspect output as well."""
from pathlib import Path
import subprocess, sys
root = Path(__file__).resolve().parents[1]
result = subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'godot', '--headless', '--path', str(root), '--editor', '--import', '--quit'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
print(result.stdout)
(root / 'build').mkdir(exist_ok=True)
(root / 'build' / 'import.log').write_text(result.stdout)
raise SystemExit(1 if result.returncode or 'SCRIPT ERROR' in result.stdout or 'ERROR:' in result.stdout else 0)
