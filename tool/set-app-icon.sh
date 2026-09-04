#!/usr/bin/env bash
#
# Replace the app icon from one source image.
#
# Reads ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json and
# regenerates exactly the sizes it declares — so it stays correct if the
# catalogue changes — plus the Android mipmaps.
#
# Two things Apple rejects that this handles for you:
#   * an alpha channel on the 1024 marketing icon. Any transparency is
#     flattened onto a solid background (white by default; pass a colour).
#   * a non-square source. It is refused rather than squashed.
#
# iOS applies its own rounded-corner mask, so supply a FULL-BLEED square with
# no rounding and no padding of its own. Artwork with wide margins renders
# small and washed out at 60x60.
#
# Usage:
#   tool/set-app-icon.sh path/to/icon.png [background-hex]
#   tool/set-app-icon.sh ~/Desktop/new-logo.png "#0B4FD8"
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=${1:?usage: tool/set-app-icon.sh <source.png> [background-hex]}
BG=${2:-#FFFFFF}
SET=ios/Runner/Assets.xcassets/AppIcon.appiconset
[ -f "$SRC" ] || { echo "No such file: $SRC" >&2; exit 1; }

W=$(sips -g pixelWidth  "$SRC" | awk '/pixelWidth/{print $2}')
H=$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/{print $2}')
echo "Source: $SRC  ${W}x${H}"
[ "$W" = "$H" ] || { echo "Refusing: the source must be square (got ${W}x${H})." >&2; exit 1; }
[ "$W" -ge 1024 ] || { echo "Refusing: the source must be at least 1024x1024 (got ${W})." >&2; exit 1; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
# Flatten onto an opaque background: the marketing icon must have no alpha.
python3 - "$SRC" "$WORK/base.png" "$BG" <<'PY'
import sys, subprocess
src, out, bg = sys.argv[1], sys.argv[2], sys.argv[3].lstrip('#')
r, g, b = (int(bg[i:i+2], 16) for i in (0, 2, 4))
try:
    from PIL import Image
    im = Image.open(src).convert('RGBA')
    flat = Image.new('RGB', im.size, (r, g, b))
    flat.paste(im, mask=im.split()[3])
    flat.save(out)
    print(f"  flattened onto #{bg} (alpha removed)")
except ImportError:
    # No Pillow: sips can strip alpha by re-encoding without it.
    subprocess.run(['sips', '-s', 'format', 'png', '--matchTo',
                    '/System/Library/ColorSync/Profiles/sRGB Profile.icc',
                    src, '--out', out], check=True, capture_output=True)
    print("  Pillow not installed — used sips; verify the 1024 has no alpha")
PY

echo "Generating iOS sizes declared in Contents.json:"
python3 - "$SET" <<'PY' > "$WORK/sizes.txt"
import json, sys
d = json.load(open(f"{sys.argv[1]}/Contents.json"))
seen = set()
for i in d['images']:
    fn = i.get('filename')
    if not fn or fn in seen: continue
    seen.add(fn)
    base = float(i['size'].split('x')[0])
    px = int(round(base * int(i['scale'].rstrip('x'))))
    print(fn, px)
PY
while read -r name px; do
  sips -s format png -z "$px" "$px" "$WORK/base.png" --out "$SET/$name" >/dev/null
  printf "  %-32s %sx%s\n" "$name" "$px" "$px"
done < "$WORK/sizes.txt"

if [ -d android/app/src/main/res ]; then
  echo "Generating Android mipmaps:"
  for pair in "mipmap-mdpi 48" "mipmap-hdpi 72" "mipmap-xhdpi 96" "mipmap-xxhdpi 144" "mipmap-xxxhdpi 192"; do
    set -- $pair
    d=android/app/src/main/res/$1
    [ -d "$d" ] || mkdir -p "$d"
    sips -s format png -z "$2" "$2" "$WORK/base.png" --out "$d/ic_launcher.png" >/dev/null
    printf "  %-24s %sx%s\n" "$1" "$2" "$2"
  done
fi

echo
echo "Marketing icon check (Apple rejects alpha here):"
sips -g pixelWidth -g pixelHeight -g hasAlpha "$SET/Icon-App-1024x1024@1x.png" | sed 's/^/ /'
echo
echo "Next: bump the +N in pubspec.yaml, then tool/testflight.sh"
