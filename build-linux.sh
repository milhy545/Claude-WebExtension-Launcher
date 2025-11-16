#!/bin/bash
set -e

VERSION="1.1.1"
ARCHS=("amd64" "arm64")

echo "Building Claude WebExtension Launcher for Linux..."

for ARCH in "${ARCHS[@]}"; do
    echo "Building for linux/$ARCH..."

    # Build binary
    GOOS=linux GOARCH=$ARCH go build -o "Claude_WebExtension_Launcher-linux-$ARCH" \
        -ldflags="-s -w -X main.Version=$VERSION" \
        .

    # Create directory structure
    BUILD_DIR="build/linux-$ARCH"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    # Copy binary
    cp "Claude_WebExtension_Launcher-linux-$ARCH" "$BUILD_DIR/Claude_WebExtension_Launcher"
    chmod +x "$BUILD_DIR/Claude_WebExtension_Launcher"

    # Create .desktop file template
    cat > "$BUILD_DIR/claude-webext-launcher.desktop" << 'EOF'
[Desktop Entry]
Version=1.1
Type=Application
Name=Claude (WebExtension Launcher)
Comment=Claude AI Desktop with Web Extension Support
Exec=Claude_WebExtension_Launcher
Icon=claude-webext-launcher
Terminal=false
Categories=Utility;Development;Office;
Keywords=ai;assistant;claude;anthropic;
StartupWMClass=Claude
StartupNotify=true
EOF

    # Create installation script
    cat > "$BUILD_DIR/install.sh" << 'EOF'
#!/bin/bash
set -e

echo "Installing Claude WebExtension Launcher..."

# Install to user directory
INSTALL_DIR="$HOME/.local/share/claude-webext-launcher"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

# Create directories
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

# Copy binary
cp Claude_WebExtension_Launcher "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/Claude_WebExtension_Launcher"

# Create symlink
ln -sf "$INSTALL_DIR/Claude_WebExtension_Launcher" "$BIN_DIR/claude-webext"

# Install desktop file
sed "s|Exec=Claude_WebExtension_Launcher|Exec=$BIN_DIR/claude-webext|g" \
    claude-webext-launcher.desktop > "$DESKTOP_DIR/claude-webext-launcher.desktop"

# Update desktop database
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

echo "✓ Installation complete!"
echo ""
echo "You can now:"
echo "  1. Run 'claude-webext' from terminal"
echo "  2. Search for 'Claude' in your application menu"
echo ""
echo "To set up auto-start, copy the desktop file to:"
echo "  ~/.config/autostart/claude-webext-launcher.desktop"
EOF
    chmod +x "$BUILD_DIR/install.sh"

    # Create uninstallation script
    cat > "$BUILD_DIR/uninstall.sh" << 'EOF'
#!/bin/bash
set -e

echo "Uninstalling Claude WebExtension Launcher..."

# Remove files
rm -rf "$HOME/.local/share/claude-webext-launcher"
rm -f "$HOME/.local/bin/claude-webext"
rm -f "$HOME/.local/share/applications/claude-webext-launcher.desktop"
rm -f "$HOME/.config/autostart/claude-webext-launcher.desktop"

# Update desktop database
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "✓ Uninstallation complete!"
echo ""
echo "Note: User data and extensions are kept in:"
echo "  ~/.local/share/claude-webext-launcher/"
echo "  ~/.config/claude-webext-launcher/"
echo "  ~/.cache/claude-webext-launcher/"
echo ""
echo "To remove them completely, run:"
echo "  rm -rf ~/.local/share/claude-webext-launcher/"
echo "  rm -rf ~/.config/claude-webext-launcher/"
echo "  rm -rf ~/.cache/claude-webext-launcher/"
EOF
    chmod +x "$BUILD_DIR/uninstall.sh"

    # Create README
    cat > "$BUILD_DIR/README.txt" << 'EOF'
Claude WebExtension Launcher for Linux
=======================================

Installation:
1. Run: ./install.sh
2. Launch: claude-webext
   Or search for "Claude" in your application menu

Uninstallation:
1. Run: ./uninstall.sh

Manual Installation:
1. Copy Claude_WebExtension_Launcher to ~/.local/bin/
2. Make it executable: chmod +x ~/.local/bin/Claude_WebExtension_Launcher
3. Run: ~/.local/bin/Claude_WebExtension_Launcher

Data Locations:
- Application: ~/.local/share/claude-webext-launcher/
- Config: ~/.config/claude-webext-launcher/
- Cache: ~/.cache/claude-webext-launcher/

For more information, visit:
https://github.com/lugia19/claude-webext-patcher
EOF

    # Create tarball
    echo "Creating tarball..."
    tar -czf "Claude_WebExtension_Launcher-$VERSION-linux-$ARCH.tar.gz" -C build "linux-$ARCH"

    echo "✓ Created Claude_WebExtension_Launcher-$VERSION-linux-$ARCH.tar.gz"

    # Clean up binary in root
    rm -f "Claude_WebExtension_Launcher-linux-$ARCH"
done

# Create a .zip file for GitHub releases (consistent with Windows/macOS)
echo ""
echo "Creating .zip files for GitHub releases..."
for ARCH in "${ARCHS[@]}"; do
    BUILD_DIR="build/linux-$ARCH"
    if [ -d "$BUILD_DIR" ]; then
        cd build
        zip -r "../Claude_WebExtension_Launcher-$VERSION-linux-$ARCH.zip" "linux-$ARCH"
        cd ..
        echo "✓ Created Claude_WebExtension_Launcher-$VERSION-linux-$ARCH.zip"
    fi
done

echo ""
echo "✓ Linux builds complete!"
echo ""
echo "Created files:"
for ARCH in "${ARCHS[@]}"; do
    echo "  - Claude_WebExtension_Launcher-$VERSION-linux-$ARCH.tar.gz"
    echo "  - Claude_WebExtension_Launcher-$VERSION-linux-$ARCH.zip"
done
