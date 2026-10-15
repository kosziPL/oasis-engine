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
echo -e "${CYAN}        Local Libraries Setup for FNF Project       ${NC}"
echo -e "${CYAN}===================================================${NC}"

# Check for Node.js and npm
if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    echo -e "${RED}Error: Node.js or npm is not installed or not in PATH!${NC}"
    echo -e "Please run ${YELLOW}./install_haxe.sh${NC} first to install dependencies."
    exit 1
fi

PROJECT_DIR=$(pwd)
echo -e "Project Directory: ${GREEN}${PROJECT_DIR}${NC}"

# 1. Configure .haxerc file in project root to delegate resolving libraries to haxelib
echo -e "\n${BLUE}[1/2] Configuring .haxerc...${NC}"
cat <<EOT > .haxerc
{
  "version": "4.2.5",
  "resolveLibs": "haxelib"
}
EOT
echo -e "${GREEN}✔ Configured .haxerc to use Haxe 4.2.5 with Haxelib resolution. ${NC}"

# 2. Set up local .haxelib folder if pre-configured zip exists
echo -e "\n${BLUE}[2/2] Setting up local libraries...${NC}"
OAZA_ZIP="${PROJECT_DIR}/.haxelib.zip"

if [ -f "$OAZA_ZIP" ]; then
    echo -e "${YELLOW}Detected pre-configured libraries archive at Oaza: $OAZA_ZIP${NC}"
    echo -e "${BLUE}Extracting cached libraries to speed up setup...${NC}"
    if [ -d ".haxelib" ]; then
        echo -e "${YELLOW}Warning: .haxelib folder already exists. Backing it up...${NC}"
        mv .haxelib .haxelib.bak_$(date +%s)
    fi
    unzip -q "$OAZA_ZIP" -d "$PROJECT_DIR"
    echo -e "${GREEN}✔ Extracted pre-configured libraries from Oaza!${NC}"
    
    # Proactively patch GenericStringRef operator= in rapidjson/document.h for GCC compatibility
    LOCAL_DOC_H=$(find .haxelib/discord_rpc -name "document.h" 2>/dev/null | head -n 1 || true)
    if [ -n "$LOCAL_DOC_H" ] && [ -f "$LOCAL_DOC_H" ]; then
        echo -e "Patching local rapidjson/document.h in .haxelib for GCC compatibility..."
        sed -i 's/GenericStringRef& operator=(const GenericStringRef\& rhs) { s = rhs.s; length = rhs.length; }/\/\/ GenericStringRef\& operator=(const GenericStringRef\& rhs) { s = rhs.s; length = rhs.length; }/' "$LOCAL_DOC_H"
        echo -e "${GREEN}✔ Local rapidjson patched successfully.${NC}"
    fi
elif [ -d ".haxelib" ]; then
    echo -e "${GREEN}✔ Local .haxelib directory already exists. Using it.${NC}"
    
    # Proactively patch existing local libraries too if needed
    LOCAL_DOC_H=$(find .haxelib/discord_rpc -name "document.h" 2>/dev/null | head -n 1 || true)
    if [ -n "$LOCAL_DOC_H" ] && [ -f "$LOCAL_DOC_H" ]; then
        echo -e "Patching local rapidjson/document.h in .haxelib for GCC compatibility..."
        sed -i 's/GenericStringRef& operator=(const GenericStringRef\& rhs) { s = rhs.s; length = rhs.length; }/\/\/ GenericStringRef\& operator=(const GenericStringRef\& rhs) { s = rhs.s; length = rhs.length; }/' "$LOCAL_DOC_H"
        echo -e "${GREEN}✔ Local rapidjson patched successfully.${NC}"
    fi
else
    echo -e "${YELLOW}No local .haxelib directory or pre-configured zip found at $OAZA_ZIP.${NC}"
    echo -e "${BLUE}Fallback: The project will use the global libraries installed in the system.${NC}"
fi

echo -e "\n${GREEN}✔ Project libraries successfully configured!${NC}"
echo -e "To compile/run, you can use: ${YELLOW}lime test linux${NC}"
