# Claude Code Desktop for Linux - Complete Design Specification

## Executive Summary

This document outlines the complete design for bringing **full-featured Claude Desktop with Web Extension support** to Linux, achieving feature parity with Windows and macOS implementations.

---

## 1. Core Architecture

### 1.1 Linux Distribution Support Strategy

**Target Distributions:**
- **Primary Tier**: Ubuntu 20.04+, Debian 11+, Fedora 36+, Arch Linux
- **Secondary Tier**: openSUSE, Linux Mint, Pop!_OS, Manjaro
- **Universal Support**: AppImage for all distributions

### 1.2 Package Formats

| Format | Priority | Use Case | Auto-Update |
|--------|----------|----------|-------------|
| **AppImage** | 🟢 Primary | Universal, portable, no root needed | Self-contained |
| **.deb** | 🟡 Secondary | Debian/Ubuntu native integration | Via package manager |
| **.rpm** | 🟡 Secondary | Fedora/RHEL native integration | Via package manager |
| **Tarball** | 🟢 Fallback | Manual installation, Arch AUR | Self-contained |

### 1.3 Installation Locations

```
Standard Paths (FHS Compliant):

User Installation (Recommended):
~/.local/share/claude-webext-launcher/           # Application data
  ├── app-latest/                                # Patched Claude Desktop
  │   └── Claude-linux-x64/                      # Electron app structure
  │       ├── claude                             # Main executable
  │       ├── resources/                         # Resources folder
  │       │   └── app.asar                       # Patched app archive
  │       └── ...
  ├── web-extensions/                            # Extensions
  │   ├── usage-tracker/
  │   └── userscript-toolbox/
  ├── launcher                                   # This launcher binary
  └── version.txt                                # Tracking file

~/.local/bin/claude-webext                       # Symlink to launcher
~/.local/share/applications/                     # .desktop file
~/.local/share/icons/hicolor/*/apps/            # Icons

Config/Cache:
~/.config/claude-webext-launcher/                # Configuration
  └── config.json                                # User preferences
~/.cache/claude-webext-launcher/                 # Temporary files
  └── downloads/                                 # Download cache

System-wide Installation (Optional):
/opt/claude-webext-launcher/                     # Application
/usr/local/bin/claude-webext                     # Symlink
/usr/share/applications/                         # .desktop file
/usr/share/icons/hicolor/*/apps/                 # Icons
```

---

## 2. Linux-Specific Implementation

### 2.1 Claude Desktop Download Strategy

**Challenge**: Claude doesn't officially release Linux binaries.

**Solution Options**:

#### Option A: Use Unofficial Linux Builds (Recommended)
```go
// Check community builds or AppImage releases
const claudeLinuxURL = "https://github.com/unofficial-claude/linux-builds/releases"
```

#### Option B: Extract from .deb Package
```go
// Download from Anthropic's potential future Linux support
// Or extract from Windows and run under Wine (not ideal)
```

#### Option C: Use Electron + Claude Web
```go
// Package Claude web interface in Electron shell
// This is the most reliable cross-platform approach
const claudeWebURL = "https://claude.ai"
```

**Recommended Implementation**: Hybrid approach
1. First check for official Linux release
2. Fall back to community AppImage builds
3. Ultimate fallback: Create Electron wrapper for claude.ai

### 2.2 Patcher Modifications for Linux

#### A. Path Resolution (`utils/paths.go`)

