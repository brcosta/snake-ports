; NES Hardware Definitions
; For use with ca65 assembler

; PPU Registers
PPU_CTRL    = $2000
PPU_MASK    = $2001
PPU_STATUS  = $2002
OAM_ADDR    = $2003
OAM_DATA    = $2004
PPU_SCROLL  = $2005
PPU_ADDR    = $2006
PPU_DATA    = $2007

; APU Registers
SQ1_VOL     = $4000
SQ1_SWEEP   = $4001
SQ1_LO      = $4002
SQ1_HI      = $4003
SQ2_VOL     = $4004
SQ2_SWEEP   = $4005
SQ2_LO      = $4006
SQ2_HI      = $4007
TRI_LINEAR  = $4008
TRI_LO      = $400A
TRI_HI      = $400B
NOISE_VOL   = $400C
NOISE_LO    = $400E
NOISE_HI    = $400F
DMC_FREQ    = $4010
DMC_RAW     = $4011
DMC_START   = $4012
DMC_LEN     = $4013
APU_STATUS  = $4015

; Controller Registers
CTRL1       = $4016
CTRL2       = $4017

; OAM DMA
OAM_DMA     = $4014

; Controller bits
BTN_A       = %10000000
BTN_B       = %01000000
BTN_SELECT  = %00100000
BTN_START   = %00010000
BTN_UP      = %00001000
BTN_DOWN    = %00000100
BTN_LEFT    = %00000010
BTN_RIGHT   = %00000001

; Sprite OAM constants
OAM_SIZE    = 256
SPR_Y       = 0
SPR_TILE    = 1
SPR_ATTR    = 2
SPR_X       = 3
