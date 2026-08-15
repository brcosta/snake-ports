; SNAKE! - playable NES port of the original HTML game
; Mapper 0 / NROM-128, 16 KiB PRG-ROM, 8 KiB CHR-RAM.
; The ROM deliberately uses only standard NES features so it runs in
; EmulatorJS/Nestopia and on real NROM hardware.

.include "nes.inc"

; -----------------------------------------------------------------------------
; iNES header
; -----------------------------------------------------------------------------
.segment "HEADER"
  .byte "NES", $1A
  .byte 1                         ; 16 KiB PRG-ROM, mirrored at $C000
  .byte 0                         ; CHR-RAM, initialized by reset
  .byte $01                       ; vertical mirroring
  .byte 0, 0, 0, 0, 0, 0, 0, 0

; -----------------------------------------------------------------------------
; Constants
; -----------------------------------------------------------------------------
STATE_TITLE = 0
STATE_GAME  = 1
STATE_OVER  = 2
STATE_PAUSE = 3

DIR_LEFT  = 0
DIR_RIGHT = 1
DIR_UP    = 2
DIR_DOWN  = 3

TILE_BODY = 1
TILE_HEAD = 2
TILE_FOOD = 3
TILE_A    = 4
TILE_0    = 30
TILE_COLON = 40
TILE_EXCL  = 41
TILE_STAR  = 43
TILE_LOGO_FIRST = 44

GRID_TOP    = 2
GRID_BOTTOM = 28
MAX_SNAKE   = 50
MOVE_FRAMES = 4
TITLE_MOVE_FRAMES = 2
MIN_MOVE_FRAMES = 2
FOODS_PER_LEVEL = 5
DEMO_MAX_SNAKE = 18

; -----------------------------------------------------------------------------
; Zero page state
; -----------------------------------------------------------------------------
.segment "ZEROPAGE"
snake_x:       .res 50
snake_y:       .res 50
snake_len:     .res 1
snake_head_index: .res 1
snake_dir:     .res 1
food_x:        .res 1
food_y:        .res 1
frame:         .res 1
move_timer:    .res 1
pad1:          .res 1
prev_pad:      .res 1
new_buttons:   .res 1
game_state:    .res 1
score:         .res 1
score_hi:      .res 1
seed_lo:       .res 1
seed_hi:       .res 1
temp_x:        .res 1
temp_y:        .res 1
temp_value:    .res 1
screen_dirty:  .res 1
text_ptr:      .res 2
hud_chars:     .res 11
food_count:    .res 1
level:         .res 1
move_delay:    .res 1
star_x:        .res 6
title_star_x:  .res 12
food_phase:    .res 1
demo_mode:     .res 1
score_dirty:   .res 1
snake_bg_dirty:.res 1
tail_x:        .res 1
tail_y:        .res 1
snake_bg_grew: .res 1
bg_x:          .res 1
bg_y:          .res 1
bg_tile:       .res 1
render_pending: .res 1
cell_ptr:      .res 2
cell_value:    .res 1

.segment "BSS"
; One byte per board cell makes collision and food placement constant-time.
; The board is 32x32 while the playable rows are 2..28.
occupancy:     .res 1024

; -----------------------------------------------------------------------------
; Reset and main loop
; -----------------------------------------------------------------------------
.segment "CODE"

reset:
  SEI
  CLD
  LDX #$40
  STX CTRL2
  LDX #$FF
  TXS
  INX
  STX PPU_CTRL
  STX PPU_MASK
  STX DMC_FREQ

  ; Wait for the PPU to leave power-on vblank, then initialize once more after
  ; the first frame. This is accepted by real hardware and accurate cores.
@wait_vblank_1:
  BIT PPU_STATUS
  BPL @wait_vblank_1
@wait_vblank_2:
  BIT PPU_STATUS
  BPL @wait_vblank_2

  JSR hide_oam
  JSR load_chr
  JSR load_palette
  JSR clear_nametable
  JSR init_game

  ; Start with a known unscrolled viewport and VRAM address.
  JSR reset_ppu_origin

  LDA #$80
  STA PPU_CTRL                    ; enable NMI, increment PPU address by 1
  LDA #$1E
  STA PPU_MASK                    ; show background and sprites
  CLI

@forever:
  JMP @forever

; -----------------------------------------------------------------------------
; NMI: input, game tick, screen updates and sprite DMA
; -----------------------------------------------------------------------------
nmi:
  PHA
  TXA
  PHA
  TYA
  PHA

  ; A complete nametable redraw is allowed to run past the current vblank,
  ; but it leaves rendering disabled so no partial frame is shown. Re-enable
  ; only at the start of the following vblank.
  LDA render_pending
  BEQ @render_ready
  LDA #0
  STA render_pending
  LDA #$1E
  STA PPU_MASK
@render_ready:
  ; Reassert the visible origin every frame. The PPU's VRAM address advances
  ; during rendering even when no nametable update is requested, so restoring
  ; it only after dirty writes can leave the HUD at a stable but shifted
  ; position.
  JSR reset_ppu_origin

  ; DMA must happen before game logic. Collision/shift work grows with the
  ; snake, so doing this later makes accurate PPUs flicker as the body grows.
  ; The page was prepared by the previous NMI and will be rebuilt below.
  LDA #0
  STA OAM_ADDR
  LDA #$02
  STA OAM_DMA

  ; Refresh the HUD at the start of vblank. Game logic below can run long
  ; enough to reach visible scanlines, where a PPU mask/address update would
  ; clip the score glyphs. A one-frame-late HUD update is preferable to a
  ; partially rendered score.
  LDA game_state
  CMP #STATE_GAME
  BNE @score_ready_early
  LDA score_dirty
  BEQ @score_ready_early
  JSR update_score
  LDA #0
  STA score_dirty
@score_ready_early:

  JSR read_controller
  ; Some browser front ends can return a transient $FF while the controller
  ; shift register settles after reset. Treat it as no input so the title
  ; screen does not start by itself.
  LDA pad1
  CMP #$FF
  BNE @buttons_ok
  LDA #0
  STA pad1
@buttons_ok:
  LDA pad1
  EOR #$FF
  AND prev_pad
  STA new_buttons
  LDA pad1
  STA prev_pad

  JSR handle_input

  LDA game_state
  CMP #STATE_TITLE
  BEQ @tick_demo
  CMP #STATE_GAME
  BNE @not_playing
@tick_demo:
  INC move_timer
  LDA move_timer
  CMP move_delay
  BCC @not_playing
  LDA #0
  STA move_timer
  LDA game_state
  CMP #STATE_TITLE
  BNE @play_step
  JSR demo_autopilot
@play_step:
  JSR step_game
@not_playing:

  LDA game_state
  CMP #STATE_TITLE
  BEQ @animate_title
  CMP #STATE_GAME
  BNE @skip_stars
  JSR animate_stars
  JMP @advance_orbit