```go
func GetBasePath() string {
    switch runtime.GOOS {
    case "darwin":
        home, _ := os.UserHomeDir()
        return filepath.Join(home, "Library", "Application Support", "Claude WebExtension Launcher")
    case "windows":
        exe, _ := os.Executable()
        return filepath.Dir(exe)
    case "linux":
        // XDG Base Directory Specification
        dataHome := os.Getenv("XDG_DATA_HOME")
        if dataHome == "" {
            home, _ := os.UserHomeDir()
            dataHome = filepath.Join(home, ".local", "share")
        }
        return filepath.Join(dataHome, "claude-webext-launcher")
    default:
        return "."
    }
}

func GetConfigPath() string {
    if runtime.GOOS == "linux" {
        configHome := os.Getenv("XDG_CONFIG_HOME")
        if configHome == "" {
            home, _ := os.UserHomeDir()
            configHome = filepath.Join(home, ".config")
        }
        return filepath.Join(configHome, "claude-webext-launcher")
    }
    return GetBasePath()
}

func GetCachePath() string {
    if runtime.GOOS == "linux" {
        cacheHome := os.Getenv("XDG_CACHE_HOME")
        if cacheHome == "" {
            home, _ := os.UserHomeDir()
            cacheHome = filepath.Join(home, ".cache")
        }
        return filepath.Join(cacheHome, "claude-webext-launcher")
    }
    return GetBasePath()
}
```

#### B. Download and Extract (`patcher/patcher.go`)

```go
func downloadAndExtract(version string) error {
    basePath := utils.GetBasePath()

    switch runtime.GOOS {
    case "linux":
        // Download Linux AppImage or tarball
        downloadURL := fmt.Sprintf(
            "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-desktop-electron/linux/Claude-%s.AppImage",
            version,
        )

        // Fallback: Download tarball
        if !urlExists(downloadURL) {
            downloadURL = fmt.Sprintf(
                "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-desktop-electron/linux/Claude-%s-linux-x64.tar.gz",
                version,
            )
        }

        cachePath := utils.GetCachePath()
        downloadPath := filepath.Join(cachePath, "downloads", fmt.Sprintf("claude-%s.tar.gz", version))

        // Download
        if err := downloadFile(downloadURL, downloadPath); err != nil {
            return err
        }

        // Extract
        extractPath := filepath.Join(basePath, "app-latest")
        os.RemoveAll(extractPath)
        os.MkdirAll(extractPath, 0755)

        // Extract tarball or mount AppImage
        if strings.HasSuffix(downloadPath, ".AppImage") {
            return extractAppImage(downloadPath, extractPath)
        } else {
            return extractTarGz(downloadPath, extractPath)
        }
    }
    return nil
}

func extractAppImage(appImagePath, destPath string) error {
    // AppImages can be extracted using --appimage-extract
    cmd := exec.Command(appImagePath, "--appimage-extract")
    cmd.Dir = filepath.Dir(destPath)

    if err := cmd.Run(); err != nil {
        return err
    }

    // Move squashfs-root to destPath
    squashfsPath := filepath.Join(filepath.Dir(destPath), "squashfs-root")
    return os.Rename(squashfsPath, destPath)
}

func extractTarGz(tarPath, destPath string) error {
    file, err := os.Open(tarPath)
    if err != nil {
        return err
    }
    defer file.Close()

    gzr, err := gzip.NewReader(file)
    if err != nil {
        return err
    }
    defer gzr.Close()

    tr := tar.NewReader(gzr)

    for {
        header, err := tr.Next()
        if err == io.EOF {
            break
        }
        if err != nil {
            return err
        }

        target := filepath.Join(destPath, header.Name)

        switch header.Typeflag {
        case tar.TypeDir:
            os.MkdirAll(target, 0755)
        case tar.TypeReg:
            outFile, err := os.Create(target)
            if err != nil {
                return err
            }
            if _, err := io.Copy(outFile, tr); err != nil {
                outFile.Close()
                return err
            }
            outFile.Close()
            os.Chmod(target, os.FileMode(header.Mode))
        }
    }

    return nil
}
```

#### C. Icon Replacement

```go
func replaceIcons() error {
    if runtime.GOOS == "linux" {
        // Replace icon in resources
        basePath := utils.GetBasePath()
        iconPath := filepath.Join(basePath, "app-latest", "Claude-linux-x64", "resources", "app.png")

        // Extract embedded icon
        iconData, _ := resources.ReadFile("resources/icons/app.png")
        return os.WriteFile(iconPath, iconData, 0644)
    }
    return nil
}
```

#### D. No Code Signing Required

Linux doesn't require code signing like macOS, so we can skip the signing steps entirely.

### 2.3 Desktop Integration

#### A. .desktop File Creation

