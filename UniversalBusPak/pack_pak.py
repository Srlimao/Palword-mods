import os
import subprocess

unreal_pak = r"C:\Program Files\Epic Games\UE_5.1\Engine\Binaries\Win64\UnrealPak.exe"
cooked_dir = r"D:\Mods\PalworkdModdingKit\PalworldModdingKit\Saved\Cooked\Windows\Pal\Content\Mods\UniversalBusPak"
output_pak = r"D:\Mods\Palword\UniversalBusPak\UniversalBusPak.pak"
manifest_path = r"D:\Mods\Palword\UniversalBusPak\pak_manifest.txt"

lines = []
for root, dirs, files in os.walk(cooked_dir):
    for f in files:
        full_path = os.path.join(root, f)
        rel_path = os.path.relpath(full_path, cooked_dir).replace("\\", "/")
        mount_path = f"../../../Pal/Content/Mods/UniversalBusPak/{rel_path}"
        lines.append(f'"{full_path}" "{mount_path}"')

with open(manifest_path, "w", encoding="utf-8") as mf:
    mf.write("\n".join(lines) + "\n")

print(f"Created manifest with {len(lines)} files.")
print(f"Packing {output_pak} ...")

cmd = [unreal_pak, output_pak, f"-create={manifest_path}"]
res = subprocess.run(cmd, capture_output=True, text=True)

print("STDOUT:", res.stdout)
print("STDERR:", res.stderr)
if res.returncode == 0:
    print(f"SUCCESS: Created {output_pak}")
else:
    print(f"ERROR: Exit code {res.returncode}")