@animate_title:
  JSR animate_title_stars
@advance_orbit:
  ; Advance the orbit once every eight frames, not every frame, so the
  ; four-position sparkle reads as a gentle rotation.
  INC frame
  LDA frame
  AND #7
  BNE @skip_food_phase
  INC food_phase
  LDA food_phase
  AND #3
  STA food_phase
@skip_food_phase:
@skip_stars:

  LDA screen_dirty
  BEQ @screen_ready
  JSR draw_current_screen
  LDA #0
  STA screen_dirty
@screen_ready:

  ; Gameplay body tiles are updated only after a movement or a screen
  ; transition. This keeps the whole snake visible without spending OAM
  ; scanline slots on every segment.
  LDA game_state
  CMP #STATE_GAME
  BEQ @maybe_draw_body
  CMP #STATE_TITLE
  BNE @background_ready
@maybe_draw_body:
  LDA snake_bg_dirty
  BEQ @background_ready
  JSR draw_snake_background
  LDA #0
  STA snake_bg_dirty
@background_ready:

  ; Build OAM after nametable updates so the PPU address/scroll writes are
  ; complete before the DMA transfer.
  LDA game_state
  CMP #STATE_GAME
  BEQ @draw_game_oam
  CMP #STATE_PAUSE
  BEQ @draw_game_oam
  CMP #STATE_TITLE
  BEQ @draw_title_oam
  JMP @dma
@draw_title_oam:
  JSR build_title_oam
  JMP @dma
@draw_game_oam:
  JSR build_oam
@dma:
  PLA
  TAY
  PLA
  TAX
  PLA
  RTI

; -----------------------------------------------------------------------------
; Controller and menu input
; -----------------------------------------------------------------------------
read_controller:
  LDA #1
  STA CTRL1
  LDA #0
  STA CTRL1
  STA pad1
  LDX #8
  LDA #0
@read:
  LDA CTRL1
  LSR A
  ROL pad1
  DEX
  BNE @read
  RTS

handle_input:
  LDA game_state
  CMP #STATE_TITLE
  BEQ @title
  CMP #STATE_OVER
  BEQ @over
  CMP #STATE_PAUSE
  BEQ @pause

  ; Start pauses the game on its rising edge.
  LDA new_buttons
  AND #BTN_START
  BEQ @direction
  LDA #STATE_PAUSE
  STA game_state
  LDA #1
  STA screen_dirty
  RTS

@direction:
  ; A direction can be held. Opposite turns are ignored.
  LDA pad1
  AND #BTN_UP
  BEQ @down
  LDA snake_dir
  CMP #DIR_DOWN
  BEQ @down
  LDA #DIR_UP
  STA snake_dir
@down:
  LDA pad1
  AND #BTN_DOWN
  BEQ @left
  LDA snake_dir
  CMP #DIR_UP
  BEQ @left
  LDA #DIR_DOWN
  STA snake_dir
@left:
  LDA pad1
  AND #BTN_LEFT
  BEQ @right
  LDA snake_dir
  CMP #DIR_RIGHT
  BEQ @right
  LDA #DIR_LEFT
  STA snake_dir
@right:
  LDA pad1
  AND #BTN_RIGHT
  BEQ @done
  LDA snake_dir
  CMP #DIR_LEFT
  BEQ @done
  LDA #DIR_RIGHT
  STA snake_dir
@done:
  RTS

@title:
  LDA new_buttons
  AND #(BTN_START | BTN_UP | BTN_DOWN | BTN_LEFT | BTN_RIGHT)
  BEQ @done
  JSR start_game
  RTS

@over:
  LDA new_buttons
  AND #BTN_START
  BEQ @done
  JSR start_game
  RTS

@pause:
  LDA new_buttons
  AND #BTN_START
  BEQ @done
  LDA #STATE_GAME
  STA game_state
  LDA #1
  STA screen_dirty
  STA snake_bg_dirty
  LDA #2
  STA snake_bg_grew
  RTS

; -----------------------------------------------------------------------------
; Game state
; -----------------------------------------------------------------------------
start_game:
  JSR init_game
  ; The title uses OAM slots 5..13 for its decorative stars. The playable
  ; screen only uses the first five slots, so clear that tail once here
  ; instead of paying to clear all 64 sprites every NMI.
  JSR hide_title_tail
  LDA #0
  STA demo_mode
  LDA #MOVE_FRAMES
  STA move_delay
  ; init_game creates the attract-mode food in its safe lower band. Respawn
  ; once after switching to play so the player gets the normal full field.
  JSR spawn_food
  LDA #1
  STA score_dirty
  STA snake_bg_dirty
  LDA #2
  STA snake_bg_grew
  LDA #STATE_GAME
  STA game_state
  LDA #1
  STA screen_dirty
  RTS

init_game:
  LDA #16
  STA snake_x
  LDA #15
  STA snake_x+1
  LDA #14
  STA snake_x+2
  LDA #15
  STA snake_y
  STA snake_y+1
  STA snake_y+2
  LDA #3
  STA snake_len
  LDA #0
  STA snake_head_index
  LDA #DIR_RIGHT
  STA snake_dir
  LDA #0
  STA frame
  STA move_timer
  STA prev_pad
  STA new_buttons
  STA render_pending
  STA score
  STA score_hi
  STA score_dirty
  STA food_count
  STA level
  STA food_phase
  LDA #1
  STA snake_bg_dirty
  LDA #2
  STA snake_bg_grew
  LDA #1
  STA demo_mode
  LDA #TITLE_MOVE_FRAMES
  STA move_delay
  LDX #0
@copy_stars:
  LDA game_star_x,X
  STA star_x,X
  INX
  CPX #5
  BNE @copy_stars
  LDX #0
@copy_title_stars:
  LDA title_star_start_x,X
  STA title_star_x,X
  INX
  CPX #12
  BNE @copy_title_stars
  LDA #$5A
  STA seed_lo
  LDA #$A7
  STA seed_hi

  ; Reset the constant-time board occupancy map, then mark the initial body.
  LDA #0
  LDX #0
@clear_occupancy:
  STA occupancy,X
  STA occupancy+256,X
  STA occupancy+512,X
  STA occupancy+768,X
  INX
  BNE @clear_occupancy
  LDA #1
  STA cell_value
  LDA snake_x
  STA temp_x
  LDA snake_y
  STA temp_y
  JSR set_cell
  LDA snake_x+1
  STA temp_x
  LDA snake_y+1
  STA temp_y
  JSR set_cell
  LDA snake_x+2
  STA temp_x
  LDA snake_y+2
  STA temp_y
  JSR set_cell
  JSR spawn_food
  LDA #STATE_TITLE
  STA game_state
  LDA #1
  STA screen_dirty
  RTS

