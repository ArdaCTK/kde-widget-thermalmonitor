#!/bin/bash
set -e
WIDGET_ID="com.arda.thermalmonitor"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -d "/var/home/$(whoami)" ] && BASE="/var/home/$(whoami)/.local/share/plasma/plasmoids" || BASE="$HOME/.local/share/plasma/plasmoids"
TARGET="$BASE/$WIDGET_ID"

echo "→ Removing old installation..."
rm -rf "$TARGET"
mkdir -p "$TARGET/contents/ui" "$TARGET/contents/code" "$TARGET/contents/config"

echo "→ Copying files..."
cp "$SRC/metadata.json"                         "$TARGET/"
cp "$SRC/contents/ui/main.qml"                  "$TARGET/contents/ui/"
cp "$SRC/contents/ui/ConfigGeneral.qml"         "$TARGET/contents/ui/"
cp "$SRC/contents/config/config.qml"            "$TARGET/contents/config/"
cp "$SRC/contents/config/main.xml"              "$TARGET/contents/config/"
cp "$SRC/contents/code/thermal_backend.py"      "$TARGET/contents/code/"
chmod +x "$TARGET/contents/code/thermal_backend.py"

echo "→ Verifying backend..."
python3 "$TARGET/contents/code/thermal_backend.py" > /tmp/thermal_test.json 2>&1
if python3 -c "import json,sys; d=json.load(open('/tmp/thermal_test.json')); print('  CPU:', d.get('cpu'), '°C |  GPU1:', d.get('gpu1'), '°C')"; then
    echo "  ✓ Backend OK"
else
    echo "  ⚠ Backend returned no data (may still work on your hardware)"
fi

echo ""
echo "✓ Installed to: $TARGET"
echo ""
echo "To reload Plasma:"
echo "  nohup plasmashell --replace > /dev/null 2>&1 & disown"
echo ""
echo "Then: Right-click panel → Add Widgets → Thermal Monitor"
echo "      Right-click widget → Configure to adjust settings"