```ini
# claude-webext-launcher.desktop
[Desktop Entry]
Version=1.1
Type=Application
Name=Claude (WebExtension Launcher)
Comment=Claude AI Desktop with Web Extension Support
GenericName=AI Assistant
Exec=/home/USER/.local/bin/claude-webext
Icon=claude-webext-launcher
Terminal=false
Categories=Utility;Development;Office;
Keywords=ai;assistant;claude;anthropic;
StartupWMClass=Claude
StartupNotify=true
MimeType=x-scheme-handler/claude;
```

#### B. Icon Installation

```bash
# Install icons in multiple sizes
for size in 16 32 48 64 128 256 512; do
    install -Dm644 "icons/app-${size}.png" \
        "$HOME/.local/share/icons/hicolor/${size}x${size}/apps/claude-webext-launcher.png"
done

# Update icon cache
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
```

#### C. MIME Type Registration

```xml
<!-- claude-webext-launcher.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="x-scheme-handler/claude">
        <comment>Claude AI Protocol</comment>
        <glob pattern="claude:*"/>
    </mime-type>
</mime-info>
```

### 2.4 Auto-Start Integration

```go
func setupAutoStart(enable bool) error {
    home, _ := os.UserHomeDir()
    autostartDir := filepath.Join(home, ".config", "autostart")
    autostartFile := filepath.Join(autostartDir, "claude-webext-launcher.desktop")

    if enable {
        os.MkdirAll(autostartDir, 0755)

        desktopContent := `[Desktop Entry]
Type=Application
Name=Claude WebExtension Launcher
Exec=%s --minimized
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
`
        exe, _ := os.Executable()
        content := fmt.Sprintf(desktopContent, exe)
        return os.WriteFile(autostartFile, []byte(content), 0644)
    } else {
        return os.Remove(autostartFile)
    }
}
```

---

## 3. Build System for Linux

### 3.1 Build Script: `build-linux.sh`

```bash
#!/bin/bash
set -e

VERSION="1.1.1"
ARCHS=("amd64" "arm64")

echo "Building Claude WebExtension Launcher for Linux..."

for ARCH in "${ARCHS[@]}"; do
    echo "Building for linux/$ARCH..."

    # Build binary
    GOOS=linux GOARCH=$ARCH go build -o "claude-webext-launcher-linux-$ARCH" \
        -ldflags="-s -w -X main.Version=$VERSION" \
        main.go

    # Create directory structure
    BUILD_DIR="build/linux-$ARCH"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    # Copy binary
    cp "claude-webext-launcher-linux-$ARCH" "$BUILD_DIR/claude-webext-launcher"
    chmod +x "$BUILD_DIR/claude-webext-launcher"

    # Create .desktop file
    cat > "$BUILD_DIR/claude-webext-launcher.desktop" << 'EOF'
[Desktop Entry]
Version=1.1
Type=Application
Name=Claude (WebExtension Launcher)
Comment=Claude AI Desktop with Web Extension Support
Exec=claude-webext-launcher
Icon=claude-webext-launcher
Terminal=false
Categories=Utility;Development;Office;
Keywords=ai;assistant;claude;anthropic;
EOF

    # Copy icons
    mkdir -p "$BUILD_DIR/icons"
    cp resources/icons/app-*.png "$BUILD_DIR/icons/" || true

    # Create installation script
    cat > "$BUILD_DIR/install.sh" << 'EOF'
#!/bin/bash
set -e

echo "Installing Claude WebExtension Launcher..."

# Install to user directory
INSTALL_DIR="$HOME/.local/share/claude-webext-launcher"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor"

# Create directories
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

# Copy binary
cp claude-webext-launcher "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/claude-webext-launcher"

# Create symlink
ln -sf "$INSTALL_DIR/claude-webext-launcher" "$BIN_DIR/claude-webext"

# Install desktop file
sed "s|Exec=claude-webext-launcher|Exec=$BIN_DIR/claude-webext|g" \
    claude-webext-launcher.desktop > "$DESKTOP_DIR/claude-webext-launcher.desktop"

# Install icons
for size in 16 32 48 64 128 256 512; do
    if [ -f "icons/app-${size}.png" ]; then
        mkdir -p "$ICON_DIR/${size}x${size}/apps"
        cp "icons/app-${size}.png" "$ICON_DIR/${size}x${size}/apps/claude-webext-launcher.png"
    fi
done

# Update desktop database
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || true

echo "✓ Installation complete!"
echo "Run 'claude-webext' to launch Claude Desktop."
EOF
    chmod +x "$BUILD_DIR/install.sh"

    # Create uninstallation script
    cat > "$BUILD_DIR/uninstall.sh" << 'EOF'
#!/bin/bash
set -e

echo "Uninstalling Claude WebExtension Launcher..."

rm -rf "$HOME/.local/share/claude-webext-launcher"
rm -f "$HOME/.local/bin/claude-webext"
rm -f "$HOME/.local/share/applications/claude-webext-launcher.desktop"

for size in 16 32 48 64 128 256 512; do
    rm -f "$HOME/.local/share/icons/hicolor/${size}x${size}/apps/claude-webext-launcher.png"
done

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "✓ Uninstallation complete!"
EOF
    chmod +x "$BUILD_DIR/uninstall.sh"

    # Create tarball
    tar -czf "Claude_WebExtension_Launcher-$VERSION-linux-$ARCH.tar.gz" -C build "linux-$ARCH"

    echo "✓ Created Claude_WebExtension_Launcher-$VERSION-linux-$ARCH.tar.gz"
done

echo "✓ Linux builds complete!"
```

