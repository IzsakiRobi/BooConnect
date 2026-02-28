<p align="center">
<img width="400" height="450" alt="BooConnect_Main" src="https://github.com/user-attachments/assets/5da58987-2940-430c-9bda-0ebdfd806f0e" />
<img width="400" height="450" alt="BooConnect_Config" src="https://github.com/user-attachments/assets/13d113a9-a476-4527-b2b6-d42196e82fd4" />
</p>
<p align="center">
<img width="400" height="320" alt="BooConnect_Token" src="https://github.com/user-attachments/assets/ee65c3ce-670a-4227-bb3b-5e350eed2b0a" />
</p>p

# BooConnect
**BooConnect** is a lightweight, modern GTK4 GUI client designed specifically for **Cisco AnyConnect** VPNs. Powered by the robust `openconnect` engine under the hood, it provides a seamless native desktop experience for Linux users without the hassle of terminal commands or complex system configurations.

## Key Features

* **Tailored for AnyConnect:** A focused, specialized client for Cisco AnyConnect networks.
* **Native GTK4/libadwaita UI:** Beautiful, modern interface that looks great on GNOME and other modern Linux desktops.
* **No Sudoers Modification Required:** Handles `sudo` authentication securely and automatically in the background.
* **2FA / SMS Token Support:** Elegantly handles secondary authentication prompts (Tokens, SMS codes) via a clean GUI dialog.
* **System Tray Indicator:** Unobtrusive background operation with a tray icon to monitor status and easily disconnect.
* **Audio & Desktop Notifications:** Get instant alerts when your VPN connects or disconnects.
* **Split Tunneling Ready:** Built-in support for custom routing via a drop-in `vpnc-script`.

## Prerequisites

Before installing, ensure you have the required packages installed on your system:

**1. Core Dependencies:**
* `openconnect` (The core VPN engine)
* `paplay` (For audio notifications)

**2. Audio Support (if you don't hear notification sounds):**
* **Ubuntu/Debian:** `sudo apt install pulseaudio-utils`
* **Fedora:** `sudo dnf install pulseaudio-utils`
* **Arch Linux:** `sudo pacman -S libpulse`

**3. GNOME Users (Crucial for the Tray Icon):**
Modern GNOME does not display legacy tray icons by default. You **must** install the AppIndicator extension:
* Install: `gnome-shell-extension-appindicator` (AppIndicator and KStatusNotifierItem Support extension)
* Enable it via the GNOME Extensions app.

## Installation

If you have downloaded the compiled binaries along with the assets:

1. Open your terminal in the directory containing the files.
2. Make the installer executable: `chmod +x install.sh`
3. Run the installer: `./install.sh`

Launch BooConnect from your application menu, or LogOff/LogOn and start from Tray

(The installer will securely copy the files to ~/.local/share/BooConnect, create desktop entries, and set up the tray icon for autostart.)



## Building from Source

Development Dependencies

To compile BooConnect from source, you need the Vala compiler and the development libraries (headers) for GTK4, libadwaita, and JSON-GLib.

1. Ubuntu / Debian / Linux Mint
   
   `sudo apt install valac build-essential libgtk-4-dev libadwaita-1-dev libjson-glib-dev libgtk-3-dev libappindicator3-dev`

3. Fedora
   
   `sudo dnf install vala gcc gtk4-devel libadwaita-devel json-glib-devel gtk3-devel libappindicator-gtk3-devel`

5. Arch Linux
   
   `sudo pacman -S vala base-devel gtk4 libadwaita json-glib gtk3 libappindicator-gtk3`

#### 1. Compile the Main Application
valac --pkg gtk4 --pkg libadwaita-1 --pkg json-glib-1.0 main.vala -o BooConnect

#### 2. Compile the Tray Indicator
valac --pkg gtk+-3.0 --pkg appindicator3-0.1 tray.vala -o BooConnectTray

(Note: Use --pkg ayatana-appindicator3-0.1 on some newer distros)



## Advanced: Custom Routing (Split Tunneling)

If you only want specific corporate traffic to go through the VPN (Split Tunneling), BooConnect makes it easy:

    Navigate to the installation directory: cd ~/.local/share/BooConnect

    You will find a generated file named vpnc-script.sample.

    Rename it to vpnc-script:
    
    mv vpnc-script.sample vpnc-script

    Open vpnc-script in your text editor and modify the CISCO_SPLIT_INC variables to match your corporate network's IP ranges.

Next time you hit "Connect", BooConnect will automatically detect the file and apply your custom routing rules!

## License

This project is licensed under the MIT License.