; Advance a 16-bit LCG. The low byte is enough for x and the high byte for y.
random16:
  LDA seed_lo
  ASL A
  ROL seed_hi
  ASL A
  ROL seed_hi
  ASL A
  ROL seed_hi
  CLC
  ADC seed_lo
  STA seed_lo
  LDA seed_hi
  ADC #$13
  STA seed_hi
  RTS

spawn_food:
  LDX #0
@try:
  JSR random16
  LDA seed_lo
  AND #$1F
  STA food_x
  LDA demo_mode
  BEQ @normal_y
  ; Keep the attract snake below the logo and PRESS START artwork. This lets
  ; the title stay in the nametable without a long mid-frame logo redraw.
  LDA seed_hi
  AND #$07
  CLC
  ADC #20
  STA food_y
  JMP @y_ready
@normal_y:
  LDA seed_hi
  AND #$1F
  CMP #27
  BCC @y_ok
  AND #$1A
@y_ok:
  CLC
  ADC #2
  STA food_y
@y_ready:

  ; Avoid the snake with a constant-time occupancy lookup. A retry is cheap
  ; on this mostly empty board and does not grow with snake length.
  LDA food_x
  STA temp_x
  LDA food_y
  STA temp_y
  JSR cell_occupied
  BNE @try
  RTS

; Return the occupancy byte for temp_x/temp_y in A.
cell_occupied:
  JSR cell_pointer
  LDY #0
  LDA (cell_ptr),Y
  RTS

; Write cell_value to the occupancy byte for temp_x/temp_y.
set_cell:
  JSR cell_pointer
  LDY #0
  LDA cell_value
  STA (cell_ptr),Y
  RTS

; Form &occupancy[(temp_y * 32) + temp_x] in cell_ptr.
cell_pointer:
  LDA temp_y
  LSR A
  LSR A
  LSR A
  CLC
  ADC #>occupancy
  STA cell_ptr+1

  ; The low five bits of y form the low byte of y*32. Keep this separate so
  ; rows 8..28 do not alias the first eight rows in the one-byte accumulator.
  LDA temp_y
  AND #7
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  CLC
  ADC temp_x
  CLC
  ADC #<occupancy
  STA cell_ptr
  BCC @done
  INC cell_ptr+1
@done:
  RTS

; Load the current head coordinates into temp_x/temp_y.
load_head:
  LDX snake_head_index
  LDA snake_x,X
  STA temp_x
  LDA snake_y,X
  STA temp_y
  RTS

; Load the current tail coordinates into tail_x/tail_y.
load_tail:
  LDA snake_head_index
  CLC
  ADC snake_len
  SEC
  SBC #1
  CMP #MAX_SNAKE
  BCC @tail_index_ready
  SEC
  SBC #MAX_SNAKE
@tail_index_ready:
  TAX
  LDA snake_x,X
  STA tail_x
  LDA snake_y,X
  STA tail_y
  RTS

add_score_move:
  INC score
  BNE @mark_dirty
  INC score_hi
@mark_dirty:
  LDA #1
  STA score_dirty
  RTS

add_score_food:
  LDA score
  CLC
  ADC #250
  STA score
  LDA score_hi
  ADC #0
  STA score_hi
  LDA #1
  STA score_dirty
  RTS

demo_autopilot:
  ; The title screen attract mode chases the food like the web version.
  ; It intentionally does not test the body for collisions; this is a demo,
  ; not a playable run, and Start will reset everything before play begins.
  JSR load_head
  LDA temp_x
  CMP food_x
  BEQ @vertical
  BCC @right
  LDA #DIR_LEFT
  STA snake_dir
  RTS
@right:
  LDA #DIR_RIGHT
  STA snake_dir
  RTS
@vertical:
  LDA temp_y
  CMP food_y
  BEQ @done
  BCC @down
  LDA #DIR_UP
  STA snake_dir
  RTS
@down:
  LDA #DIR_DOWN
  STA snake_dir
@done:
  RTS

step_game:
  ; Compute the next head with wraparound. The playable rows are 1..28;
  ; row 0 is reserved for the score/status strip.
  JSR load_head
  LDA snake_dir
  CMP #DIR_LEFT
  BNE @right
  LDA temp_x
  BNE @left_step
  LDA #31
  STA temp_x
  JMP @next_head
@left_step:
  DEC temp_x
  JMP @next_head
@right:
  CMP #DIR_RIGHT
  BNE @up
  INC temp_x
  LDA temp_x
  CMP #32
  BCC @next_head
  LDA #0
  STA temp_x
  JMP @next_head
@up:
  CMP #DIR_UP
  BNE @down
  LDA temp_y
  CMP #GRID_TOP
  BNE @up_step
  LDA #GRID_BOTTOM
  STA temp_y
  JMP @next_head
@up_step:
  DEC temp_y
  JMP @next_head
@down:
  INC temp_y
  LDA temp_y
  CMP #(GRID_BOTTOM + 1)
  BCC @next_head
  LDA #GRID_TOP
  STA temp_y
@next_head:

  ; Preserve the proposed head while the tail is temporarily used as the
  ; occupancy-map write target below.
  LDA temp_x
  STA bg_x
  LDA temp_y
  STA bg_y

  ; Save the tail before collision resolution. The tail is allowed as a
  ; destination on a non-food move because it leaves this frame.
  JSR load_tail

  ; Match the HTML game: every completed movement is worth one point. Food
  ; adds its bonus below, after collision and growth have been resolved.
  LDA demo_mode
  BNE @skip_demo_move_score
  JSR add_score_move
@skip_demo_move_score:

  ; Decide whether this move eats before changing the body. That lets the
  ; collision test distinguish the tail, which is about to move away, from a
  ; real self-hit.
  LDA temp_x
  CMP food_x
  BNE @not_food
  LDA temp_y
  CMP food_y
  BNE @not_food
  LDA #1
  STA temp_value
  JMP @check_collision
@not_food:
  LDA #0
  STA temp_value

@check_collision:
  LDA demo_mode
  BNE @move_body
  JSR cell_occupied
  BEQ @move_body
  LDA temp_value
  BNE @game_over
  ; Without food, the old tail is legal because it moves this tick.
  LDA temp_x
  CMP tail_x
  BNE @game_over
  LDA temp_y
  CMP tail_y
  BEQ @move_body
  JMP @game_over
@game_over:
  LDA #STATE_OVER
  STA game_state
  ; Hide the five gameplay sprites once. The over screen leaves OAM alone on
  ; later frames, keeping the NMI short enough for the vblank window.
  JSR hide_game_oam
  LDA #1
  STA screen_dirty
  RTS

  ; Shift the body, then write the new head.
@move_body:
  ; Keep the old tail so the background renderer can erase it after the
  ; sprite-free snake has been shifted. A food move grows instead of erasing.
  LDA temp_value
  BEQ @drop_tail_cell
  LDA demo_mode
  BNE @demo_growth_limit
  LDA snake_len
  CMP #MAX_SNAKE
  BCS @drop_tail_cell
  JMP @mark_growth
