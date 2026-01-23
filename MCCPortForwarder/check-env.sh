#!/bin/bash

# Environment Check Script for MCC Port Forwarder

set -e

echo "🔍 Checking development environment..."
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track if all checks pass
ALL_CHECKS_PASSED=true

# Function to check command
check_command() {
    local cmd=$1
    local name=$2
    local install_hint=$3
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name: $(command -v $cmd)"
        if [ "$cmd" = "xcodegen" ]; then
            echo "  Version: $(xcodegen --version)"
        fi
        return 0
    else
        echo -e "${RED}✗${NC} $name not found"
        echo -e "  ${YELLOW}Install:${NC} $install_hint"
        ALL_CHECKS_PASSED=false
        return 1
    fi
}

# Function to check file
check_file() {
    local file=$1
    local name=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $name: $file"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $name not found: $file"
        return 1
    fi
}

# Function to check Xcode
check_xcode() {
    if xcodebuild -version &> /dev/null; then
        echo -e "${GREEN}✓${NC} Xcode installed"
        xcodebuild -version | head -n 1
        return 0
    else
        echo -e "${RED}✗${NC} Xcode not found"
        echo -e "  ${YELLOW}Install from App Store:${NC} https://apps.apple.com/app/xcode/id497799835"
        ALL_CHECKS_PASSED=false
        return 1
    fi
}

# Function to check macOS version
check_macos() {
    local version=$(sw_vers -productVersion)
    local major=$(echo "$version" | cut -d. -f1)
    
    echo "macOS version: $version"
    
    if [ "$major" -ge 13 ]; then
        echo -e "${GREEN}✓${NC} macOS 13.0+ required: OK"
        return 0
    else
        echo -e "${RED}✗${NC} macOS 13.0+ required, found: $version"
        ALL_CHECKS_PASSED=false
        return 1
    fi
}

echo "=== System ==="
check_macos
echo ""

echo "=== Required Tools ==="
check_xcode
check_command "xcodegen" "XcodeGen" "brew install xcodegen"
check_command "make" "Make" "xcode-select --install"
echo ""

echo "=== Optional Tools ==="
check_command "mcc" "MCC CLI" "Install mcc binary to /usr/local/bin/mcc"
check_command "git" "Git" "xcode-select --install"
echo ""

echo "=== Project Files ==="
check_file "project.yml" "XcodeGen config"
check_file "Makefile" "Makefile"
check_file "MCCPortForwarder/App/MCCPortForwarderApp.swift" "App entry point"
check_file "MCCPortForwarder/Models/Service.swift" "Data models"
check_file "MCCPortForwarder/Services/ProcessService.swift" "Process service"
check_file "MCCPortForwarder/ViewModels/AppViewModel.swift" "View model"
check_file "MCCPortForwarder/Views/ContentView.swift" "Main view"
echo ""

echo "=== Homebrew (optional) ==="
if command -v brew &> /dev/null; then
    echo -e "${GREEN}✓${NC} Homebrew: $(brew --version | head -n 1)"
else
    echo -e "${YELLOW}⚠${NC} Homebrew not found (optional)"
    echo "  Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
fi
echo ""

# Summary
echo "=== Summary ==="
if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ All required checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. make setup    # Generate Xcode project"
    echo "  2. make run      # Build and launch"
    echo ""
else
    echo -e "${RED}✗ Some checks failed${NC}"
    echo ""
    echo "Please install missing dependencies and run this script again."
    echo ""
    exit 1
fi