### 3.2 AppImage Build: `build-appimage.sh`

```bash
#!/bin/bash
set -e

VERSION="1.1.1"
ARCH="x86_64"  # AppImage uses x86_64 naming

echo "Building AppImage for Claude WebExtension Launcher..."

# Build binary
GOOS=linux GOARCH=amd64 go build -o "claude-webext-launcher" \
    -ldflags="-s -w -X main.Version=$VERSION" \
    main.go

# Create AppDir structure
APPDIR="Claude_WebExtension_Launcher.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Copy binary
cp claude-webext-launcher "$APPDIR/usr/bin/"

# Create .desktop file
cat > "$APPDIR/claude-webext-launcher.desktop" << 'EOF'
[Desktop Entry]
Version=1.1
Type=Application
Name=Claude (WebExtension Launcher)
Comment=Claude AI Desktop with Web Extension Support
Exec=claude-webext-launcher
Icon=claude-webext-launcher
Terminal=false
Categories=Utility;Development;Office;
EOF

# Copy desktop file
cp "$APPDIR/claude-webext-launcher.desktop" "$APPDIR/usr/share/applications/"

# Copy icon
cp resources/icons/app-256.png "$APPDIR/usr/share/icons/hicolor/256x256/apps/claude-webext-launcher.png"
cp resources/icons/app-256.png "$APPDIR/claude-webext-launcher.png"

# Create AppRun
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/claude-webext-launcher" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Download appimagetool if not present
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool-x86_64.AppImage
fi

# Build AppImage
ARCH=$ARCH ./appimagetool-x86_64.AppImage "$APPDIR" \
    "Claude_WebExtension_Launcher-$VERSION-$ARCH.AppImage"

echo "✓ AppImage build complete!"
echo "Created: Claude_WebExtension_Launcher-$VERSION-$ARCH.AppImage"
```

### 3.3 Debian Package Build: `build-deb.sh`