@demo_growth_limit:
  LDA snake_len
  CMP #DEMO_MAX_SNAKE
  BCS @drop_tail_cell
@mark_growth:
  LDA #1
  STA snake_bg_grew
  JMP @put_head
@drop_tail_cell:
  LDA #0
  STA cell_value
  LDA tail_x
  STA temp_x
  LDA tail_y
  STA temp_y
  JSR set_cell
  LDA #0
  STA snake_bg_grew
@put_head:
  LDA bg_x
  STA temp_x
  LDA bg_y
  STA temp_y
  LDA snake_head_index
  BNE @previous_head_index
  LDA #MAX_SNAKE-1
  JMP @store_head_index
@previous_head_index:
  SEC
  SBC #1
@store_head_index:
  STA snake_head_index
  TAX
  LDA temp_x
  STA snake_x,X
  LDA temp_y
  STA snake_y,X
  LDA #1
  STA cell_value
  JSR set_cell
  LDA #1
  STA snake_bg_dirty

  LDA temp_value
  BEQ @done
  LDA demo_mode
  BNE @demo_food
  JSR add_score_food
  JSR play_eat_sound
@demo_food:
  INC food_count
  LDA snake_len
  LDA demo_mode
  BEQ @normal_growth_limit
  LDA snake_len
  CMP #DEMO_MAX_SNAKE
  BCS @level_up_check
  INC snake_len
  JMP @new_food
@normal_growth_limit:
  LDA snake_len
  CMP #MAX_SNAKE
  BCS @level_up_check
  INC snake_len
@level_up_check:
  LDA food_count
  CMP #FOODS_PER_LEVEL
  BCC @new_food
  LDA #0
  STA food_count
  INC level
  LDA move_delay
  CMP #(MIN_MOVE_FRAMES + 1)
  BCC @new_food
  DEC move_delay
@new_food:
  JSR spawn_food
@done:
  RTS

play_eat_sound:
  ; Short bright pulse on channel 1 for food pickup.
  LDA #$01
  STA APU_STATUS
  LDA #$9F                    ; 50% duty, constant volume 15
  STA SQ1_VOL
  LDA #0
  STA SQ1_SWEEP
  LDA #$70                    ; high, chirpy pitch
  STA SQ1_LO
  LDA #$00                    ; shortest length counter: quick beep
  STA SQ1_HI
  RTS

; -----------------------------------------------------------------------------
; PPU and screen drawing
; -----------------------------------------------------------------------------
load_palette:
  BIT PPU_STATUS
  LDA #$3F
  STA PPU_ADDR
  LDA #$00
  STA PPU_ADDR
  LDX #0
@loop:
  LDA palette_data,X
  STA PPU_DATA
  INX
  CPX #32
  BNE @loop
  RTS

load_chr:
  ; NROM-128 cartridges with a zero CHR-bank count provide 8 KiB of CHR-RAM.
  ; Copy the compact pattern data from PRG-ROM during reset so the final ROM
  ; does not need a separate padded 8 KiB CHR-ROM bank.
  BIT PPU_STATUS
  LDA #$00
  STA PPU_ADDR
  STA PPU_ADDR
  LDA #<chr_data
  STA text_ptr
  LDA #>chr_data
  STA text_ptr+1
  LDY #0
  LDX #5
@page:
  LDA (text_ptr),Y
  STA PPU_DATA
  INY
  BNE @page
  INC text_ptr+1
  DEX
  BNE @page
  RTS

clear_nametable:
  BIT PPU_STATUS
  LDA #$20
  STA PPU_ADDR
  LDA #$00
  STA PPU_ADDR
  LDA #0
  LDY #30
@row:
  LDX #32
@col:
  STA PPU_DATA
  DEX
  BNE @col
  DEY
  BNE @row

  ; Clear the 64-byte attribute table too. Leaving it uninitialized makes
  ; background logo colors depend on the emulator or console power state.
  LDY #2
@attr_row:
  LDX #32
@attr_byte:
  STA PPU_DATA
  DEX
  BNE @attr_byte
  DEY
  BNE @attr_row
  RTS

set_text_address:
  BIT PPU_STATUS               ; reset the PPUADDR/PPUSCROLL write latch
  STA PPU_ADDR
  STX PPU_ADDR
  RTS

; Restore both halves of the PPU viewport after nametable writes. PPUSCROLL
; changes the temporary scroll address, while PPUDATA advances the current
; VRAM address. Resetting only PPUSCROLL leaves the next frame starting at the
; last tile written, which appears as a vertical screen jump on accurate PPUs.
reset_ppu_origin:
  BIT PPU_STATUS
  LDA #$20
  STA PPU_ADDR
  LDA #0
  STA PPU_ADDR
  LDA #0
  STA PPU_SCROLL
  STA PPU_SCROLL
  RTS

write_text:
  LDY #0
@loop:
  LDA (text_ptr),Y
  CMP #$FF
  BEQ @done
  STA PPU_DATA
  INY
  BNE @loop
@done:
  RTS

draw_title_logo:
  ; Three 17-tile rows at nametable row 6, column 7. The logo tiles are
  ; background tiles now, so every pixel survives real NES sprite overflow.
  LDA #$20
  LDX #$C8
  JSR set_text_address
  LDA #<title_logo_row0
  STA text_ptr
  LDA #>title_logo_row0
  STA text_ptr+1
  JSR write_text

  LDA #$20
  LDX #$E8
  JSR set_text_address
  LDA #<title_logo_row1
  STA text_ptr
  LDA #>title_logo_row1
  STA text_ptr+1
  JSR write_text

  LDA #$21
  LDX #$08
  JSR set_text_address
  LDA #<title_logo_row2
  STA text_ptr
  LDA #>title_logo_row2
  STA text_ptr+1
  JSR write_text

  ; Select background palette 3 for the logo's two attribute bands. The
  ; separate palette gives it the bright yellow used by the web version.
  LDA #$23
  LDX #$C9                     ; attribute row 1, column 1
  JSR set_text_address
  LDA #$F0
  LDY #6
@logo_attr_upper:
  STA PPU_DATA
  DEY
  BNE @logo_attr_upper
  LDA #$23
  LDX #$D1                     ; attribute row 2, column 1
  JSR set_text_address
  LDA #$0F
  LDY #6
@logo_attr_lower:
  STA PPU_DATA
  DEY
  BNE @logo_attr_lower
  RTS

draw_title_static:
  JSR draw_title_logo
  LDA #$21
  LDX #$CB
  JSR set_text_address
  LDA #<start_text
  STA text_ptr
  LDA #>start_text
  STA text_ptr+1
  JSR write_text
  RTS

