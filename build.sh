#!/bin/bash
# Build script for NES Snake Game

echo "Building NES Snake ROM..."

# Check if ca65 is installed
if ! command -v ca65 &> /dev/null; then
    echo "Error: ca65 assembler not found!"
    echo ""
    echo "Install cc65 suite:"
    echo "  macOS: brew install cc65"
    echo "  Ubuntu: sudo apt install cc65"
    echo "  Windows: Download from https://cc65.github.io/"
    echo ""
    echo "Or download pre-built binaries from: https://github.com/cc65/cc65/releases"
    exit 1
fi

# Assemble
echo "Assembling..."
ca65 snake.asm -o snake.o

if [ $? -ne 0 ]; then
    echo "Assembly failed!"
    exit 1
fi

# Link
echo "Linking..."
ld65 -C nes.cfg snake.o -o snake.nes

if [ $? -ne 0 ]; then
    echo "Linking failed!"
    exit 1
fi

echo ""
echo "Build successful! ROM: snake.nes"
echo ""
echo "To play:"
echo "  1. Open snake.nes in an NES emulator (FCEUX, Nestopia, Mesen, etc.)"
echo "  2. Arrow keys to move snake"
echo "  3. Eat food to grow and score points"
echo ""
echo "Download emulators:"
echo "  FCEUX: https://fceux.com/"
echo "  Nestopia: https://nestopia.sourceforge.net/"
echo "  Mesen: https://www.mesen.ca/"