```bash
#!/bin/bash
set -e

VERSION="1.1.1"
ARCH="amd64"

echo "Building .deb package..."

# Build binary
GOOS=linux GOARCH=amd64 go build -o "claude-webext-launcher" \
    -ldflags="-s -w -X main.Version=$VERSION" \
    main.go

# Create package structure
PKG_DIR="claude-webext-launcher_${VERSION}_${ARCH}"
rm -rf "$PKG_DIR"

mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/applications"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$PKG_DIR/usr/share/doc/claude-webext-launcher"

# Copy binary
cp claude-webext-launcher "$PKG_DIR/usr/bin/"
chmod 755 "$PKG_DIR/usr/bin/claude-webext-launcher"

# Create control file
cat > "$PKG_DIR/DEBIAN/control" << EOF
Package: claude-webext-launcher
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: nodejs (>= 14)
Maintainer: Claude WebExtension Launcher Team
Description: Claude AI Desktop with Web Extension Support
 Modified Claude Desktop launcher that enables web extension support.
 Allows running Chrome-compatible extensions in Claude Desktop.
Homepage: https://github.com/lugia19/claude-webext-patcher
EOF

# Create postinst script
cat > "$PKG_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Update desktop database
update-desktop-database 2>/dev/null || true
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

exit 0
EOF
chmod 755 "$PKG_DIR/DEBIAN/postinst"

# Create prerm script
cat > "$PKG_DIR/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

# Update desktop database
update-desktop-database 2>/dev/null || true
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

exit 0
EOF
chmod 755 "$PKG_DIR/DEBIAN/postrm"

# Copy desktop file
cp claude-webext-launcher.desktop "$PKG_DIR/usr/share/applications/"

# Copy icon
cp resources/icons/app-256.png "$PKG_DIR/usr/share/icons/hicolor/256x256/apps/claude-webext-launcher.png"

# Copy documentation
cp README.md "$PKG_DIR/usr/share/doc/claude-webext-launcher/"
cp LICENSE "$PKG_DIR/usr/share/doc/claude-webext-launcher/"

# Build package
dpkg-deb --build "$PKG_DIR"

echo "✓ Debian package build complete!"
echo "Created: ${PKG_DIR}.deb"
```

---

## 4. Launch Mechanism

### 4.1 Launcher Behavior (Linux-specific)

```go
// In main.go
func launchClaude() error {
    basePath := utils.GetBasePath()

    switch runtime.GOOS {
    case "linux":
        // Find Claude executable
        claudePath := filepath.Join(basePath, "app-latest", "Claude-linux-x64", "claude")

        if _, err := os.Stat(claudePath); os.IsNotExist(err) {
            // Try alternative locations
            claudePath = filepath.Join(basePath, "app-latest", "claude")
        }

        // Launch with detached process
        cmd := exec.Command(claudePath)
        cmd.Env = append(os.Environ(),
            "ELECTRON_IS_DEV=0",
            "ELECTRON_RUN_AS_NODE=0",
        )

        // Detach from parent
        cmd.SysProcAttr = &syscall.SysProcAttr{
            Setpgid: true,
        }

        if err := cmd.Start(); err != nil {
            return err
        }

        // Detach completely
        cmd.Process.Release()

        fmt.Println("✓ Claude launched successfully!")
        return nil
    }

    return nil
}
```

---

## 5. Self-Update Mechanism for Linux

### 5.1 Update Detection

```go
// In selfupdate/selfupdate.go
func getPlatformAssetName(version string) string {
    switch runtime.GOOS {
    case "linux":
        arch := runtime.GOARCH
        if arch == "amd64" {
            return fmt.Sprintf("Claude_WebExtension_Launcher-%s-linux-amd64.tar.gz", version)
        } else if arch == "arm64" {
            return fmt.Sprintf("Claude_WebExtension_Launcher-%s-linux-arm64.tar.gz", version)
        }
        // AppImage alternative
        return fmt.Sprintf("Claude_WebExtension_Launcher-%s-x86_64.AppImage", version)
    }
    return ""
}
```

### 5.2 Update Installation (Linux)

```go
func applyUpdate(assetURL string) error {
    if runtime.GOOS == "linux" {
        // Download new version
        cachePath := utils.GetCachePath()
        updatePath := filepath.Join(cachePath, "update.tar.gz")

        if err := downloadFile(assetURL, updatePath); err != nil {
            return err
        }

        // Extract to temporary location
        tmpDir := filepath.Join(cachePath, "update-tmp")
        os.RemoveAll(tmpDir)
        os.MkdirAll(tmpDir, 0755)

        if err := extractTarGz(updatePath, tmpDir); err != nil {
            return err
        }

        // Get current executable path
        exe, _ := os.Executable()
        exeReal, _ := filepath.EvalSymlinks(exe)

        // Create update script
        scriptPath := filepath.Join(cachePath, "update.sh")
        script := fmt.Sprintf(`#!/bin/bash