draw_current_screen:
  ; Nametable writes are safe with rendering disabled. This also makes every
  ; transition deterministic in accurate cores and on real NROM hardware.
  LDA #0
  STA PPU_MASK
  JSR clear_nametable

  ; Gameplay uses palette 0 for the green background snake and palette 1 for
  ; the coral HUD/text. The title uses palette 0 for the green demo snake and
  ; paints its Press Start band separately; the logo overrides its own
  ; attribute bands with palette 3.
  LDA game_state
  CMP #STATE_GAME
  BEQ @game_attributes
  CMP #STATE_TITLE
  BNE @menu_attributes
  JSR set_title_attributes
  JMP @attributes_ready
@menu_attributes:
  JSR set_text_attributes
  JMP @attributes_ready
@game_attributes:
  JSR set_game_attributes
@attributes_ready:

  LDA game_state
  CMP #STATE_TITLE
  BEQ @title
  CMP #STATE_OVER
  BEQ @over
  CMP #STATE_PAUSE
  BNE @draw_hud
  JMP @pause

  ; HUD for the play screen.
@draw_hud:
  LDA #$20
  LDX #$21                     ; row 1, column 1: first visible score strip
  JSR set_text_address
  LDA #<hud_text
  STA text_ptr
  LDA #>hud_text
  STA text_ptr+1
  JSR write_text
  JSR update_score
  LDA #0
  STA score_dirty
  JMP @finish

@title:
  ; The outlined logo is background artwork, avoiding the NES eight-sprites-
  ; per-scanline limit that applies to OAM sprites.
  JSR draw_title_static
  JMP @finish

@over:
  LDA #$20
  LDX #$CC                     ; row 12, column 12
  JSR set_text_address
  LDA #<over_text
  STA text_ptr
  LDA #>over_text
  STA text_ptr+1
  JSR write_text
  LDA #$20
  LDX #$EB                     ; row 14, column 11
  JSR set_text_address
  LDA #<restart_text
  STA text_ptr
  LDA #>restart_text
  STA text_ptr+1
  JSR write_text
  JMP @finish

@pause:
  LDA #$21
  LDX #$C6                     ; row 14, column 6: centered 19-char text
  JSR set_text_address
  LDA #<pause_text
  STA text_ptr
  LDA #>pause_text
  STA text_ptr+1
  JSR write_text

@finish:
  JSR reset_ppu_origin
  ; A complete redraw can take longer than one vblank on real hardware and
  ; accurate cores. Leave rendering off until the next NMI instead of turning
  ; it back on halfway through an active scanout, which produces a visible
  ; split/flicker.
  LDA #1
  STA render_pending
  RTS

set_text_attributes:
  LDA #$23
  LDX #$C0
  JSR set_text_address
  LDA #$55
  LDY #64
@all_text:
  STA PPU_DATA
  DEY
  BNE @all_text
  RTS

set_title_attributes:
  ; Keep the attract snake green (background palette 0) while the Press Start
  ; text remains coral (palette 1) in nametable rows 14-15.
  LDA #$23
  LDX #$C0
  JSR set_text_address
  LDA #$00
  LDY #64
@all_title:
  STA PPU_DATA
  DEY
  BNE @all_title

  LDA #$23
  LDX #$DA
  JSR set_text_address
  LDA #$50
  LDY #4
@start_band:
  STA PPU_DATA
  DEY
  BNE @start_band
  RTS

set_game_attributes:
  LDA #$23
  LDX #$C0
  JSR set_text_address
  LDA #$55
  LDY #8
@hud_attributes:
  STA PPU_DATA
  DEY
  BNE @hud_attributes
  RTS

format_score:
  ; Convert the full 16-bit score to five decimal digits (00000..65535).
  LDA score
  STA temp_x
  LDA score_hi
  STA temp_y

  ; Ten-thousands, 10000 = $2710.
  LDX #0
@ten_thousands:
  LDA temp_y
  CMP #$27
  BCC @store_ten_thousands
  BNE @subtract_ten_thousand
  LDA temp_x
  CMP #$10
  BCC @store_ten_thousands
@subtract_ten_thousand:
  SEC
  LDA temp_x
  SBC #$10
  STA temp_x
  LDA temp_y
  SBC #$27
  STA temp_y
  INX
  JMP @ten_thousands
@store_ten_thousands:
  TXA
  CLC
  ADC #TILE_0
  STA hud_chars+6

  ; Thousands, 1000 = $03E8.
  LDX #0
@thousands:
  LDA temp_y
  CMP #3
  BCC @store_thousands
  BNE @subtract_thousand
  LDA temp_x
  CMP #$E8
  BCC @store_thousands
@subtract_thousand:
  SEC
  LDA temp_x
  SBC #$E8
  STA temp_x
  LDA temp_y
  SBC #3
  STA temp_y
  INX
  JMP @thousands
@store_thousands:
  TXA
  CLC
  ADC #TILE_0
  STA hud_chars+7

@hundreds_start:
  LDX #0
@hundreds:
  LDA temp_y
  BNE @subtract_hundred
  LDA temp_x
  CMP #100
  BCC @store_hundreds
@subtract_hundred:
  SEC
  LDA temp_x
  SBC #100
  STA temp_x
  LDA temp_y
  SBC #0
  STA temp_y
  INX
  JMP @hundreds
@store_hundreds:
  TXA
  CLC
  ADC #TILE_0
  STA hud_chars+8

  LDX #0
@tens:
  LDA temp_x
  CMP #10
  BCC @store_tens
  SEC
  SBC #10
  STA temp_x
  INX
  JMP @tens
@store_tens:
  TXA
  CLC
  ADC #TILE_0
  STA hud_chars+9
  LDA temp_x
  CLC
  ADC #TILE_0
  STA hud_chars+10
  RTS

update_score:
  ; This routine is called at the start of vblank. Keep the display mask
  ; unchanged while writing the five HUD tiles; toggling it around PPUADDR
  ; writes can expose a clipped score if the NMI runs close to scanout.
  LDA #$20
  LDX #$21                     ; SCORE: at row 1, columns 1..11
  JSR set_text_address
  LDA #<hud_text
  STA text_ptr
  LDA #>hud_text
  STA text_ptr+1
  JSR write_text

  LDA #$20
  LDX #$27                     ; digits at columns 7..11
  JSR set_text_address
  JSR format_score
  LDY #6
@write_digits:
  LDA hud_chars,Y
  STA PPU_DATA
  INY
  CPY #11
  BNE @write_digits
  ; Restore the visible origin so the next frame does not start at the last
  ; HUD tile written.
  JSR reset_ppu_origin
  RTS

; -----------------------------------------------------------------------------
; Sprite/OAM rendering
; -----------------------------------------------------------------------------
hide_oam:
  LDA #$F8
  LDY #0
  LDX #64
  JMP hide_oam_count

