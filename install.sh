#!/bin/bash

# Configuration Variables
APP_NAME="BooConnect"
APP_DIR="$HOME/.local/share/BooConnect"
AUTOSTART_DIR="$HOME/.config/autostart"
APPLICATIONS_DIR="$HOME/.local/share/applications"

BIN_MAIN="BooConnect"
BIN_TRAY="BooConnectTray"
ICON="AppIcon.svg"
SOUND="Alert.wav"

echo "=========================================================="
echo "              $APP_NAME Installer                         "
echo "=========================================================="
echo ""
echo "[i] DEPENDENCIES INFORMATION"
echo "To ensure $APP_NAME works properly, please make sure"
echo "you have the following packages installed on your system:"
echo "  * openconnect  (Required for the VPN connection)"
echo "  * paplay       (Required for sound notifications)"
echo ""
echo "[i] DESKTOP ENVIRONMENT NOTES"
echo "If you use GNOME, you must install the AppIndicator extension"
echo "to see the Tray Icon. Package name:"
echo "  -> gnome-shell-extension-appindicator"
echo ""
echo "[i] MISSING SOUNDS?"
echo "If you experience missing sounds, install the audio tools:"
echo "  - Arch Linux:    sudo pacman -S libpulse"
echo "  - Fedora:        sudo dnf install pulseaudio-utils"
echo "  - Ubuntu/Debian: sudo apt install pulseaudio-utils"
echo "----------------------------------------------------------"
echo ""

echo ">> Starting installation..."

# 1. Create App Directory
if [ ! -d "$APP_DIR" ]; then
    mkdir -p "$APP_DIR"
    echo "   [+] Created directory: $APP_DIR"
else
    echo "   [*] Directory already exists: $APP_DIR"
fi

# 2. Copy Files
echo ">> Copying application files..."
cp "$BIN_MAIN" "$APP_DIR/" 2>/dev/null || echo "   [!] WARNING: $BIN_MAIN not found!"
cp "$BIN_TRAY" "$APP_DIR/" 2>/dev/null || echo "   [!] WARNING: $BIN_TRAY not found!"
cp "$ICON" "$APP_DIR/" 2>/dev/null || echo "   [!] WARNING: $ICON not found!"
cp "$SOUND" "$APP_DIR/" 2>/dev/null || echo "   [!] WARNING: $SOUND not found!"
echo "   [+] Executables and assets copied successfully."

# 3. Generate vpnc-script.sample
echo ">> Generating vpnc-script.sample..."
cat <<EOF > "$APP_DIR/vpnc-script.sample"
#!/bin/bash
# ==========================================================
# CUSTOM ROUTING SCRIPT (SPLIT TUNNELING)
# ==========================================================
# If you want to use custom routing, rename this file to 
# "vpnc-script" (remove the .sample extension).
#
# Replace the IPs and masks below with your corporate network.
# This script will pass the values to the default system script.

export CISCO_SPLIT_INC=1
export CISCO_SPLIT_INC_0_ADDR=10.0.0.0
export CISCO_SPLIT_INC_0_MASK=255.0.0.0
export CISCO_SPLIT_INC_0_MASKLEN=8

# Execute the default system vpnc-script
. /usr/share/vpnc-scripts/vpnc-script
EOF
chmod +x "$APP_DIR/vpnc-script.sample"
echo "   [+] vpnc-script.sample created."

# 4. Set Permissions
echo ">> Setting executable permissions..."
chmod +x "$APP_DIR/$BIN_MAIN" 2>/dev/null
chmod +x "$APP_DIR/$BIN_TRAY" 2>/dev/null
echo "   [+] Permissions updated."

# 5. Create Desktop Entry (App Menu)
echo ">> Creating Application Menu entry..."
mkdir -p "$APPLICATIONS_DIR"
cat <<EOF > "$APPLICATIONS_DIR/io.github.izsakirobi.booconnect.desktop"
[Desktop Entry]
Name=BooConnect
Comment=GUI client for OpenConnect VPN
Exec=$APP_DIR/$BIN_MAIN
Icon=$APP_DIR/$ICON
Terminal=false
Type=Application
Categories=Network;Utility;
EOF
echo "   [+] Menu icon created."

# 6. Create Autostart Entry (System Tray)
echo ">> Configuring Autostart for the System Tray..."
if [ -f "$APP_DIR/$BIN_TRAY" ]; then
    mkdir -p "$AUTOSTART_DIR"
    cat <<EOF > "$AUTOSTART_DIR/io.github.izsakirobi.booconnect.tray.desktop"
[Desktop Entry]
Name=BooConnect Tray
Comment=BooConnect VPN Status Indicator
Exec=$APP_DIR/$BIN_TRAY
Icon=$APP_DIR/$ICON
Terminal=false
Type=Application
X-GNOME-Autostart-enabled=true
EOF
    echo "   [+] Autostart entry created."
else
    echo "   [-] Tray application missing, skipping autostart configuration."
fi

echo ""
echo "=========================================================="
echo "   ✅ Installation completed successfully!"
echo "   You can now launch $APP_NAME from your app menu."
echo "=========================================================="
echo ""

# Wait for user input before exiting
read -n 1 -s -r -p "Press any key to exit..."
echo ""