sleep 1
cp "%s/linux-*/claude-webext-launcher" "%s"
chmod +x "%s"
rm -rf "%s"
exec "%s"
`, tmpDir, exeReal, exeReal, tmpDir, exeReal)

        os.WriteFile(scriptPath, []byte(script), 0755)

        // Execute update script
        cmd := exec.Command("bash", scriptPath)
        cmd.Start()

        os.Exit(0)
    }
    return nil
}
```

---

## 6. System Tray Integration (Optional)

For Linux desktop environments, we can add system tray support:

```go
// Using github.com/getlantern/systray
import "github.com/getlantern/systray"

func onReady() {
    systray.SetIcon(iconData)
    systray.SetTitle("Claude WebExt")
    systray.SetTooltip("Claude Desktop with Extensions")

    mOpen := systray.AddMenuItem("Open Claude", "Launch Claude Desktop")
    mExtensions := systray.AddMenuItem("Manage Extensions", "Update extensions")
    systray.AddSeparator()
    mQuit := systray.AddMenuItem("Quit", "Quit the launcher")

    go func() {
        for {
            select {
            case <-mOpen.ClickedCh:
                launchClaude()
            case <-mExtensions.ClickedCh:
                updateExtensions()
            case <-mQuit.ClickedCh:
                systray.Quit()
            }
        }
    }()
}
```

---

## 7. Feature Parity Matrix

| Feature | Windows | macOS | Linux (Proposed) |
|---------|---------|-------|------------------|
| **Core Functionality** ||||
| Download Claude Desktop | ✅ | ✅ | ✅ (.tar.gz/AppImage) |
| Patch app.asar | ✅ | ✅ | ✅ (same mechanism) |
| Inject extension loader | ✅ | ✅ | ✅ (identical code) |
| Load web extensions | ✅ | ✅ | ✅ (identical API) |
| Auto-update extensions | ✅ | ✅ | ✅ (GitHub releases) |
| **Distribution** ||||
| Portable package | ✅ (.zip) | ✅ (.zip) | ✅ (.tar.gz) |
| Universal package | ❌ | ❌ | ✅ (AppImage) |
| Native package | ❌ | ✅ (.app) | ✅ (.deb/.rpm) |
| **Desktop Integration** ||||
| Application icon | ✅ | ✅ | ✅ (.desktop + icons) |
| Start menu entry | ✅ | ✅ | ✅ (applications menu) |
| Auto-start | ✅ (batch) | ✅ (LaunchAgents) | ✅ (autostart) |
| **Updates** ||||
| Self-update launcher | ✅ | ✅ | ✅ (tar.gz replacement) |
| Update Claude Desktop | ✅ | ✅ | ✅ (version check) |
| **User Experience** ||||
| GUI launcher | ✅ | ✅ | ✅ (same) |
| System tray (optional) | ⚠️ | ⚠️ | ✅ (systray library) |
| Terminal-free launch | ✅ | ✅ | ✅ (.desktop file) |

**Legend**: ✅ Fully supported | ⚠️ Partial | ❌ Not supported

---

## 8. Testing Strategy

### 8.1 Distribution Testing

Test on:
- **Ubuntu 22.04 LTS** (GNOME)
- **Fedora 39** (GNOME)
- **Arch Linux** (KDE Plasma)
- **Debian 12** (Xfce)
- **Linux Mint 21** (Cinnamon)

### 8.2 Test Cases

1. **Installation**
   - ✓ Fresh install from tarball
   - ✓ Fresh install from AppImage
   - ✓ Upgrade from previous version
   - ✓ Verify file permissions
   - ✓ Verify desktop integration

2. **Functionality**
   - ✓ Claude Desktop downloads and patches
   - ✓ Extensions load correctly
   - ✓ Extensions function (alarm API, notifications, etc.)
   - ✓ Auto-update works
   - ✓ Launch from desktop menu
   - ✓ Launch from terminal

