# Snake: HTML-to-NES Port Strategy

This document records the main decisions and techniques used to turn the
original JavaScript/HTML Snake game into a playable NES ROM that runs in
accurate desktop emulators and browser-based EmulatorJS/Nestopia.

## 1. Preserve the gameplay contract first

The HTML version in `ports/web/index.html` was treated as the behavioral reference. Before optimizing
for visual fidelity, the port reproduced the important rules:

- The snake moves on a wrapped 32-column by 28-row playfield.
- Every completed move adds 1 point.
- Eating food adds 250 points and grows the snake by one segment.
- Self-collision ends the real game.
- Every five food pickups increases the level and reduces the movement delay.
- The food has a second sprite that orbits it.
- Background stars drift from right to left.

The title screen is an attract-mode demo. It moves and grows a demonstration
snake, but disables self-collision so it cannot end by itself. Pressing Start
always calls the normal game initializer, resetting the position, length,
score, speed, and demo mode.

## 2. Use a deliberately simple NES target

The ROM uses the smallest practical NES configuration:

- cc65 `ca65` assembles `ports/nes/src/snake.asm`.
- `ld65` links it with `ports/nes/src/nes.cfg`.
- Mapper 0 / NROM is used for broad emulator compatibility.
- The ROM uses one 16 KiB PRG bank mirrored by NROM-128 and initializes the
  8 KiB CHR-RAM pattern table from compact data stored in PRG-ROM.
- No mapper banking, expansion audio, or hardware-specific features are
  required.

This keeps the ROM compatible with EmulatorJS/Nestopia and ordinary desktop NES
emulators while keeping the cartridge image at about 16 KB instead of a padded
40 KB.

## 3. Organize the game around NMI frames

The 6502 main loop stays idle while the NMI handler performs frame work:

1. Read controller input.
2. Detect newly pressed buttons for Start/Pause transitions.
3. Advance the player or title demo movement timer.
4. Move the starfield and food orbit.
5. Redraw the nametable only when the screen state changes.
6. Build the current OAM sprite list.
7. DMA the previously built OAM page at the next frame's vblank start.

This matches the NES rendering model and avoids trying to update graphics from
the idle loop.

The OAM page is double-buffered in CPU RAM: the NMI transfers the completed
page first, then builds the next page after nametable updates. This keeps OAM
DMA inside the safe vblank window without delaying HUD writes.

All live nametable updates, including the score digits, temporarily disable
rendering and reset the PPU scroll latch afterward. This prevents accurate
PPU implementations from interpreting HUD writes as a mid-frame scroll
change.

## 4. Keep gameplay state in zero page

Frequently accessed values are stored in zero page for short, fast 6502
instructions:

- Snake X/Y arrays, length, and direction
- Food position and orbit phase
- Score, level, food count, and movement delay
- Controller state and rising-edge button state
- Game state and demo-mode flag

The snake body is shifted from the tail toward the head before the new head
is written. Collision checks happen against the proposed next head, with the
old tail treated as legal on a non-food move because it leaves that square on
the same tick.

## 5. Separate background and sprite responsibilities

The PPU nametable is used for stable text and screen-state content:

- Start, pause, game-over, and score text
- The live score strip is refreshed after each completed movement tick
- Screen clearing during state transitions

OAM is used for moving or highly visible objects:

- Food and its orbiting partner
- Gameplay and title stars

The gameplay snake body is written into the background nametable one movement
at a time. This is important on real NES hardware: a long horizontal snake can
put more than eight segments on one scanline, so keeping every segment in OAM
would make the PPU drop some of them. Food and its orbit are emitted first in
OAM so they retain priority over decorative sprites.

The title line-art logo is rendered as background nametable artwork rather
than OAM sprites. This keeps it visible on real NES hardware, where the
eight-sprites-per-scanline limit would otherwise drop parts of the logo.

The title demo snake also uses background tiles, and the static logo/text is
redrawn after each demo movement so the snake cannot erase the title artwork.

All gameplay snake segments intentionally use the same body tile. The title
logo uses dedicated line-art tiles assembled from multiple 8x8 sprites.

## 6. Respect NES sprite limits

The NES has 64 hardware sprites and a practical eight-sprites-per-scanline
limit. The port accounts for both:

- Gameplay OAM contains only food, its orbit, and a small set of stars; all 50 possible
  body segments are background tiles.
- The title logo and attract-mode demo snake use background tiles. Title OAM is
  reserved for the food, its orbit, and 12 stars, keeping decorative sprites
  well below the hardware scanline limit.
- This avoids both the 64-sprite limit and the eight-sprites-per-scanline
  overflow that exposed the earlier sprite-based logo implementation.

When the title demo grows, it continues moving and eating in background tiles
without consuming OAM slots. The actual player game retains the full 50-segment
maximum in the same background-tile path.

## 7. Handle browser and accurate-core failure modes

Several bugs only became obvious when the ROM was exercised in a browser core
and then checked against accurate desktop emulators:

- A transient `$FF` controller value after reset was ignored so the title did
  not start unexpectedly.
- Screen redraws were moved behind a `screen_dirty` flag. Food pickups update
  sprites and HUD state without clearing the nametable during active rendering.
  This fixed the blanking/score glitch seen during eating.
- Square-channel sound uses a zero length-counter value for a very short food
  beep instead of the long default tone.
- OAM is rebuilt every frame and transferred with DMA so stale sprites cannot
  remain visible.
- The score was moved from OAM into the first visible background row. Snake
  sprites use behind-background priority there, preventing top-row movement
  from hiding the digits or triggering sprite overflow.

## 8. Test the actual browser core

`ports/nes/web/test_nestopia.html` loads the ROM through the same EmulatorJS configuration as
the player, explicitly selects the Nestopia core, and drives the documented NES
input indices through EmulatorJS's `GameManager.simulateInput()` API. It checks
that the actual Nestopia instance creates a render canvas and exposes its NES
input path, then sends Start automatically. The active canvas remains visible
for frame-level visual checks.

This is intentionally a browser smoke test: EmulatorJS exposes input and save
state APIs, but not a stable public CPU-RAM/OAM inspection API. Detailed ROM
behavior should therefore be verified visually through this page and with a
real Nestopia/Mesen hardware-accuracy run.

## 9. Keep the browser player as a real test surface

`ports/nes/web/emulatorjs-player.html` is served over HTTP because browsers do not reliably load a
ROM with `file://` fetches. It embeds the official EmulatorJS loader, points it
at the local ROM with a cache-busting query, and selects the Nestopia NES core.
EmulatorJS owns the rendering, keyboard mapping, pause/reset menu, save states,
and touch-friendly virtual gamepad.

Visual checks in the built-in browser were used for title layout, food
animation, star movement, sprite appearance, responsive mobile layout, and the
final handheld-console styling. The browser smoke page and accurate desktop
emulators are the validation surfaces for the ROM.

## Build and run

```bash
./ports/nes/build.sh
python3 -m http.server 8000
```

Then open:

```text
http://localhost:8000/ports/nes/web/emulatorjs-player.html

http://localhost:8000/ports/nes/web/test_nestopia.html
```
