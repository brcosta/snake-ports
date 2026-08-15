# NES Snake Game

A classic snake game ported to the Nintendo Entertainment System (NES).

## Requirements

- **Assembler**: [cc65](https://cc65.github.io/) suite (ca65 assembler, ld65 linker)
- **Emulator**: Any NES emulator (FCEUX, Nestopia, Mesen, etc.)

## Building

### macOS
```bash
brew install cc65
./build.sh
```

### Ubuntu/Debian
```bash
sudo apt install cc65
./build.sh
```

### Windows
1. Download cc65 from https://github.com/cc65/cc65/releases
2. Add to PATH
3. Run: `build.bat` or manually:
   ```
   ca65 snake.asm -o snake.o
   ld65 -C nes.cfg snake.o -o snake.nes
   ```

### EmulatorJS browser player

The ROM is mapper-0/NROM and can be loaded by EmulatorJS using its Nestopia
NES core. A local portable-console player is included for testing:

```bash
python3 -m http.server
```

Open `http://localhost:8000/jsnes-player.html`. EmulatorJS provides the
keyboard, touch, pause, reset, and save-state controls; the ROM title screen
still starts gameplay only when Start is pressed.

## Playing

1. Open `snake.nes` in your NES emulator
2. Use arrow keys to control the snake
3. Eat the food (green dot) to grow and score points
4. Avoid hitting yourself!
5. Speed increases with level

## Controls

| Key | Action |
|-----|--------|
| Arrow Keys | Move snake |
| Start (Enter) | Start/Pause |
| A (Z) | Not used |
| B (X) | Not used |

## Files

- `snake.asm` - Main game source code (6502 assembly)
- `nes.inc` - NES hardware definitions
- `nes.cfg` - Linker configuration
- `build.sh` - Build script (macOS/Linux)
- `snake.nes` - Output ROM (after building)
- `jsnes-player.html` - Local EmulatorJS/Nestopia player for testing the ROM in a browser
- `test_nestopia.html` - EmulatorJS/Nestopia rendered-frame smoke test

## Technical Details

- **CPU**: 6502 @ 1.79 MHz
- **Resolution**: 256x240 pixels
- **Graphics**: 8x8 pixel tiles
- **Memory**: 2KB RAM + 16KB NROM-128 PRG-ROM + 8KB CHR-RAM

## Credits

Original 2D web version by _Faster (2003)
NES port by Claude (2024)
