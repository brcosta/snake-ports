# Snake! — NES port

This directory contains the cc65 6502 source, build script, ROMs, and browser
player for the Nintendo Entertainment System port.

## Build

Install the [cc65](https://cc65.github.io/) suite, then run this directory's
script from anywhere:

```bash
./ports/nes/build.sh
```

The output is written to `ports/nes/roms/snake.nes`.

## Play

- Open `roms/snake.nes` in Mesen, Nestopia, FCEUX, or another NES emulator.
- Serve the repository with a local HTTP server and open
  `web/jsnes-player.html` for the portable EmulatorJS/Nestopia player.
- `web/test_nestopia.html` is a small rendered-frame and input smoke test.

Gameplay starts only after pressing Start. Arrow keys steer the snake; Start
pauses or resumes the game. Eating food grows the snake, awards a bonus, and
eventually increases the speed.

## Technical profile

- Mapper 0 / NROM-128
- 16 KiB PRG-ROM with the NROM mirror and CHR data packed into the image
- 256×240 NES frame with an 8×8 tile graphics system
- cc65 `ca65` assembly and `ld65` linking
- OAM is reserved for food, its orbiting marker, and stars; the snake body is
  drawn with background tiles to avoid the NES eight-sprites-per-scanline
  limit