3. **Edge Cases**
   - ✓ Network failures during download
   - ✓ Corrupted downloads
   - ✓ Insufficient disk space
   - ✓ No Node.js installed
   - ✓ Different file systems (ext4, btrfs, xfs)

---

## 9. Implementation Checklist

### Phase 1: Core Linux Support
- [ ] Add Linux path resolution to `utils/paths.go`
- [ ] Implement Linux download in `patcher/patcher.go`
- [ ] Add tar.gz extraction support
- [ ] Add AppImage extraction support
- [ ] Test patching on Linux Electron apps
- [ ] Update `main.go` to handle Linux launches

### Phase 2: Build System
- [ ] Create `build-linux.sh` for tarball builds
- [ ] Create `build-appimage.sh` for AppImage
- [ ] Create `build-deb.sh` for Debian packages
- [ ] Generate multi-size icons (16-512px)
- [ ] Create installation/uninstallation scripts

### Phase 3: Desktop Integration
- [ ] Generate `.desktop` file
- [ ] Implement icon installation
- [ ] Add MIME type registration
- [ ] Implement auto-start functionality
- [ ] Test on GNOME, KDE, Xfce

### Phase 4: Self-Update
- [ ] Add Linux asset detection in `selfupdate.go`
- [ ] Implement tar.gz update mechanism
- [ ] Create update shell script
- [ ] Test update flow

### Phase 5: Distribution
- [ ] Upload Linux builds to GitHub releases
- [ ] Create AUR package (Arch User Repository)
- [ ] Submit to Flathub (optional)
- [ ] Create Snap package (optional)
- [ ] Update documentation

---

## 10. Documentation Updates

### README.md additions:

```markdown
## Linux Installation

### Option 1: AppImage (Universal - Recommended)
1. Download `Claude_WebExtension_Launcher-1.1.1-x86_64.AppImage`
2. Make it executable: `chmod +x Claude_WebExtension_Launcher-*.AppImage`
3. Run: `./Claude_WebExtension_Launcher-*.AppImage`

### Option 2: Tarball
1. Download `Claude_WebExtension_Launcher-1.1.1-linux-amd64.tar.gz`
2. Extract: `tar -xzf Claude_WebExtension_Launcher-*.tar.gz`
3. Run installer: `cd linux-amd64 && ./install.sh`
4. Launch: `claude-webext`

### Option 3: Debian/Ubuntu (.deb)
```bash
sudo dpkg -i claude-webext-launcher_1.1.1_amd64.deb
claude-webext-launcher
```

### Option 4: Fedora/RHEL (.rpm)
```bash
sudo rpm -i claude-webext-launcher-1.1.1-x86_64.rpm
claude-webext-launcher
```

### Uninstallation
- Tarball: Run `~/.local/share/claude-webext-launcher/uninstall.sh`
- Debian: `sudo apt remove claude-webext-launcher`
- Fedora: `sudo dnf remove claude-webext-launcher`
```

---

## 11. Future Enhancements

### 11.1 Wayland Support
- Ensure compatibility with Wayland compositors
- Test screen sharing extensions under Wayland

### 11.2 Flatpak Distribution
```yaml
# org.claude.WebExtLauncher.yaml
app-id: org.claude.WebExtLauncher
runtime: org.freedesktop.Platform
runtime-version: '23.08'
sdk: org.freedesktop.Sdk
command: claude-webext-launcher
```

### 11.3 Snap Package
```yaml
# snapcraft.yaml
name: claude-webext-launcher
version: '1.1.1'
summary: Claude AI Desktop with Web Extensions
description: |
  Modified Claude Desktop launcher with web extension support
base: core22
confinement: strict
grade: stable
```

---

## Summary

This design provides **complete feature parity** for Linux users:

✅ **Full functionality** - All features from Windows/macOS
✅ **Multiple distribution formats** - AppImage, .deb, .rpm, tarball
✅ **Native desktop integration** - Proper Linux FHS compliance
✅ **Auto-updates** - Same mechanism as other platforms
✅ **Professional UX** - Desktop files, icons, system tray

**Next Steps**: Implement Phase 1 (Core Linux Support) and test on Ubuntu 22.04.
