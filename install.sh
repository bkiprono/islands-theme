#!/bin/bash

set -e

echo "🏝️  Islands Dark Theme Installer for macOS/Linux"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect IDE
if command -v antigravity &> /dev/null; then
    IDE_NAME="Antigravity"
    CLI_CMD="antigravity"
    echo -e "${GREEN}✓ Antigravity CLI found${NC}"
elif [ -f "/Applications/Antigravity.app/Contents/Resources/app/bin/antigravity" ]; then
    IDE_NAME="Antigravity"
    CLI_CMD="/Applications/Antigravity.app/Contents/Resources/app/bin/antigravity"
    echo -e "${GREEN}✓ Antigravity found at application path${NC}"
elif command -v code &> /dev/null; then
    IDE_NAME="VS Code"
    CLI_CMD="code"
    echo -e "${GREEN}✓ VS Code CLI found${NC}"
else
    echo -e "${RED}❌ Error: Neither Antigravity nor VS Code CLI found!${NC}"
    echo "Please install an IDE and make sure its CLI command is in your PATH."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ""
echo "📦 Step 1: Installing Islands Dark theme extension..."

# Set extension directory based on IDE
if [[ "$IDE_NAME" == "Antigravity" ]]; then
    EXT_DIR="$HOME/.antigravity/extensions/bwya77.islands-dark-1.0.0"
else
    EXT_DIR="$HOME/.vscode/extensions/bwya77.islands-dark-1.0.0"
fi

rm -rf "$EXT_DIR"
mkdir -p "$EXT_DIR"
cp "$SCRIPT_DIR/package.json" "$EXT_DIR/"
cp -r "$SCRIPT_DIR/themes" "$EXT_DIR/"

if [ -d "$EXT_DIR/themes" ]; then
    echo -e "${GREEN}✓ Theme extension installed to $EXT_DIR${NC}"
else
    echo -e "${RED}❌ Failed to install theme extension${NC}"
    exit 1
fi

echo ""
echo "🔧 Step 2: Installing Custom UI Style extension..."
if $CLI_CMD --install-extension subframe7536.custom-ui-style --force; then
    echo -e "${GREEN}✓ Custom UI Style extension installed${NC}"
else
    echo -e "${YELLOW}⚠️  Could not install Custom UI Style extension automatically${NC}"
    echo "   Please install it manually from the Extensions marketplace"
fi

echo ""
echo "🔤 Step 3: Installing required fonts..."

install_font_macos() {
    local font_name=$1
    local download_url=$2
    local filename=$3

    if mdfind "kMDItemFontFamily == '$font_name'" | grep -q "$font_name"; then
        echo -e "${GREEN}✓ $font_name is already installed${NC}"
    else
        echo "   Installing $font_name..."
        mkdir -p "/tmp/islands-fonts"
        curl -L "$download_url" -o "/tmp/islands-fonts/$filename"
        cp "/tmp/islands-fonts/$filename" "$HOME/Library/Fonts/"
        echo -e "${GREEN}✓ $font_name installed${NC}"
    fi
}

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    FONT_DIR="$HOME/Library/Fonts"
    echo "   Checking system fonts..."
    
    # Install Bear Sans UI (bundled)
    cp "$SCRIPT_DIR/fonts/"*.otf "$FONT_DIR/" 2>/dev/null || true
    echo -e "${GREEN}✓ Bear Sans UI fonts installed${NC}"

    # Install IBM Plex Mono (missing)
    install_font_macos "IBM Plex Mono" \
        "https://github.com/IBM/plex/raw/master/IBM-Plex-Mono/fonts/complete/otf/IBM-Plex-Mono-Regular.otf" \
        "IBM-Plex-Mono-Regular.otf"

    # Install Fira Code Nerd Font (missing)
    install_font_macos "FiraCode Nerd Font Mono" \
        "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Regular/FiraCodeNerdFontMono-Regular.ttf" \
        "FiraCodeNerdFontMono-Regular.ttf"

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    echo "   Installing bundled fonts to: $FONT_DIR"
    cp "$SCRIPT_DIR/fonts/"*.otf "$FONT_DIR/" 2>/dev/null || true
    fc-cache -f 2>/dev/null || true
    echo -e "${GREEN}✓ Bundled fonts installed${NC}"
    echo -e "${YELLOW}⚠️  Manual installation of IBM Plex Mono and Fira Code still recommended for Linux${NC}"
