#!/usr/bin/env bash

#  copyVendorLibs.sh
#  RhythmNetwork
#
#  Created by John R. Iversen/CGPT5 on 2025-08-08.
#
set -euo pipefail

# Resolve script directory even if sourced via symlink
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
VENDOR_DIR="$PROJECT_ROOT/ThirdParty/lib"
mkdir -p "$VENDOR_DIR"

# Homebrew "opt" locations (stable paths with current symlink)
BREW_LIB_DIR="/opt/homebrew/lib"

#top level library names -lftdi1 -lusb-1.0
USB_NAME="libusb-1.0.dylib"
FTDI_NAME="libftdi1.dylib"

#get realpaths
USB_PATH=$(realpath "$BREW_LIB_DIR/$USB_NAME")
FTDI_PATH=$(realpath "$BREW_LIB_DIR/$FTDI_NAME")

echo "==> Sourcing from Homebrew:"
echo "    USB : $USB_PATH"
echo "    FTDI: $FTDI_PATH"
echo "==> Vendoring into: $VENDOR_DIR"

# Copy actual files (preserve mode/timestamps). cp is fine for dylibs.
cp -p "$USB_PATH"  "$VENDOR_DIR/"
cp -p "$FTDI_PATH" "$VENDOR_DIR/"

# Update to point now to our copied version
USB_NAME=$(basename ${USB_PATH})
FTDI_NAME=$(basename ${FTDI_PATH})

USB_PATH="$VENDOR_DIR/$USB_NAME"
FTDI_PATH="$VENDOR_DIR/$FTDI_NAME"

echo "==> Rewriting install IDs to @rpath"
install_name_tool -id "@rpath/$USB_NAME"  "$USB_PATH"
install_name_tool -id "@rpath/$FTDI_NAME" "$FTDI_PATH"

echo "==> Rewriting intra‑dylib dependencies to @rpath (remove Homebrew paths)"
# Fix FTDI -> USB reference (and any other /opt/homebrew refs inside the vendored libs)
# This loop rewrites any absolute brew path it finds to @rpath/<basename>
for LIB in "$USB_PATH" "$FTDI_PATH"; do
  while read -r DEP _; do
    if [[ "$DEP" == /opt/homebrew/* ]]; then
      BASE="$(basename "$DEP")"
      if [[ -f "$VENDOR_DIR/$BASE" ]]; then
        echo "    $LIB : $DEP -> @rpath/$BASE"
        install_name_tool -change "$DEP" "@rpath/$BASE" "$LIB"
      else
        echo "    (note) $LIB : depends on $DEP (no vendored copy present)"
      fi
    fi
  done < <(otool -L "$LIB" | tail -n +2 | awk '{print $1}')
done

echo "==> Final linkage (sanity check):"
otool -L "$USB_PATH"
otool -L "$FTDI_PATH"

echo "==> Done. Add these to your project:"
echo "    - $USB_PATH"
echo "    - $FTDI_PATH"
echo
echo "Xcode wiring (once):"
echo "  • Link Binary With Libraries: add both dylibs from ThirdParty/lib"
echo "  • Runpath Search Paths (LD_RUNPATH_SEARCH_PATHS) should include:"
echo "      @executable_path/../Frameworks"
echo "  • Deployment only: Copy Files (Destination: Frameworks) + Code Sign on Copy"
