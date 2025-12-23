#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $(basename "$0") <input_image_path> [output_png_path]"
  echo "Example: $(basename "$0") ./appicon_source.jpg ./AppIcon-1024.png"
  exit 2
fi

INPUT="$1"
OUTPUT="${2:-./AppIcon-1024.png}"

if [[ ! -f "$INPUT" ]]; then
  echo "Error: input file not found: $INPUT" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC_PNG="$TMPDIR/src.png"
SCALED="$TMPDIR/scaled.png"
OUTDIR="$(cd "$(dirname "$OUTPUT")" && pwd)"
OUTFILE="$OUTDIR/$(basename "$OUTPUT")"

# 1) Convert to PNG first (so downstream ops are consistent)
sips -s format png "$INPUT" --out "$SRC_PNG" >/dev/null

# 2) Read dimensions
read -r W H < <(sips -g pixelWidth -g pixelHeight "$SRC_PNG" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w, h}')
if [[ -z "${W:-}" || -z "${H:-}" ]]; then
  echo "Error: failed to read image dimensions from: $INPUT" >&2
  exit 1
fi

# 3) Scale so BOTH dimensions are >= 1024 (cover), then center-crop to 1024x1024.
#    Compute target size that preserves aspect ratio.
read -r TW TH < <(W="$W" H="$H" python3 - <<'PY'
import math, os
w=int(os.environ["W"]); h=int(os.environ["H"])
target=1024
scale=target/min(w,h)
tw=int(math.ceil(w*scale))
th=int(math.ceil(h*scale))
print(tw, th)
PY
)

sips -z "$TH" "$TW" "$SRC_PNG" --out "$SCALED" >/dev/null
sips --cropToHeightWidth 1024 1024 "$SCALED" --out "$OUTFILE" >/dev/null

# 4) Sanity check output is 1024x1024
read -r OW OH < <(sips -g pixelWidth -g pixelHeight "$OUTFILE" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w, h}')
if [[ "$OW" != "1024" || "$OH" != "1024" ]]; then
  echo "Error: output is not 1024x1024 (got ${OW}x${OH}). Output: $OUTFILE" >&2
  exit 1
fi

echo "Done: $OUTFILE (${OW}x${OH}, png)"