else
    echo -e "${YELLOW}⚠️  Could not detect OS type for automatic font installation${NC}"
    echo "   Please manually install the fonts from the 'fonts/' folder"
fi

echo ""
echo "⚙️  Step 4: Applying $IDE_NAME settings..."
if [[ "$IDE_NAME" == "Antigravity" ]]; then
    SETTINGS_DIR="$HOME/Library/Application Support/Antigravity/User"
else
    SETTINGS_DIR="$HOME/.config/Code/User"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
    fi
fi

mkdir -p "$SETTINGS_DIR"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

# Check if settings.json exists
if [ -f "$SETTINGS_FILE" ]; then
    echo -e "${YELLOW}⚠️  Existing settings.json found${NC}"
    echo "   Backing up to settings.json.backup"
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"

    # Read the existing settings and merge
    echo "   Merging Islands Dark settings with your existing settings..."

    # Create a temporary file with the merge logic using node.js if available
    if command -v node &> /dev/null; then
        export SETTINGS_FILE
        node << 'NODE_SCRIPT'
const fs = require('fs');
const path = require('path');

// Strip JSONC features for JSON.parse
function stripJsonc(text) {
    text = text.replace(/\/\/(?=(?:[^"\\]|\\.)*$)/gm, '');
    text = text.replace(/\/\*[\s\S]*?\*\//g, '');
    text = text.replace(/,\s*([}\]])/g, '$1');
    return text;
}

const scriptDir = process.cwd();
const newSettingsFile = path.join(scriptDir, 'settings.json');
const newSettings = JSON.parse(stripJsonc(fs.readFileSync(newSettingsFile, 'utf8')));

const settingsFile = process.env.SETTINGS_FILE;
const existingText = fs.readFileSync(settingsFile, 'utf8');
const existingSettings = JSON.parse(stripJsonc(existingText));

// Merge settings - Islands Dark settings take precedence
const mergedSettings = { ...existingSettings, ...newSettings };

// Deep merge custom-ui-style.stylesheet
const stylesheetKey = 'custom-ui-style.stylesheet';
if (existingSettings[stylesheetKey] && newSettings[stylesheetKey]) {
    mergedSettings[stylesheetKey] = {
        ...existingSettings[stylesheetKey],
        ...newSettings[stylesheetKey]
    };
}

fs.writeFileSync(settingsFile, JSON.stringify(mergedSettings, null, 2));
console.log('Settings merged successfully');
NODE_SCRIPT
    else
        echo -e "${YELLOW}   Node.js not found. Please manually merge settings.json from this repo into your VS Code settings.${NC}"
        echo "   Your original settings have been backed up to settings.json.backup"
    fi
else
    # No existing settings, just copy
    cp "$SCRIPT_DIR/settings.json" "$SETTINGS_FILE"
    echo -e "${GREEN}✓ Settings applied${NC}"
fi

echo ""
echo "🚀 Step 5: Enabling Custom UI Style..."
echo "   $IDE_NAME will reload after applying changes..."

# Create a flag file to indicate first run
FIRST_RUN_FILE="$SCRIPT_DIR/.islands_dark_first_run"
if [ ! -f "$FIRST_RUN_FILE" ]; then
    touch "$FIRST_RUN_FILE"
    echo ""
    echo -e "${YELLOW}📝 Important Notes:${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   • Fonts have been installed automatically (requires reload to take effect)"
    else
        echo "   • IBM Plex Mono and FiraCode Nerd Font Mono need to be installed separately"
    fi
    echo "   • After $IDE_NAME reloads, you may see a 'corrupt installation' warning"
    echo "   • This is expected - click the gear icon and select 'Don't Show Again'"
    echo ""
    if [ -t 0 ]; then
        read -p "Press Enter to continue and reload $IDE_NAME..."
    fi
fi

# Reload IDE to apply changes
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "🎉 Islands Dark theme has been installed!"
echo "   $IDE_NAME will now reload to apply the custom UI style."
echo ""

# Use AppleScript on macOS to show a notification and reload IDE
if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e 'display notification "Islands Dark theme installed successfully!" with title "🏝️ Islands Dark"' 2>/dev/null || true
fi

echo "   Reloading $IDE_NAME..."
$CLI_CMD --reload-window 2>/dev/null || $CLI_CMD . 2>/dev/null || true

echo ""
echo -e "${GREEN}Done! 🏝️${NC}"