hide_game_oam:
  ; Gameplay has seven sprite entries: food, orbit, and five stars.
  LDA #$F8
  LDY #0
  LDX #7
  JMP hide_oam_count

hide_title_tail:
  ; Title uses entries 0..13; gameplay only uses entries 0..4.
  LDA #$F8
  LDY #20                     ; OAM byte 20 = sprite entry 5
  LDX #9

hide_oam_count:
@hide:
  STA $0200,Y
  INY
  INY
  INY
  INY
  DEX
  BNE @hide
  RTS

build_oam:
  LDY #0                      ; food gets the first two OAM slots
  LDA food_y
  ASL A
  ASL A
  ASL A
  STA $0200,Y
  LDA #TILE_FOOD
  STA $0201,Y
  LDA #3                      ; sprite palette 3: bright food dot
  STA $0202,Y
  LDA food_x
  ASL A
  ASL A
  ASL A
  STA $0203,Y
  INY
  INY
  INY
  INY
  JSR build_food_orbit
  JSR build_game_stars
  RTS

; Draw the snake in the background nametable. NES hardware only evaluates
; eight sprites on one scanline; keeping the body in tiles means a long
; horizontal snake never loses segments, and the food/orbit sprites remain
; available for their animation.
draw_snake_background:
  LDA #0
  STA PPU_MASK

  LDA snake_bg_grew
  CMP #2
  BEQ @write_all
  LDA snake_bg_grew
  BNE @write_head
  LDA tail_x
  STA bg_x
  LDA tail_y
  STA bg_y
  LDA #0
  STA bg_tile
  JSR write_bg_cell

@write_head:
  JSR load_head
  LDA temp_x
  STA bg_x
  LDA temp_y
  STA bg_y
  LDA #TILE_BODY
  STA bg_tile
  JSR write_bg_cell
  JMP @done

@write_all:
  LDX snake_head_index
  LDY snake_len
@body:
  LDA snake_x,X
  STA bg_x
  LDA snake_y,X
  STA bg_y
  LDA #TILE_BODY
  STA bg_tile
  JSR write_bg_cell
  INX
  CPX #MAX_SNAKE
  BCC @next_body_index
  LDX #0
@next_body_index:
  DEY
  BNE @body

@done:
@restore_rendering:
  JSR reset_ppu_origin
  LDA render_pending
  BNE @leave_rendering_off
  LDA #$1E
  STA PPU_MASK
@leave_rendering_off:
  RTS

write_bg_cell:
  ; $2000 + (y * 32) + x, with y in rows 2..28.
  BIT PPU_STATUS
  LDA bg_y
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$20
  STA PPU_ADDR
  LDA bg_y
  AND #7
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  CLC
  ADC bg_x
  STA PPU_ADDR
  LDA bg_tile
  STA PPU_DATA
  RTS

build_food_orbit:
  ; The HTML game draws a second food sprite on a four-position orbit.
  ; Positions are four pixels from the food center and advance every eight frames.
  LDA food_phase
  CMP #0
  BEQ @down
  CMP #1
  BEQ @right
  CMP #2
  BEQ @up

  ; Left
  LDA food_y
  ASL A
  ASL A
  ASL A
  STA $0200,Y
  LDA food_x
  ASL A
  ASL A
  ASL A
  SEC
  SBC #4
  STA $0203,Y
  JMP @write

@down:
  LDA food_y
  ASL A
  ASL A
  ASL A
  CLC
  ADC #4
  STA $0200,Y
  LDA food_x
  ASL A
  ASL A
  ASL A
  STA $0203,Y
  JMP @write

@right:
  LDA food_y
  ASL A
  ASL A
  ASL A
  STA $0200,Y
  LDA food_x
  ASL A
  ASL A
  ASL A
  CLC
  ADC #4
  STA $0203,Y
  JMP @write

@up:
  LDA food_y
  ASL A
  ASL A
  ASL A
  SEC
  SBC #4
  STA $0200,Y
  LDA food_x
  ASL A
  ASL A
  ASL A
  STA $0203,Y
@write:
  LDA #TILE_FOOD
  STA $0201,Y
  LDA #3
  STA $0202,Y
  INY
  INY
  INY
  INY
  RTS

build_hud_oam:
  ; SCORE: plus a five-digit decimal score on the bottom status row.
  LDA #22
  STA hud_chars
  LDA #6
  STA hud_chars+1
  LDA #18
  STA hud_chars+2
  LDA #21
  STA hud_chars+3
  LDA #8
  STA hud_chars+4
  LDA #40
  STA hud_chars+5

  JSR format_score

  LDX #0
@hud:
  LDA #8                      ; top status row (safe for accurate NES cores)
  STA $0200,Y
  LDA hud_chars,X
  STA $0201,Y
  LDA #2                      ; sprite palette 2: orange HUD text
  STA $0202,Y
  TXA
  ASL A
  ASL A
  ASL A
  CLC
  ADC #8
  STA $0203,Y
  INY
  INY
  INY
  INY
  INX
  CPX #11
  BNE @hud
  RTS

build_game_stars:
  LDX #0
@star:
  LDA game_star_y,X
  STA $0200,Y
  LDA #TILE_STAR
  STA $0201,Y
  LDA #1                      ; sprite palette 1: pale stars
  STA $0202,Y
  LDA star_x,X
  STA $0203,Y
  INY
  INY
  INY
  INY
  INX
  CPX #5
  BNE @star
  RTS

animate_stars:
  ; Five sparse stars drift left one pixel per frame. Wrapping at the left
  ; edge keeps the background moving without consuming another sprite slot.
  LDX #0
@move:
  LDA star_x,X
  BEQ @wrap
  DEC star_x,X
  JMP @next
@wrap:
  LDA #248
  STA star_x,X
@next:
  INX
  CPX #5
  BNE @move
  RTS

animate_title_stars:
  ; The attract-mode stars share the gameplay drift, but use the full title
  ; field so the logo never sits on a static background.
  LDX #0
@move:
  LDA title_star_x,X
  BEQ @wrap
  DEC title_star_x,X
  JMP @next
@wrap:
  LDA #248
  STA title_star_x,X
@next:
  INX
  CPX #12
  BNE @move
  RTS

build_title_oam:
  ; Keep the demo collectible ahead of the decorative stars and snake so it
  ; remains visible on real NES scanlines as the attract snake grows.
  LDY #0
  LDA food_y
  ASL A
  ASL A
  ASL A
  STA $0200,Y
  LDA #TILE_FOOD
  STA $0201,Y
  LDA #3
  STA $0202,Y
  LDA food_x
  ASL A
  ASL A
  ASL A
  STA $0203,Y
  INY
  INY
  INY
  INY
  JSR build_food_orbit

  LDX #0
