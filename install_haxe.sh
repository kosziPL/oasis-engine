#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}===================================================${NC}"
echo -e "${CYAN}   Haxe & Global Dependencies Installer (Lix)      ${NC}"
echo -e "${CYAN}          For FNF Psych Engine (Multi-distro)       ${NC}"
echo -e "${CYAN}===================================================${NC}"

# Check for Node.js, npm, git, unzip
echo -e "\n${BLUE}Verifying required system tools...${NC}"
for tool in node npm git unzip; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${RED}Error: Required tool '$tool' is not installed or not in PATH!${NC}"
        echo -e "Please install it using your distribution package manager (e.g. 'sudo pacman -S $tool')."
        exit 1
    fi
done
echo -e "Node.js: ${GREEN}$(node -v)${NC}"
echo -e "npm: ${GREEN}$(npm -v)${NC}"

# Install lix locally in the project as a devDependency (no global EACCES/permission errors)
echo -e "\n${BLUE}Installing lix package manager locally...${NC}"
npm ci

LIX_CMD="npx lix"

# Pin Haxe 4.2.5 in lix
echo -e "\n${BLUE}Installing and selecting Haxe 4.2.5...${NC}"
$LIX_CMD install haxe 4.2.5
$LIX_CMD use haxe 4.2.5

# Setup Haxerc to use Haxelib resolution
cat <<EOT > .haxerc
{
  "version": "4.2.5",
  "resolveLibs": "haxelib"
}
EOT

# Setup global haxelib directory in home folder (no sudo required!)
echo -e "\n${BLUE}Configuring global haxelib path in user home...${NC}"
mkdir -p ~/haxe/haxelib
npx haxelib setup ~/haxe/haxelib

# Determine Haxelib command with HTTP override to bypass HTTPS Eof issues
HAXELIB_CMD="npx haxelib"

# Install base libraries globally
echo -e "\n${BLUE}Installing base Haxe libraries globally...${NC}"
$HAXELIB_CMD install flixel 4.11.0 --always
$HAXELIB_CMD install flixel-addons 2.11.0 --always
$HAXELIB_CMD install flixel-ui 2.4.0 --always
$HAXELIB_CMD install hscript 2.5.0 --always
$HAXELIB_CMD install tjson 1.4.0 --always
$HAXELIB_CMD install hxjsonast 1.1.0 --always
$HAXELIB_CMD install hxCodec 2.5.1 --always
$HAXELIB_CMD install lime 7.9.0 --always
$HAXELIB_CMD install openfl 9.2.1 --always
$HAXELIB_CMD install hxcpp 4.3.2 --always
$HAXELIB_CMD install bson 0.1.0 --always

# Install git-based libraries globally
echo -e "\n${BLUE}Installing Git-based libraries globally...${NC}"
$HAXELIB_CMD git linc_luajit https://github.com/superpowers04/linc_luajit --always
$HAXELIB_CMD git hscript-ex https://github.com/ianharrigan/hscript-ex --always
$HAXELIB_CMD git discord_rpc https://github.com/Aidan63/linc_discord-rpc --always

# Initialize submodules in discord_rpc
echo -e "\n${BLUE}Initializing git submodules for global discord_rpc...${NC}"
DISCORD_RPC_PATH=$($HAXELIB_CMD path discord_rpc | grep -v '^\-' | head -n 1 || echo "$HOME/haxe/haxelib/discord_rpc/git")
if [ -d "$DISCORD_RPC_PATH" ]; then
    echo -e "Found discord_rpc at: ${GREEN}${DISCORD_RPC_PATH}${NC}"
    # Use subshell to avoid directory change affecting script flow
    (
        cd "$DISCORD_RPC_PATH"
        git submodule update --init --recursive
        
        # Patch GenericStringRef operator= in rapidjson/document.h for modern GCC compilers
        DOCUMENT_H_PATH="lib/rapidjson/include/rapidjson/document.h"
        if [ -f "$DOCUMENT_H_PATH" ]; then
            echo -e "Patching rapidjson/document.h for modern GCC compatibility..."
            sed -i 's/GenericStringRef& operator=(const GenericStringRef\& rhs) { s = rhs.s; length = rhs.length; }/\/\/ GenericStringRef\& operator=(const GenericStringRef\& rhs) { s = rhs.s; length = rhs.length; }/' "$DOCUMENT_H_PATH"
            echo -e "${GREEN}✔ Patched rapidjson successfully.${NC}"
        fi
    )
else
    echo -e "${RED}Warning: Could not find discord_rpc global path to update submodules.${NC}"
fi

echo -e "\n${GREEN}✔ Installation complete!${NC}"
echo -e "Haxe 4.2.5 and all fallback libraries are installed under your user home (no sudo/pacman required)."
echo -e "You can now run: ${YELLOW}./setup_local_libs.sh${NC} to configure the project."
