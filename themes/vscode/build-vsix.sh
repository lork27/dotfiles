#!/usr/bin/env bash
# Rebuild yorha-<version>.vsix from the source in this directory.
# Run this after editing package.json or themes/*.json, then commit the
# resulting vsix next to it (install.sh installs that packaged file).
set -euo pipefail

cd "$(dirname "$0")"

version="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' yorha-theme/package.json | head -1)"
out="yorha-${version}.vsix"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/extension" "$stage/_rels"
cp yorha-theme/extension.vsixmanifest "$stage/"
cp yorha-theme/package.json "$stage/extension/"
cp -r yorha-theme/themes "$stage/extension/"

cat > "$stage/_rels/.rels" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Name="xmlmanifest" Target="extension.vsixmanifest" Type="vsic/manifest"/>
  <Relationship Name="manifest" Target="extension/package.json" Type="vsic/manifest"/>
</Relationships>
EOF

cat > "$stage/[Content_Types].xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json"/>
  <Default Extension="vsixmanifest" ContentType="text/xml"/>
</Types>
EOF

rm -f "$out"
out_abs="$PWD/$out"
(
  cd "$stage"
  zip -X -q "$out_abs" \
    '[Content_Types].xml' '_rels/.rels' 'extension.vsixmanifest' \
    'extension/package.json' 'extension/themes/yorha-light-color-theme.json' 'extension/themes/yorha-dark-color-theme.json'
)

echo "built $out"