@star:
  LDA title_star_y,X
  STA $0200,Y
  LDA #TILE_STAR
  STA $0201,Y
  LDA #1                      ; sprite palette 1: pale star color
  STA $0202,Y
  LDA title_star_x,X
  STA $0203,Y
  INY
  INY
  INY
  INY
  INX
  CPX #12
  BNE @star

  ; The attract-mode snake is drawn in the background nametable, just like
  ; the playable snake, so title OAM cannot overflow as it grows.
  RTS

; -----------------------------------------------------------------------------
; Nametable text data. Tile 0 is a space; letters are TILE_A..TILE_A+25.
; -----------------------------------------------------------------------------
title_text:   .byte 22,17,4,14,8,41,$FF                 ; SNAKE!
start_text:   .byte 19,21,8,22,22,0,22,23,4,21,23,$FF    ; PRESS START
over_text:    .byte 10,4,16,8,0,18,25,8,21,$FF           ; GAME OVER
restart_text: .byte 19,21,8,22,22,0,22,23,4,21,23,$FF    ; PRESS START
pause_text:   .byte 19,4,24,22,8,0,42,0,19,21,8,22,22,0,22,23,4,21,23,$FF
hud_text:     .byte 22,6,18,21,8,40,30,30,30,30,30,$FF    ; SCORE:00000

palette_data:
  .byte $0F,$29,$1A,$30, $0F,$26,$16,$30
  .byte $0F,$0F,$0F,$0F, $0F,$28,$18,$30
  .byte $0F,$29,$1A,$30, $0F,$10,$00,$20
  .byte $0F,$26,$16,$30, $0F,$27,$17,$30

title_star_start_x: .byte 12,52,92,132,172,212,244,28,76,148,196,236
title_star_y:   .byte 18,46,76,28,62,94,132,118,166,146,204,224
; Three 17-tile rows: six two-tile glyphs separated by one blank tile.
title_logo_row0: .byte 44,45,0,50,51,0,56,57,0,62,63,0,68,69,0,74,75,$FF
title_logo_row1: .byte 46,47,0,52,53,0,58,59,0,64,65,0,70,71,0,76,77,$FF
title_logo_row2: .byte 48,49,0,54,55,0,60,61,0,66,67,0,72,73,0,78,79,$FF
game_star_x:    .byte 24,96,176,232,136
game_star_y:    .byte 24,96,152,208,184

; -----------------------------------------------------------------------------
; Interrupt vectors
; -----------------------------------------------------------------------------
.segment "VEC"
  .word nmi
  .word reset
  .word 0

; -----------------------------------------------------------------------------
; Compact CHR data copied into CHR-RAM during reset. Font tiles use plane 0
; only and sprite tiles use the sprite palette.
; -----------------------------------------------------------------------------
.segment "CHRDATA"
chr_data:
  ; Tile 0: blank
  .byte 0,0,0,0,0,0,0,0
  .byte 0,0,0,0,0,0,0,0

  ; Tile 1: snake body, rounded with a two-tone highlight
  .byte %00011000,%00111100,%01111110,%11111111
  .byte %11111111,%01111110,%00111100,%00011000
  .byte %00000000,%00011000,%00100100,%01000010
  .byte %01000010,%00100100,%00011000,%00000000

  ; Tile 2: snake head with two bright eyes
  .byte %00111100,%01111110,%11111111,%11111111
  .byte %11111111,%11111111,%01111110,%00111100
  .byte %00000000,%00000000,%01000010,%00000000
  .byte %00000000,%01000010,%00000000,%00000000

  ; Tile 3: food crystal with a central glint
  .byte %00011000,%00111100,%01111110,%11111111
  .byte %01111110,%00111100,%00011000,%00000000
  .byte %00000000,%00011000,%00100100,%00011000
  .byte %00000000,%00000000,%00000000,%00000000

.macro FONT_TILE p0,p1,p2,p3,p4,p5,p6,p7
  .byte p0,p1,p2,p3,p4,p5,p6,p7
  .byte 0,0,0,0,0,0,0,0
.endmacro

  ; A-Z (tiles 4-29)
  FONT_TILE %01110000,%11011000,%11011000,%11111000,%11011000,%11011000,%11011000,%00000000
  FONT_TILE %11110000,%11011000,%11011000,%11110000,%11011000,%11011000,%11110000,%00000000
  FONT_TILE %01111000,%11000000,%11000000,%11000000,%11000000,%11000000,%01111000,%00000000
  FONT_TILE %11110000,%11011000,%11011000,%11011000,%11011000,%11011000,%11110000,%00000000
  FONT_TILE %11111000,%11000000,%11000000,%11110000,%11000000,%11000000,%11111000,%00000000
  FONT_TILE %11111000,%11000000,%11000000,%11110000,%11000000,%11000000,%11000000,%00000000
  FONT_TILE %01111000,%11000000,%11000000,%11011000,%11011000,%11011000,%01111000,%00000000
  FONT_TILE %11011000,%11011000,%11011000,%11111000,%11011000,%11011000,%11011000,%00000000
  FONT_TILE %11111000,%00110000,%00110000,%00110000,%00110000,%00110000,%11111000,%00000000
  FONT_TILE %00011100,%00011000,%00011000,%00011000,%00011000,%11011000,%01110000,%00000000
  FONT_TILE %11011000,%11011000,%11110000,%11100000,%11110000,%11011000,%11011000,%00000000
  FONT_TILE %11000000,%11000000,%11000000,%11000000,%11000000,%11000000,%11111000,%00000000
  ; M: compact five-pixel glyph with clear stems and a strong center.
  FONT_TILE %11011000,%11111000,%11111000,%11011000,%11011000,%11011000,%11011000,%00000000
  FONT_TILE %11011000,%11111000,%11111000,%11011000,%11011000,%11011000,%11011000,%00000000
  FONT_TILE %01110000,%11011000,%11011000,%11011000,%11011000,%11011000,%01110000,%00000000
  FONT_TILE %11110000,%11011000,%11011000,%11110000,%11000000,%11000000,%11000000,%00000000
  FONT_TILE %01110000,%11011000,%11011000,%11011000,%11111000,%01111000,%00011000,%00000000
  FONT_TILE %11110000,%11011000,%11011000,%11110000,%11110000,%11011000,%11011000,%00000000
  FONT_TILE %01111000,%11000000,%11000000,%01110000,%00011000,%00011000,%11110000,%00000000
  ; T: wider cap with a centered two-pixel stem.
  FONT_TILE %11111100,%00110000,%00110000,%00110000,%00110000,%00110000,%00110000,%00000000
  FONT_TILE %11011000,%11011000,%11011000,%11011000,%11011000,%11011000,%01110000,%00000000
  FONT_TILE %11011000,%11011000,%11011000,%11011000,%11011000,%01110000,%00100000,%00000000
  FONT_TILE %11011000,%11011000,%11011000,%11011000,%11111100,%11101100,%11000100,%00000000
  FONT_TILE %11011000,%11011000,%01110000,%00100000,%01110000,%11011000,%11011000,%00000000
  FONT_TILE %11011000,%11011000,%01110000,%00110000,%00110000,%00110000,%00110000,%00000000
  FONT_TILE %11111000,%00011000,%00110000,%01100000,%11000000,%11000000,%11111000,%00000000

  ; 0-9 (tiles 30-39)
  FONT_TILE %01110000,%11011000,%11011000,%11011000,%11011000,%11011000,%01110000,%00000000
  FONT_TILE %00110000,%01110000,%00110000,%00110000,%00110000,%00110000,%11111000,%00000000
  FONT_TILE %01110000,%11011000,%00011000,%00110000,%01100000,%11000000,%11111000,%00000000
  FONT_TILE %11110000,%00011000,%00011000,%01110000,%00011000,%00011000,%11110000,%00000000
  FONT_TILE %00011000,%00111000,%01111000,%11011000,%11111000,%00011000,%00011000,%00000000
  FONT_TILE %11111000,%11000000,%11000000,%11110000,%00011000,%00011000,%11110000,%00000000
  FONT_TILE %01110000,%11000000,%11000000,%11110000,%11011000,%11011000,%01110000,%00000000
  FONT_TILE %11111000,%00011000,%00110000,%00110000,%01100000,%01100000,%01100000,%00000000
  FONT_TILE %01110000,%11011000,%11011000,%01110000,%11011000,%11011000,%01110000,%00000000
  FONT_TILE %01110000,%11011000,%11011000,%01111000,%00011000,%00011000,%01110000,%00000000

  ; Tile 40: colon. Tile 41: exclamation. Tile 42: dash.
  FONT_TILE %00000000,%00110000,%00110000,%00000000,%00110000,%00110000,%00000000,%00000000
  FONT_TILE %00110000,%00110000,%00110000,%00110000,%00110000,%00000000,%00110000,%00000000
  FONT_TILE %00000000,%00000000,%00000000,%11111000,%00000000,%00000000,%00000000,%00000000

  ; Tile 43: small gray star dot
  .byte 0,0,0,%00011000,%00011000,0,0,0
  .byte 0,0,0,0,0,0,0,0

  ; Tiles 44-79: outlined SNAKE! title logo, split into 2x3 sprites per glyph.
