#!/bin/bash

APP_NAME="Claude_WebExtension_Launcher"
PACKAGE_NAME="com.lugia19.claudewebextlauncher"

# Read version from main.go
VERSION=$(grep 'const Version = ' main.go | sed 's/.*"\(.*\)".*/\1/')
if [ -z "$VERSION" ]; then
    echo "ERROR: Could not find version in main.go"
    exit 1
fi

echo "Building version: $VERSION for all platforms"
echo "============================================"

# Create builds directory
mkdir -p builds

# Clean up any existing files
rm -f builds/*.zip
rm -rf builds/*.app

# Function to create macOS app bundle
create_macos_bundle() {
    local binary_name=$1
    local arch_suffix=$2
    
    echo "Creating macOS app bundle for $arch_suffix..."
    
    # Create directory structure
    mkdir -p "builds/$APP_NAME.app/Contents/MacOS"
    mkdir -p "builds/$APP_NAME.app/Contents/Resources"
    
    # Move binary
    mv "$binary_name" "builds/$APP_NAME.app/Contents/MacOS/$APP_NAME"
    chmod +x "builds/$APP_NAME.app/Contents/MacOS/$APP_NAME"
    
    # Create Info.plist with architecture-specific settings
    if [ "$arch_suffix" = "arm64" ]; then
        cat > "builds/$APP_NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>app.icns</string>
    <key>CFBundleIdentifier</key>
    <string>$PACKAGE_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
</dict>
</plist>
EOF
    else
        cat > "builds/$APP_NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>app.icns</string>
    <key>CFBundleIdentifier</key>
    <string>$PACKAGE_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.12</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>x86_64</string>
    </array>
</dict>
</plist>
EOF
    fi
    
    # Copy icon if it exists
    if [ -f "resources/icons/app.icns" ]; then
        cp "resources/icons/app.icns" "builds/$APP_NAME.app/Contents/Resources/"
        echo "  Icon added to app bundle"
    fi
    
    # Sign the app with ad-hoc signature
    echo "  Signing app..."
    codesign --remove-signature "builds/$APP_NAME.app" 2>/dev/null || true
    codesign --force --deep --sign - "builds/$APP_NAME.app"
    
    if [ $? -eq 0 ]; then
        echo "  ✅ App signed successfully"
    else
        echo "  ⚠️  Warning: Could not sign app, but continuing..."
    fi
    
    # Remove quarantine attributes
    xattr -cr "builds/$APP_NAME.app" 2>/dev/null || true
    
    # Create distribution zip
    echo "  Creating distribution zip..."
    cd builds
    zip -r "$APP_NAME-$VERSION-macos-$arch_suffix.zip" "$APP_NAME.app"
    cd ..
    
    echo "  ✅ Created: builds/$APP_NAME-$VERSION-macos-$arch_suffix.zip"
    
    # Clean up app bundle
    rm -rf "builds/$APP_NAME.app"
}

# Build 1: macOS Apple Silicon (ARM64)
echo ""
echo "1. Building macOS Apple Silicon (ARM64)..."
GOOS=darwin GOARCH=arm64 go build -o "$APP_NAME-mac-arm64"

if [ -f "$APP_NAME-mac-arm64" ]; then
    create_macos_bundle "$APP_NAME-mac-arm64" "arm64"
else
    echo "  ❌ ARM64 build failed!"
fi

# Build 2: macOS Intel (AMD64)
echo ""
echo "2. Building macOS Intel (AMD64)..."
GOOS=darwin GOARCH=amd64 go build -o "$APP_NAME-mac-amd64"

if [ -f "$APP_NAME-mac-amd64" ]; then
    create_macos_bundle "$APP_NAME-mac-amd64" "amd64"
else
    echo "  ❌ Intel macOS build failed!"
fi

# Build 3: Windows (AMD64)
echo ""
echo "3. Building Windows (AMD64)..."
GOOS=windows GOARCH=amd64 go build -o "$APP_NAME.exe"

if [ -f "$APP_NAME.exe" ]; then
    echo "  Creating Windows distribution zip..."

    # Create temporary directory for packaging
    temp_dir="builds/temp-windows"
    mkdir -p "$temp_dir"

    # Copy executable and batch scripts to temp directory
    cp "$APP_NAME.exe" "$temp_dir/"
    cp "resources/Toggle-Startup.bat" "$temp_dir/"
    cp "resources/Toggle-StartMenu.bat" "$temp_dir/"

    # Create zip from temp directory
    cd "$temp_dir"
    zip "../$APP_NAME-$VERSION-windows.zip" *
    cd ../..

    # Clean up
    rm "$APP_NAME.exe"
    rm -rf "$temp_dir"

    echo "  ✅ Created: builds/$APP_NAME-$VERSION-windows.zip"
else
    echo "  ❌ Windows build failed!"
fi

# Build 4 & 5: Linux (AMD64 and ARM64)
for arch in amd64 arm64; do
    build_num=$((arch == "amd64" ? 4 : 5))
    echo ""
    echo "$build_num. Building Linux ($arch)..."
    GOOS=linux GOARCH=$arch go build -o "$APP_NAME-linux-$arch"

    if [ -f "$APP_NAME-linux-$arch" ]; then
        echo "  Creating Linux distribution zip..."

        # Create temporary directory for packaging
        temp_dir="builds/temp-linux-$arch"
        mkdir -p "$temp_dir"

        # Copy executable
        cp "$APP_NAME-linux-$arch" "$temp_dir/$APP_NAME"
        chmod +x "$temp_dir/$APP_NAME"

        # Create .desktop file
        cat > "$temp_dir/claude-webext-launcher.desktop" << EOF
[Desktop Entry]
Version=1.1
Type=Application
Name=Claude (WebExtension Launcher)
Comment=Claude AI Desktop with Web Extension Support
Exec=$APP_NAME
Icon=claude-webext-launcher
Terminal=false
Categories=Utility;Development;Office;
Keywords=ai;assistant;claude;anthropic;
StartupWMClass=Claude
StartupNotify=true
EOF

        # Create installation script
        cat > "$temp_dir/install.sh" << 'INSTALLEOF'
#!/bin/bash
set -e

echo "Installing Claude WebExtension Launcher..."

INSTALL_DIR="$HOME/.local/share/claude-webext-launcher"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

cp Claude_WebExtension_Launcher "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/Claude_WebExtension_Launcher"

ln -sf "$INSTALL_DIR/Claude_WebExtension_Launcher" "$BIN_DIR/claude-webext"

sed "s|Exec=Claude_WebExtension_Launcher|Exec=$BIN_DIR/claude-webext|g" \
    claude-webext-launcher.desktop > "$DESKTOP_DIR/claude-webext-launcher.desktop"

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

echo "✓ Installation complete!"
echo "Run 'claude-webext' or search for 'Claude' in your application menu"
INSTALLEOF
        chmod +x "$temp_dir/install.sh"

        # Create uninstallation script
        cat > "$temp_dir/uninstall.sh" << 'UNINSTALLEOF'
#!/bin/bash
set -e

echo "Uninstalling Claude WebExtension Launcher..."

rm -rf "$HOME/.local/share/claude-webext-launcher"
rm -f "$HOME/.local/bin/claude-webext"
rm -f "$HOME/.local/share/applications/claude-webext-launcher.desktop"
rm -f "$HOME/.config/autostart/claude-webext-launcher.desktop"

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "✓ Uninstallation complete!"
UNINSTALLEOF
        chmod +x "$temp_dir/uninstall.sh"

        # Create README
        cat > "$temp_dir/README.txt" << 'READMEEOF'
Claude WebExtension Launcher for Linux

Installation: ./install.sh
Uninstallation: ./uninstall.sh

For more information:
https://github.com/lugia19/claude-webext-patcher
READMEEOF

        # Create zip from temp directory
        cd "$temp_dir"
        zip "../$APP_NAME-$VERSION-linux-$arch.zip" *
        cd ../..

        # Clean up
        rm "$APP_NAME-linux-$arch"
        rm -rf "$temp_dir"

        echo "  ✅ Created: builds/$APP_NAME-$VERSION-linux-$arch.zip"
    else
        echo "  ❌ Linux $arch build failed!"
    fi
done

# Summary
echo ""
echo "============================================"
echo "Build Summary:"
echo "============================================"

if [ -f "builds/$APP_NAME-$VERSION-macos-arm64.zip" ]; then
    echo "✅ macOS Apple Silicon: builds/$APP_NAME-$VERSION-macos-arm64.zip"
fi

if [ -f "builds/$APP_NAME-$VERSION-macos-amd64.zip" ]; then
    echo "✅ macOS Intel: builds/$APP_NAME-$VERSION-macos-amd64.zip"
fi

if [ -f "builds/$APP_NAME-$VERSION-windows.zip" ]; then
    echo "✅ Windows: builds/$APP_NAME-$VERSION-windows.zip"
fi

if [ -f "builds/$APP_NAME-$VERSION-linux-amd64.zip" ]; then
    echo "✅ Linux AMD64: builds/$APP_NAME-$VERSION-linux-amd64.zip"
fi

if [ -f "builds/$APP_NAME-$VERSION-linux-arm64.zip" ]; then
    echo "✅ Linux ARM64: builds/$APP_NAME-$VERSION-linux-arm64.zip"
fi

echo ""
echo "All builds complete! 🎉"
