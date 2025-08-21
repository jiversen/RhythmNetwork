#!/bin/bash
set -e

echo "Generating build fingerprint..."

# Locate the fingerprinted header
HEADER_FILE=$(grep -rl '// @BUILD_FINGERPRINT' "$SRCROOT" --include="*.h" | head -n 1)

if [ -z "$HEADER_FILE" ]; then
    echo "No header marked with // @BUILD_FINGERPRINT found."
    exit 1
fi

BASENAME="BuildFingerprint"
HEADER_OUT="$SRCROOT/${BASENAME}.h"
SOURCE_OUT="$SRCROOT/${BASENAME}.m"

# Metadata
# TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
# USE COMMIT TIME, fallback to date
TIMESTAMP=$(git -C "$SRCROOT" log -1 --date=format:'%Y-%m-%d %H:%M:%S' --format='%ad' 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")
COMMIT=$(git -C "$SRCROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
BRANCH=$(git -C "$SRCROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
COMMIT_MSG=$(git -C "$SRCROOT" log -1 --pretty=format:%s 2>/dev/null || echo "no commit message")
DIRTY=""
if [[ -n $(git -C "$SRCROOT" status --porcelain 2>/dev/null) ]]; then
    DIRTY=" (with uncommitted changes)"
fi

# Header file
cat > "$HEADER_OUT" <<EOF
// Auto-generated. Do not edit.

#import <Foundation/Foundation.h>

extern const char *BuildFingerprint;
EOF

# Source file
{
    echo "// Auto-generated. Do not edit."
    echo '#import "BuildFingerprint.h"'
    echo 'const char *BuildFingerprint = '
    echo "\"=== Build Info ===\\n\""
    echo "\"Timestamp: $TIMESTAMP\\n\""
    echo "\"Branch: $BRANCH\\n\""
    echo "\"Commit: $COMMIT — $COMMIT_MSG$DIRTY\\n\\n\""
	echo "\"Fingerprint ($(basename "$HEADER_FILE")):\\n\\n\""
	#grep '^#define' "$HEADER_FILE" | sed 's/"/\\"/g; s/^/"/; s/$/\\n"/'
	sed 's/"/\\"/g; s/^/"/; s/$/\\n"/' "$HEADER_FILE"
    echo ';'
} > "$SOURCE_OUT"

echo "Fingerprint embedded from: $HEADER_FILE"
echo "Files written:"
echo " - $HEADER_OUT"
echo " - $SOURCE_OUT"
