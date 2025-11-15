# Claude Desktop WebExtension Installer

A custom installer for Claude Desktop that includes built-in extensions (and the ability to install your own).

**Note**: The extensions in question are _Web_ extensions! Not to be confused with Local MCPs, which the client also calls Extensions and come in the dxt format.

**Disclaimer**: This is an unofficial, third-party modification of Claude Desktop that enables extension support. By using this installer, you acknowledge that:
- You are doing so at your own risk and discretion
- This project is neither affiliated with nor endorsed by Anthropic
- You are responsible for ensuring your use complies with all applicable terms and agreements

## Overview

This installer generates a modified version of the Claude Desktop client with extension support enabled. It creates a standalone installation that can coexist with the official Claude Desktop client, automatically keeping both the client and extensions up to date.

## Known Issues

### Extension not showing up

This can happen due to reasons I'm not really sure of. Restarting the application is enough.

### Windows defender flags it as malware

Yep, Waca- etc are a pretty common false positive. Pyinstaller-built exes used to also trigger it. There isn't really anything I can do about that.

### Refuses to open on MacOS (Insecure/Not Verified)
You might need to go to Settings -> Privacy and Security and click "Open anyway".

MacOS REALLY doesn't like apps that aren't notarized (aka, that haven't paid the 99$ apple tax).
Not much I can do. I can't afford the subscription, and even if I could, this wouldn't be allowed on the app store.

### First Launch Network Service Crash (macOS only)
On first launch, you might see a crash dialog about the network service. This is (likely) because the modified app needs Keychain permission to be granted, given that it uses an ad-hoc signature. Just ignore it.


## Installation

### Supported Platforms
- **macOS** - Intel and Apple Silicon
- **Windows** - Windows 10/11
- **Linux** - AMD64 and ARM64 (all major distributions)

### Quick Start

#### macOS / Windows
Download the latest installer from [Releases](../../releases) and run it. The installer will handle everything automatically.

#### Linux
1. Download the appropriate release for your architecture from [Releases](../../releases):
   - `Claude_WebExtension_Launcher-X.X.X-linux-amd64.zip` for 64-bit Intel/AMD systems
   - `Claude_WebExtension_Launcher-X.X.X-linux-arm64.zip` for ARM64 systems

2. Extract the archive:
   ```bash
   unzip Claude_WebExtension_Launcher-*-linux-*.zip
   cd linux-*
   ```

3. Run the installation script:
   ```bash
   ./install.sh
   ```

4. Launch Claude:
   ```bash
   claude-webext
   ```
   Or search for "Claude" in your application menu.

**Note for Linux users**: Since Claude doesn't officially support Linux yet, this launcher uses the Windows Electron binaries adapted for Linux. Full functionality is maintained, including all web extension features.

## Features

The installer provides:

- **Latest Claude Desktop** - Automatically downloads and updates to the most recent supported version
- **Custom Icon** - Distinguishes your extended installation from the standard client
- **Extension Support** - Unpacks resources and enables extension loading capabilities. You can add your own unpacked extensions in the extensions folder. NOTE: Most extensions will need to be adapted to work.
- **Pre-installed Extensions** - Includes Usage Tracker (and Toolbox coming soon, including all my userscripts from [here](https://github.com/lugia19/Claude-Toolbox))
- **Automatic Updates** - Keeps both the client and extensions current
- **Standalone Installation** - Runs independently alongside the official Claude Desktop

## How It Works

1. Downloads the latest compatible Claude Desktop client, creating a separate install
2. Modifies the application to enable extension loading
3. Applies a custom icon for easy identification
4. Installs the default extensions

## Privacy

The installer only modifies your local Claude Desktop installation. No data is collected or transmitted by the installer itself. Individual extensions may have their own privacy policies.

## Troubleshooting

If you encounter issues:
- Ensure you have the latest version of the installer
- Check that your system meets the platform requirements
- The extended installation can be completely removed by deleting the installation folder

### Linux-Specific Issues

**Missing dependencies**: Make sure you have Node.js installed:
```bash
# Ubuntu/Debian
sudo apt install nodejs npm

# Fedora
sudo dnf install nodejs npm

# Arch
sudo pacman -S nodejs npm
```

**Permission errors**: Ensure the binary is executable:
```bash
chmod +x ~/.local/share/claude-webext-launcher/Claude_WebExtension_Launcher
```

**Desktop entry not showing**: Update the desktop database manually:
```bash
update-desktop-database ~/.local/share/applications
```

**Uninstall**: Run the uninstall script:
```bash
~/.local/share/claude-webext-launcher/uninstall.sh
```

Or manually remove:
```bash
rm -rf ~/.local/share/claude-webext-launcher
rm -f ~/.local/bin/claude-webext
rm -f ~/.local/share/applications/claude-webext-launcher.desktop
```
