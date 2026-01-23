#!/bin/bash

# MCC Port Forwarder - Project Setup Script

set -e

echo "🚀 Setting up MCCPortForwarder project..."

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "📦 XcodeGen not found. Installing via Homebrew..."
    
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Please install Homebrew first:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    brew install xcodegen
fi

# Generate Xcode project
echo "🔨 Generating Xcode project..."
xcodegen generate

echo "✅ Project setup complete!"
echo ""
echo "Next steps:"
echo "  1. open MCCPortForwarder.xcodeproj"
echo "  2. Select 'MCCPortForwarder' scheme"
echo "  3. Press ⌘+R to build and run"
echo ""
echo "The app will appear in your status bar."