.macro LOGO_TILE p0,p1,p2,p3,p4,p5,p6,p7
  .byte p0,p1,p2,p3,p4,p5,p6,p7
  .byte 0,0,0,0,0,0,0,0
.endmacro
  LOGO_TILE %00000000,%00011111,%00011111,%00011111,%11100000,%11100000,%11100000,%11100000
  LOGO_TILE %00000000,%11110000,%11110000,%11110000,%00000000,%00000000,%00000000,%00000000
  LOGO_TILE %11100000,%11100000,%00011111,%00011111,%00011111,%00000000,%00000000,%00000000
  LOGO_TILE %00000000,%00000000,%11110000,%11110000,%11110000,%00001110,%00001110,%00001110
  LOGO_TILE %00000000,%00000000,%00000000,%00011111,%00011111,%00011111,%00000000,%00000000
  LOGO_TILE %00001110,%00001110,%00001110,%11110000,%11110000,%11110000,%00000000,%00000000
  LOGO_TILE %00000000,%11100000,%11100000,%11100000,%11111100,%11111100,%11111100,%11100011
  LOGO_TILE %00000000,%00001110,%00001110,%00001110,%00001110,%00001110,%00001110,%10001110
  LOGO_TILE %11100011,%11100011,%11100000,%11100000,%11100000,%11100000,%11100000,%11100000
  LOGO_TILE %10001110,%10001110,%01111110,%01111110,%01111110,%00001110,%00001110,%00001110
  LOGO_TILE %11100000,%11100000,%11100000,%11100000,%11100000,%11100000,%00000000,%00000000
  LOGO_TILE %00001110,%00001110,%00001110,%00001110,%00001110,%00001110,%00000000,%00000000
  LOGO_TILE %00000000,%00011111,%00011111,%00011111,%11100000,%11100000,%11100000,%11100000
  LOGO_TILE %00000000,%11110000,%11110000,%11110000,%00001110,%00001110,%00001110,%00001110
  LOGO_TILE %11100000,%11100000,%11111111,%11111111,%11111111,%11100000,%11100000,%11100000
  LOGO_TILE %00001110,%00001110,%11111110,%11111110,%11111110,%00001110,%00001110,%00001110
  LOGO_TILE %11100000,%11100000,%11100000,%11100000,%11100000,%11100000,%00000000,%00000000
  LOGO_TILE %00001110,%00001110,%00001110,%00001110,%00001110,%00001110,%00000000,%00000000
  LOGO_TILE %00000000,%11100000,%11100000,%11100000,%11100000,%11100000,%11100000,%11100011
  LOGO_TILE %00000000,%00001110,%00001110,%00001110,%01110000,%01110000,%01110000,%10000000
  LOGO_TILE %11100011,%11100011,%11111100,%11111100,%11111100,%11100011,%11100011,%11100011
  LOGO_TILE %10000000,%10000000,%00000000,%00000000,%00000000,%10000000,%10000000,%10000000
  LOGO_TILE %11100000,%11100000,%11100000,%11100000,%11100000,%11100000,%00000000,%00000000
  LOGO_TILE %01110000,%01110000,%01110000,%00001110,%00001110,%00001110,%00000000,%00000000
  LOGO_TILE %00000000,%11111111,%11111111,%11111111,%11100000,%11100000,%11100000,%11100000
  LOGO_TILE %00000000,%11111110,%11111110,%11111110,%00000000,%00000000,%00000000,%00000000
  LOGO_TILE %11100000,%11100000,%11111111,%11111111,%11111111,%11100000,%11100000,%11100000
  LOGO_TILE %00000000,%00000000,%11110000,%11110000,%11110000,%00000000,%00000000,%00000000
  LOGO_TILE %11100000,%11100000,%11100000,%11111111,%11111111,%11111111,%00000000,%00000000
  LOGO_TILE %00000000,%00000000,%00000000,%11111110,%11111110,%11111110,%00000000,%00000000
  LOGO_TILE %00000000,%00000011,%00000011,%00000011,%00000011,%00000011,%00000011,%00000011
  LOGO_TILE %00000000,%10000000,%10000000,%10000000,%10000000,%10000000,%10000000,%10000000
  LOGO_TILE %00000011,%00000011,%00000011,%00000011,%00000011,%00000011,%00000011,%00000011
  LOGO_TILE %10000000,%10000000,%10000000,%10000000,%10000000,%10000000,%10000000,%10000000
  LOGO_TILE %00000000,%00000000,%00000000,%00000011,%00000011,%00000011,%00000000,%00000000
  LOGO_TILE %00000000,%00000000,%00000000,%10000000,%10000000,%10000000,%00000000,%00000000
