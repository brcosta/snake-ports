;=============================================================================;
;  SNAKE! ver 0.1                                                             ;
;                                                                             ;
;  by Bruno (_Faster)     (x_bruno17@yahoo.com.br)                        2003;
;  ToDo - Optimizar o péssimo código :(                                       ;
;=============================================================================;

.model compact
.stack 100h
.386
;=============================================================================;
.data

SNAKECOUNT    EQU   50
STARSCOUNT    EQU   25

Buffer     db 64000 DUP (?)

Palette    db 0,0,0, 0,0,40, 40,0,0, 5,4,3, 23,23,23, 40,40,40, 15,10,10,0,0,0,20,0,0,0,00,00
           db 30,1,2,0,0,0,63,63,63,0,0,0,0,0,0,63,30,0,63,63,63,63,63,63,0,00
           db 0,63,63,63,10,20,00,10,50,00,20,30,00,63,63,20,20,30,00,20,63,00
           db 30,40,00,63,63,63

ARect      STRUC
  X        dw ?
  Y        dw ?
  XL       dw ?
  YL       dw ?
  Color    db ?
ARect      ENDS

AFont     STRUC
  X        dw ?
  Y        dw ?
  InitX    dw ?
  Col      db ?
  Italic   db ?
  Shadow   db 255
AFont     ENDS

TempX      dw ?
TempY      dw ?
TempByte   db ?

CharToDraw db ?

Radius     dw ?
Angle      dw ?
DegPi      dw ?

ShowDebug  db ?
ShowStars  db ?

Rect       ARect <>
Font       AFont <>

HeadFlag   db ?

Dir        db ?
Vel        db ?
VelCount   db ?


IntroMode  db ?
SCount     db ?
Score      dd ?
Level      db ?

StringMask dd ?

DotX       db ?
DotY       db ?

RandRange  dw ?


Seed       dw ?

.FARDATA @dsegment2

;font usada durante o jogo
SmallFont  db 000, 000, 000, 000, 000, 032, 032, 032, 000, 032, 080, 080, 000, 000, 000, 080
           db 248, 080, 248, 080, 032, 112, 096, 048, 112, 200, 208, 032, 088, 152, 096, 104
           db 112, 144, 104, 032, 032, 000, 000, 000, 016, 032, 032, 032, 016, 064, 032, 032
           db 032, 064, 168, 112, 032, 112, 168, 032, 032, 248, 032, 032, 000, 000, 000, 032
           db 064, 000, 000, 248, 000, 000, 000, 000, 000, 000, 032, 008, 016, 032, 064, 128
           db 112, 136, 136, 136, 112, 016, 048, 016, 016, 056, 112, 008, 112, 128, 248, 240
           db 008, 112, 008, 240, 016, 144, 240, 016, 016, 240, 128, 240, 008, 240, 112, 128
           db 240, 136, 112, 120, 008, 016, 032, 032, 112, 136, 112, 136, 112, 112, 136, 120
           db 008, 112, 000, 032, 000, 032, 000, 000, 032, 000, 032, 064, 016, 032, 064, 032
           db 016, 000, 248, 000, 248, 000, 064, 032, 016, 032, 064, 112, 008, 048, 000, 032
           db 112, 184, 184, 128, 112, 112, 136, 248, 136, 136, 240, 136, 240, 136, 240, 112
           db 128, 128, 128, 112, 240, 136, 136, 136, 240, 248, 128, 240, 128, 248, 248, 128
           db 240, 128, 128, 120, 128, 184, 136, 120, 136, 136, 248, 136, 136, 248, 032, 032
           db 032, 248, 120, 016, 016, 144, 096, 136, 144, 224, 144, 136, 128, 128, 128, 128
           db 248, 136, 216, 168, 136, 136, 136, 200, 168, 152, 136, 112, 136, 136, 136, 112
           db 240, 136, 240, 128, 128, 112, 136, 168, 152, 120, 240, 136, 240, 144, 136, 112
           db 128, 112, 008, 112, 248, 032, 032, 032, 032, 136, 136, 136, 136, 112, 136, 136
           db 080, 080, 032, 136, 136, 168, 216, 136, 136, 080, 032, 080, 136, 136, 136, 120
           db 008, 112, 248, 016, 032, 064, 248, 112, 064, 064, 064, 112, 128, 064, 032, 016
           db 008, 112, 016, 016, 016, 112, 032, 080, 000, 000, 000, 000, 000, 000, 000, 252, 000, 000, 000, 000, 000

SnakeBody  db 00h, 14h, 14h, 14h, 14h, 14h, 14h, 00h
           db 14h, 16h, 16h, 15h, 15h, 16h, 16h, 14h
           db 14h, 16h, 15h, 15h, 15h, 15h, 16h, 14h
           db 14h, 15h, 15h, 17h, 17h, 15h, 15h, 14h
           db 14h, 15h, 15h, 17h, 17h, 15h, 15h, 14h
           db 14h, 16h, 15h, 15h, 15h, 15h, 16h, 14h
           db 14h, 16h, 16h, 15h, 15h, 16h, 16h, 14h
           db 00h, 14h, 14h, 14h, 14h, 14h, 14h, 00h

Dot        db 00h, 00h, 00h, 18h, 18h, 00h, 00h, 00h
           db 00h, 00h, 18h, 1Ah, 1Ah, 18h, 00h, 00h
           db 00h, 18h, 1Ah, 19h, 19h, 1Ah, 18h, 00h
           db 18h, 1Ah, 19h, 1Bh, 1Bh, 19h, 1Ah, 18h
           db 18h, 1Ah, 19h, 1Bh, 1Bh, 19h, 1Ah, 18h
           db 00h, 18h, 1Ah, 19h, 19h, 1Ah, 18h, 00h
           db 00h, 00h, 18h, 1Ah, 1Ah, 18h, 00h, 00h
           db 00h, 00h, 00h, 18h, 18h, 00h, 00h, 00h

NumberStr  db 17,"99999999",0
LevelText  db 15,"NIVEL:",0
ScoreText  db 15,"SCORE:",0

Credits    db 17,"BY _FASTER 2003",0
GameTitle  db 23,"SNAKE!",0
Ver        db 17,"VERSAO 0.1",0

PressAKey  db 15,"PRESSIONE ESPACO PARA CONTINUAR",0
PressAnyKey  db 17,"PRESSIONE QUALQUER TECLA :(",0
InstrTitle db 17,"INSTRUCOES",0
Instruct   db 17,"MOVER COBRINHA   = ",15,"SETAS",255
           db 17,"PAUSAR JOGO      = ",15,"ESPACO",255
           db 17,"APAGAR ESTRELAS  = ",15,"S",255,255
           db 17,"DEBUGMODE WINDOW = ",15,"D",255
           db 17,"AUMENTAR NIVEL   = ",15,"A",17," EM DEBUGMODE",255,255
           db 17,"SAIR DO JOGO     = ",23,"ESC",0

GOverTitle db 17,"GAME OVER :(",0
GameOver   db 15,"NAO FIQUE TRISTE PRESSIONE ENTER PARA JOGAR",255
           db "        OUTRA PARTIDA, MAS SE VC",255
           db "    QUISER SAIR, APERTE ESC ",17,"(NAO VAHH)",15," :)",0

DebugTitle    db 17,"DEBUG",0
DotXStr       db 23,"DOT_X:",0
DotYStr       db 23,"DOT_Y:",0
SnakeXStr     db 23,"SNAKE_X:",0
SnakeYStr     db 23,"SNAKE_Y:",0
SnakeStr      db 23,"SIZE:",0
SSStr         db 23,"SHOWSTARS:",0
UpStr         db 17,"CIMA",0
DownStr       db 15,"BAIXO",0
LeftStr       db 21,"ESQ.",0
RightStr      db 25,"DIR.",0
SnakeDirStr   db 23,"DIRECAO:",0

FinalCredits db "               ",17,"SNAKE!",255,255
             db "           ",23,"PROGRAMADO POR",255
             db "       ",15,"_FASTER (BRUNO COSTA)",255
             db "       ",25,"X_BRUNO17",17,"@",15,"YAHOO",17,".",15,"COM",17,".",15,"BR",255,255
             db "                EM",255
             db "    ",15,"VARIOS DIAS DE ",17,"AGOSTO",15," DE ",17,"2003",255,255,255
             db "         ",17,"VISITEM OS CANAIS:",255
             db "   ",21,"#DEFINE, #ROMHACKING, #UNASHAMED",255,255,255
             db "          ",17,"BLIND GUARDIAN ROX",255,255,255,255
             db "                 ",21,"\O/",0

.FARDATA @dsegment3

ForeStarsX dw STARSCOUNT DUP (?)
BackStarsY dw STARSCOUNT DUP (?)

BackStarsX dw STARSCOUNT DUP (?)
ForeStarsY dw STARSCOUNT DUP (?)

SnakeX     db SNAKECOUNT DUP (?)
SnakeY     db SNAKECOUNT DUP (?)

;Logo, compactado com rle
Logo       db 255,000,123,000,001,240,001,255,001,127,009,000,001,128,001,031
           db 007,000,001,126,009,000,001,032,001,000,001,128,010,000,001,033
           db 007,000,001,132,009,000,001,064,002,000,001,001,009,000,001,066
           db 007,000,001,008,001,001,008,000,001,128,002,000,001,002,009,000
           db 001,132,007,000,001,016,001,002,009,000,001,001,001,000,001,004
           db 009,000,001,008,001,001,006,000,001,032,001,004,008,000,001,240
           db 002,255,001,015,009,000,001,016,001,002,006,000,001,064,001,008
           db 008,000,001,032,001,004,011,000,001,032,001,004,006,000,001,128
           db 001,016,008,000,001,064,001,008,011,000,001,064,001,008,007,000
           db 001,033,008,000,001,128,001,016,011,000,001,128,001,016,007,000
           db 001,066,009,000,001,033,012,000,001,033,007,000,001,132,009,000
           db 001,066,012,000,001,066,007,000,001,008,001,001,008,000,001,132
           db 012,000,001,132,007,000,001,016,001,002,008,000,001,008,001,001
           db 011,000,001,008,001,001,006,000,001,032,001,004,008,000,001,016
           db 001,002,011,000,001,016,001,002,001,128,001,031,004,000,001,064
           db 001,008,008,000,001,224,002,255,001,031,001,000,001,252,001,255
           db 001,127,002,000,001,254,001,255,001,000,001,032,001,004,001,000
           db 001,033,001,000,001,248,001,255,001,003,001,128,001,016,009,000
           db 001,008,001,000,001,032,001,000,001,008,001,000,001,128,002,000
           db 001,004,001,000,001,001,001,064,001,008,001,000,001,066,001,000
           db 001,016,001,000,001,004,001,000,001,033,009,000,001,016,001,000
           db 001,064,001,000,001,016,002,000,001,001,001,000,001,008,001,000
           db 001,002,001,128,001,016,001,000,001,132,001,000,001,032,001,000
           db 001,008,001,000,001,066,009,000,001,032,001,000,001,128,001,000
           db 001,032,002,000,001,002,001,000,001,016,001,000,001,004,001,000
           db 001,033,001,000,001,008,001,001,001,064,001,000,001,016,001,000
           db 001,132,009,000,001,064,002,000,001,001,001,064,002,000,001,004
           db 001,000,001,032,001,000,001,008,001,000,001,066,001,128,001,255
           db 001,003,001,128,001,000,001,032,001,000,001,008,001,001,008,000
           db 001,128,002,255,001,127,001,128,001,240,002,255,001,001,001,192
           db 002,255,001,003,001,132,001,000,001,033,001,000,001,248,002,255
           db 001,015,001,016,001,002,011,000,001,132,001,000,001,033,001,000
           db 001,016,001,002,002,000,001,032,001,004,001,008,001,001,001,066
           db 001,000,001,016,001,002,001,128,001,016,001,032,001,004,011,000
           db 001,008,001,001,001,066,001,000,001,032,001,004,002,000,001,064
           db 001,008,001,016,001,002,001,132,001,000,001,032,001,004,001,000
           db 001,033,001,064,001,008,011,000,001,016,001,002,001,132,001,000
           db 001,064,001,008,002,000,001,128,001,016,001,032,001,004,001,008
           db 001,001,001,064,001,008,001,000,001,066,001,128,001,016,011,000
           db 001,032,001,004,001,008,001,001,001,128,001,016,001,000,001,252
           db 001,255,001,033,001,064,001,248,001,255,001,003,001,128,001,240
           db 001,255,001,135,001,000,001,033,011,000,001,064,001,008,001,016
           db 001,002,001,000,001,033,001,000,001,008,001,000,001,064,001,128
           db 001,000,001,032,002,000,001,001,002,000,001,001,001,066,011,000
           db 001,128,001,016,001,032,001,004,001,000,001,066,001,000,001,016
           db 001,000,001,128,001,000,001,001,001,064,002,000,001,002,002,000
           db 001,002,001,132,012,000,001,033,001,064,001,008,001,000,001,132
           db 001,000,001,032,002,000,001,001,001,002,001,128,002,000,001,004
           db 002,000,001,004,001,008,001,001,011,000,001,066,001,128,001,016
           db 001,000,001,008,001,001,001,064,002,000,001,002,001,004,001,000
           db 001,001,001,000,001,008,002,000,001,008,001,016,001,002,011,000
           db 001,132,001,000,001,033,001,000,001,016,001,002,001,252,001,255
           db 001,063,001,004,001,008,001,255,001,127,001,000,001,016,001,254
           db 001,255,001,031,001,224,001,007,011,000,001,008,001,001,001,066
           db 001,000,001,032,001,004,001,008,001,001,001,064,001,008,001,016
           db 001,002,001,132,001,000,001,032,001,004,015,000,001,016,001,002
           db 001,132,001,000,001,064,001,008,001,016,001,002,001,128,001,016
           db 001,032,001,004,001,008,001,001,001,064,001,008,015,000,001,032
           db 001,004,001,008,001,001,001,128,001,016,001,032,001,004,001,000
           db 001,033,001,064,001,008,001,016,001,002,001,128,001,016,012,000
           db 001,128,003,255,001,015,001,016,001,002,001,000,001,033,001,064
           db 001,008,001,000,001,066,001,128,001,016,001,032,001,004,001,000
           db 002,255,001,015,001,000,001,126,009,000,001,001,001,000,001,128
           db 001,000,001,032,001,004,001,000,001,066,001,128,002,255,001,135
           db 001,000,001,033,001,192,001,255,001,001,001,064,001,000,001,016
           db 001,000,001,132,009,000,001,002,002,000,001,001,001,064,001,008
           db 001,000,001,132,001,000,001,032,002,000,001,001,001,066,001,000
           db 001,016,001,002,001,128,001,000,001,032,001,000,001,008,001,001
           db 008,000,001,004,002,000,001,002,001,128,001,016,001,000,001,008
           db 001,001,001,064,002,000,001,002,001,132,001,000,001,032,001,004
           db 001,000,001,001,001,064,001,000,001,016,001,002,008,000,001,008
           db 002,000,001,004,001,000,001,033,001,000,001,016,001,002,001,128
           db 002,000,001,004,001,008,001,001,001,064,001,008,001,000,001,002
           db 001,128,001,000,001,032,001,004,008,000,001,240,002,255,001,015
           db 001,000,001,126,001,000,001,224,001,007,001,000,002,255,001,015
           db 001,240,001,003,001,128,001,031,001,000,001,252,001,255,001,001
           db 001,192,001,015,001,000,001,000,001,000,001,000,001,000,001,000

;===============================================================================
.code

ASSUME  fs:@dsegment2
ASSUME  gs:@dsegment3

;-------------------------------------------------------------------------------
Mode13h   PROC
  mov ax, 0013h
  int 10h

  mov si, offset palette
  mov cx, 84
  mov dx, 03C8h
  xor al, al

  cli

  out dx, al
  inc dx
  cld
  rep   outsb

  sti
  ret
Mode13h   ENDP

;-------------------------------------------------------------------------------
TextMode         PROC
  mov ax, 0003h
  int 10h
  ret
TextMode         ENDP

;-------------------------------------------------------------------------------
PutPixel         PROC
  mov ax, TempY
  shl ax, 6
  mov di, ax
  shl ax, 2
  add di, ax

  add di, offset Buffer
  add di, TempX

  mov al, TempByte

  mov ds:[di], al
  ret
PutPixel         ENDP

;-------------------------------------------------------------------------------
Random           PROC
   mov ax, Seed

   mov dx, 0ABCDh
   mul dx
   inc ax
   mov seed, ax

   xor dx, dx
   mov cx, randrange
   div cx

   ret
Random           ENDP

;-------------------------------------------------------------------------------
InitStars PROC
  xor bx, bx

  SetNextStar:
  mov randrange, 309
  call random
  add dx, 10
  mov ForeStarsX[bx], dx

  mov randrange, 181
  call random
  add dx, 10
  mov ForeStarsY[bx], dx

  mov randrange, 307
  call random
  add dx, 13
  mov BackStarsX[bx], dx

  mov randrange, 181
  call random
  add dx, 10
  mov BackStarsY[bx], dx

  inc bx
  inc bx
  cmp bx, STARSCOUNT*2
  jne SetNextStar
  ret
InitStars ENDP

;-------------------------------------------------------------------------------
DrawStars PROC
  xor bx, bx
  UpdateNextStar:

  cmp BackStarsX[bx], 0
  je WrapBSX
  dec BackStarsX[bx]
  jmp UpdFore

  WrapBSX:
  mov randrange, 180
  call random
  add dx, 10
  mov BackStarsY[bx], dx
  mov BackStarsX[bx], 318

  UpdFore:
  cmp ForeStarsX[bx], 2
  jb WrapFSX
  dec ForeStarsX[bx]
  dec ForeStarsX[bx]
  jmp UpdEnd

  WrapFSX:
  mov randrange, 180
  call random
  add dx, 10
  mov ForeStarsY[bx], dx
  mov ForeStarsX[bx], 318

  UpdEnd:
  inc bx
  inc bx
  cmp bx, STARSCOUNT*2
  jne UpdateNextStar

  xor bx, bx

  DrawNextStar:
  mov ax, BackStarsX[bx]
  mov TempX, ax
  mov ax, BackStarsY[bx]
  mov TempY, ax
  mov TempByte, 4
  call PutPixel
  cmp TempX, 319
  jnb nd1
  inc TempX
  mov TempByte,6
  call PutPixel
  nd1:
  mov ax, ForeStarsX[bx]
  mov TempX, ax
  mov ax, ForeStarsY[bx]
  mov TempY, ax
  mov TempByte, 17
  call PutPixel
  cmp TempX, 319
  jnb ndd
  inc TempX
  mov TempByte,5
  call PutPixel
  inc TempX
  mov TempByte,6
  call PutPixel
  ndd:

  inc bx
  inc bx
  cmp bx, STARSCOUNT*2
  jne DrawNextStar
  ret
DrawStars ENDP

;-------------------------------------------------------------------------------
DrawChar         PROC
  cmp [Font.Y], 199-5
  ja DrawCharClip
  push si
  mov si, offset SmallFont
  xor ah, ah

  mov al, CharToDraw
  sub al, 32

  mov cl, 5
  mul cl

  add si, ax
  mov ax, ds
  mov es, ax

  xor cx, cx

  nextlin:
  xor dx, dx

  nextcol:
  mov bl, fs:[si]
  mov cl, 7
  sub cl, dl
  shr bl, cl
  and bl, 1
  jz MaskBit

  mov ax, [Font.Y]
  add al, ch
  shl ax, 6
  mov di, ax
  shl ax, 2
  add di, ax

  add di, [Font.X]
  add di, dx
  add di, offset Buffer

  mov al, [Font.col]

  cmp [Font.Italic], 0
  je NoItalic

  xor bx, bx
  mov bl, ch
  shr bl, 1
  sub di, bx
  NoItalic:

  mov es:[di], al

  MaskBit:


  inc dl
  cmp dl, 5
  jne nextcol

  inc si
  inc ch
  cmp ch, 5
  jne nextlin

  pop si
  DrawCharClip:
  ret
DrawChar         ENDP

;-------------------------------------------------------------------------------
DrawText         PROC
  mov ax, [Font.X]
  mov [Font.InitX], ax

  DrawNextChar:
  mov al, fs:[si]
  cmp al, 0
  je DrawTextEnd
  cmp al, 32
  jnb NoChangeFontColor
  mov [Font.Col], al
  jmp NoDrawChar
  NoChangeFontColor:
  cmp al, 255
  jne NoWrapLine
  add [Font.Y], 6
  mov bx, [Font.InitX]
  mov [Font.X], bx
  jmp NoDrawChar

  NoWrapLine:
  mov CharToDraw, al
  add [Font.X], 6
  cmp [Font.Shadow], 255
  je NoShadow
  inc [Font.X]
  inc [Font.Y]
  mov al, [Font.Col]
  push ax
  mov al, [Font.Shadow]
  mov [Font.Col], al
  call DrawChar
  dec [Font.X]
  dec [Font.Y]
  pop ax
  mov [Font.Col], al

  NoShadow:
  call DrawChar

  NoDrawChar:
  inc si
  jmp DrawNextChar

  DrawTextEnd:
  add [Font.X], 6
 ret
DrawText         ENDP

;-------------------------------------------------------------------------------
IntToString      PROC
  xor edx, edx
  mov ecx, StringMask
  mov bx, 1

  GetNextNumber:
  cmp ecx, 0
  je ConversionFinished
  div ecx
  add eax, 48
  mov NumberStr[bx], al
  mov eax, edx
  xor edx, edx

  push eax
  mov eax, ecx
  mov ecx, 10
  div ecx
  mov ecx, eax
  pop eax

  inc bl
  cmp bl, 9
  jne GetNextNumber

  ConversionFinished:
  mov NumberStr[bx], 0
  mov si, offset NumberStr
  call DrawText
  ret
IntToString      ENDP

;-------------------------------------------------------------------------------
WaitRetrace      PROC
  mov dx, 03DAh

  Retrace1:
  in al, dx
  test al, 08h
  jnz Retrace1

  Retrace2:
  in al,dx
  test al, 08h
  jz Retrace2
  ret
WaitRetrace      ENDP

;-------------------------------------------------------------------------------
ClearScreen      PROC
  cld
  mov ax, ds
  mov es, ax
  xor edi, edi
  mov di, offset Buffer

  mov cx, 16000
  xor eax, eax

  rep stosd
  ret
ClearScreen      ENDP


;-------------------------------------------------------------------------------
SpriteDraw         PROC
  mov ax, ds
  mov es, ax
  xor ch, ch

  nlin:
  xor dh, dh

  ncol:
  mov ax, [Rect.y]
  add al, ch
  shl ax, 6
  mov di, ax
  shl ax, 2
  add di, ax

  add di, [Rect.x]
  xor bx, bx
  mov bl, dh
  add di, bx

  add di, offset Buffer

  mov al, fs:[si]
  cmp al, 0
  je maskbyte
  cmp HeadFlag, 0
  jz drawnohead
  add al, 4

  drawnohead:
  mov es:[di], al

  maskbyte:
  inc si
  inc dh
  cmp dh, 8
  jne ncol
  inc ch
  cmp ch, 8
  jne nlin
  ret
SpriteDraw         ENDP

;-------------------------------------------------------------------------------
FlipBuffer       PROC
  cld
  mov ax, 0a000h
  mov es, ax

  xor edi, edi
  xor esi, esi
  mov si, offset buffer

  mov cx, 16000
  rep movsd

  ret
FlipBuffer       ENDP

;-------------------------------------------------------------------------------
DrawHL         PROC
  mov ax, ds
  mov es, ax
  cld
  mov ax, [Rect.Y]
  shl ax, 6
  mov di, ax
  shl ax, 2
  add di, ax
  add di, offset Buffer
  add di, [Rect.X]
  mov cx, [Rect.XL]
  mov al, [Rect.Color]
  rep stosb
  ret
DrawHL         ENDP

;-------------------------------------------------------------------------------
DrawVL         PROC
  mov ax, ds
  mov es, ax
  mov cx, [Rect.X]
  mov dx, [Rect.YL]
  DrawVLine:
  mov ax, [Rect.Y]
  shl ax, 6
  mov di, ax
  shl ax, 2
  add di, ax
  add di, offset Buffer
  add di, cx
  add cx, 320
  mov al, [Rect.Color]
  mov es:[di], al
  dec dx
  jnz DrawVLine
  ret
DrawVL         ENDP

;-------------------------------------------------------------------------------
DrawBox         PROC
  mov ax, [Rect.X]
  add ax, [Rect.XL]
  cmp ax, 320
  ja clip

  mov ax, [Rect.Y]
  add ax, [Rect.YL]
  cmp ax, 200
  ja clip

  mov dx, [Rect.Y]
  add dx, [Rect.YL]
  mov ax, ds
  mov es, ax
  DrawHLine:
  cld
  mov ax, dx
  shl ax, 6
  mov di, ax
  shl ax, 2
  add di, ax
  add di, offset Buffer
  add di, [Rect.X]
  mov cx, [Rect.XL]
  mov al, [Rect.Color]
  rep stosb
  dec dx
  cmp dx, [Rect.Y]
  ja DrawHLine
  Clip:
  ret
DrawBox         ENDP

;-------------------------------------------------------------------------------
DrawWindow       PROC
  push [Rect.YL]
  mov [Rect.YL], 7
  call DrawBox
  pop [Rect.YL]
  call DrawHL
  call DrawVL
  push [Rect.X]
  mov ax, [Rect.XL]
  add [Rect.X], ax
  call DrawVL
  pop [Rect.X]
  inc [Rect.XL]
  mov ax, [Rect.YL]
  add [Rect.Y], ax
  call DrawHL
  ret
DrawWindow       ENDP

;-------------------------------------------------------------------------------
InitializeSnake  PROC
  mov bx, 0
  ToZero:
  mov SnakeX[bx], 0
  mov SnakeY[bx], 0
  inc bx
  cmp bx, 50
  jne ToZero

  mov Vel, 10
  mov al, 19
  mov cl, 12
  mov SnakeX[0], al
  mov SnakeY[0], cl
  dec al
  mov SnakeX[1], al
  mov SnakeY[1], cl
  dec al
  mov SnakeX[2], al
  mov SnakeY[2], cl

  mov SCount, 3
  mov Dir, 1
  mov DotX, 0
  mov DotY, 0
  mov Score, 0
  mov Level, 0
  ret
InitializeSnake  ENDP

;-------------------------------------------------------------------------------
SnakeInXY        PROC
  mov al, 1
  xor bx, bx
  mov bl, SCount
  dec bl

  TestCol:
  cmp cl, SnakeX[bx]
  jne NextIter
  cmp dl, SnakeY[bx]
  je SIXYEnd

  NextIter:
  dec bx
  cmp bx, 0
  jne Testcol
  jmp NoCol

  NoCol:
  mov al, 0
  SIXYEnd:
  ret
SnakeInXY        ENDP

;-------------------------------------------------------------------------------
PutDot           PROC
  RegenerateAll:
  mov al, DotX
  mov TempByte, al
  mov randrange, 39

  RegenerateDotX:
  call random
  mov DotX, dl
  mov al, TempByte
  cmp al, DotX
  je RegenerateDotX

  mov al, DotY
  mov TempByte, al
  mov randrange, 22

  RegenerateDotY:
  call Random
  mov DotY, dl
  inc DotY
  mov al, TempByte
  cmp al, DotY
  je RegenerateDotY

  mov cl, DotX
  mov dl, DotY
  call SnakeInXY
  cmp al, 0
  je TestHead
  jmp RegenerateAll
  TestHead:
  mov al, DotX
  cmp al, SnakeX[0]
  jne EndPutDot
  mov al, DotY
  cmp al, SnakeY[0]
  je RegenerateAll
  EndPutDot:
  ret
PutDot           ENDP

;-------------------------------------------------------------------------------
DrawGameOver PROC
  GameOverScreen:
  mov [Rect.X], 30
  mov [Rect.Y], 65
  mov [Rect.XL], 260
  mov [Rect.YL], 60
  mov [Rect.Color], 1
  call DrawWindow

  mov si, offset GOverTitle
  mov [Font.X], 120
  mov [Font.Y], 66
  mov [Font.Shadow], 0
  call DrawText
  mov [Font.Shadow], 255
  call FlipBuffer

  mov si, offset GameOver
  mov [Font.X], 26
  mov [Font.Y], 90
  call DrawText
  call FlipBuffer

  mov ah, 01h
  int 16h
  jz GameOverScreen

  mov ah, 00h
  int 16h

  cmp al, 13
  je Start
  cmp ah, 01
  je Fim

  jmp GameOverScreen
  ret
DrawGameOver ENDP

;-------------------------------------------------------------------------------
UpdateSnake      PROC
  xor ax, ax
  mov al, Level
  inc al
  shl al, 2
  mov Vel, al
  shl al, 1
  add Vel, al

  cmp IntroMode, 1
  je JumpColTest

  mov cl, SnakeX[0]
  mov dl, SnakeY[0]
  call SnakeInXY
  cmp al, 0
  je GoUpdate

  Collisioned:
  call DrawGameOver

  JumpColTest:
  GoUpdate:
  mov cl, SnakeX[0]
  mov dl, SnakeY[0]

  cmp cl, DotX
  jne InitUpdate
  cmp dl, DotY
  jne InitUpdate

  inc SCount

  cmp IntroMode, 1
  je JumpAddScore
  add Score, 250
  JumpAddScore:
  call Putdot
  cmp SCount, 49
  jna InitUpdate
  cmp IntroMode, 1
  je JumpIncLevel
  inc Level
  JumpIncLevel:
  mov SCount, 3

  InitUpdate:
  mov cl, SCount
  dec cl
  xor bx, bx
  UpdateNext:
  mov bl, cl
  dec bl
  mov al, SnakeX[bx]
  inc bl
  mov SnakeX[bx], al
  dec bl
  mov al, SnakeY[bx]
  inc bl
  mov SnakeY[bx], al
  dec cl
  cmp cl, 0
  jne UpdateNext

  mov cl, Dir

  GoLeft:
  cmp cl, 0
  jne GoRight

  mov cl, SnakeX[0]
  cmp cl, 0
  je ToRight

  dec SnakeX[0]
  jmp GoNothing

  ToRight:
  mov SnakeX[0], 39
  jmp GoNothing

  GoRight:
  cmp cl, 1
  jne GoUp

  mov cl, SnakeX[0]
  cmp cl, 39
  je ToLeft

  inc SnakeX[0]
  jmp GoNothing

  ToLeft:
  mov SnakeX[0], 0
  jmp GoNothing

  GoUp:
  cmp cl, 2
  jne GoDown

  mov cl, SnakeY[0]

  cmp cl, 0
  je ToDown

  dec SnakeY[0]
  jmp GoNothing

  ToDown:
  mov SnakeY[0], 23
  jmp GoNothing

  GoDown:
  cmp cl, 3
  jne GoNothing

  mov cl, SnakeY[0]
  cmp cl, 23
  je ToUp

  inc SnakeY[0]
  jmp GoNothing

  ToUp:
  mov SnakeY[0], 0

  GoNothing:
  ret
UpdateSnake      ENDP

;-------------------------------------------------------------------------------
DrawInstructions PROC
  mov [Rect.X], 50
  mov [Rect.Y], 30
  mov [Rect.XL], 220
  mov [Rect.YL], 84
  mov [Rect.Color], 23
  call DrawWindow

  mov si, offset InstrTitle
  mov [Font.X], 120
  mov [Font.Y], 31
  mov [Font.Shadow], 0
  call DrawText
  mov [Font.Shadow], 255

  mov si, offset Instruct
  mov [Font.X], 60
  mov [Font.Y], 45
  call DrawText

  mov si, offset PressAKey
  mov [Font.X], 65
  mov [Font.Y], 103
  call DrawText
  ret
DrawInstructions ENDP

;-------------------------------------------------------------------------------
DrawCredits      PROC
  mov [Font.Italic], 1
  mov [Font.X], 1
  mov [Font.Y], 1
  mov [Font.Shadow], 22
  mov si, offset GameTitle
  call DrawText
  mov [Font.Shadow], 255

  mov [Font.Italic], 0
  mov [Font.X], 250
  mov [Font.Y], 1
  mov [Font.Shadow], 1
  mov si, offset Ver
  call DrawText
  mov [Font.Shadow], 255
  ret
DrawCredits      ENDP

;-------------------------------------------------------------------------------
DrawStatus       PROC
  mov [Rect.X], 1
  mov [Rect.Y], 191
  mov [Rect.XL], 318
  mov [Rect.YL], 8
  mov [Rect.Color], 8
  call DrawBox

  mov [Font.X], 5
  mov [Font.Y], 194
  mov si, offset ScoreText
  call DrawText

  mov [Font.X], 45
  mov [Font.Y], 194

  mov eax, score
  mov StringMask, 10000000
  call IntToString

  mov [Font.X], 125
  mov [Font.Y], 194
  mov si, offset LevelText
  call DrawText

  mov [Font.X], 165
  mov [Font.Y], 194

  xor eax, eax
  mov al, Level
  mov StringMask, 1
  call IntToString
  ret
DrawStatus       ENDP

;-------------------------------------------------------------------------------
DrawDebuggerWindow PROC
  mov StringMask, 10
  
  mov [Rect.X], 230
  mov [Rect.Y], 10
  mov [Rect.XL], 87
  mov [Rect.YL], 65
  mov [Rect.Color], 15
  call DrawWindow
  mov [Font.X], 252
  mov [Font.Y], 12
  mov [Font.Shadow], 0
  mov si, offset DebugTitle
  call DrawText
  mov [Font.Shadow], 255

  mov [Font.X], 226
  mov [Font.Y], 20
  mov si, offset DotXStr
  call DrawText

  xor eax, eax
  mov al, DotX
  call IntToString

  mov [Font.X], 226
  mov [Font.Y], 28
  mov si, offset DotYStr
  call DrawText

  xor eax, eax
  mov al, DotY
  call IntToString

  mov [Font.X], 226
  mov [Font.Y], 36
  mov si, offset SnakeXStr
  call DrawText

  xor eax, eax
  mov al, SnakeX[0]
  call IntToString

  mov [Font.X], 226
  mov [Font.Y], 44
  mov si, offset SnakeYStr
  call DrawText

  xor eax, eax
  mov al, SnakeY[0]
  call IntToString

  mov [Font.X], 226
  mov [Font.Y], 52
  mov si, offset SnakeStr
  call DrawText

  xor eax, eax
  mov al, SCount
  call IntToString

  mov [Font.X], 226
  mov [Font.Y], 60
  mov si, offset SSStr
  call DrawText

  mov StringMask, 1

  xor eax, eax
  mov al, ShowStars
  call IntToString

  mov [Font.X], 226
  mov [Font.Y], 68
  mov si, offset SnakeDirStr
  call DrawText

  cmp dir, 0
  jne drawrightstr
  mov si, offset LeftStr
  call DrawText
  jmp drawstrend

  drawrightstr:
  cmp dir, 1
  jne drawupstr
  mov si, offset RightStr
  call DrawText
  jmp drawstrend

  drawupstr:
  cmp dir, 2
  jne drawdownstr
  mov si, offset UpStr
  call DrawText
  jmp drawstrend

  drawdownstr:
  cmp dir, 3
  jne drawrightstr
  mov si, offset DownStr
  call DrawText

  drawstrend:
  ret
DrawDebuggerWindow ENDP

;-------------------------------------------------------------------------------
DrawScreen       PROC
  xor ax, ax
  mov al, DotX
  shl ax, 3
  mov [Rect.X], ax
  xor ax, ax
  mov al, DotY
  shl ax, 3
  mov [Rect.Y], ax

  mov HeadFlag, 0
  mov si, offset Dot
  call SpriteDraw

  fldpi
  fidiv DegPi
  fimul Angle

  fcos
  fimul Radius
  fistp TempX

  fldpi
  fidiv DegPi
  fimul Angle
  fsin
  fimul Radius
  fistp TempY

  mov ax, TempX
  mov bx, TempY
  add bx, [Rect.X]
  add ax, [Rect.Y]
  mov [Rect.X], bx
  mov [Rect.Y], ax

  mov si, offset Dot
  call SpriteDraw

  sub Angle, 6
  cmp Angle, 0
  jnz NoRestoreAngle
  mov angle, 360

  NoRestoreAngle:
  xor bx, bx
  xor cx, cx
  mov cl, SCount
  dec cl

  DrawSnake:
  mov bl, cl
  xor ax, ax
  mov al, SnakeX[bx]
  shl ax, 3
  mov [Rect.X], ax

  xor ax, ax
  mov al, SnakeY[bx]
  shl ax, 3
  mov [Rect.Y], ax

  mov HeadFlag, 0
  cmp cx, 0
  jne NoHead
  mov HeadFlag, 1
  NoHead:
  mov si, offset SnakeBody
  push cx
  call SpriteDraw
  pop cx
  dec cl
  cmp cl, 255
  jne DrawSnake
  ret
DrawScreen       ENDP

;-------------------------------------------------------------------------------
DrawGame Proc
  mov al, Vel
  add VelCount, al
  cmp VelCount, 100
  jb NoUpdate
  mov VelCount,0
  add Score, 1

  call UpdateSnake

  NoUpdate:
  call ClearScreen
  cmp ShowStars, 0
  je HideStars
  call DrawStars

  HideStars:
  call DrawScreen
  call DrawStatus
  cmp ShowDebug, 0
  je HideDebugger
  call DrawDebuggerWindow

  HideDebugger:
  call DrawCredits
  call WaitRetrace
  call FlipBuffer
  ret
DrawGame ENDP

DrawIntro PROC
  mov IntroMode, 1
  Intro:
  call AutoPilot
  call UpdateSnake
  call ClearScreen
  call DrawStars
  call DrawScreen
  mov Rect.X, 35
  mov Rect.Y, 15
  call DrawRLELogo
  mov [Font.X], 65
  mov [Font.Y], 82
  mov si, offset PressAKey
  call DrawText
  mov [Font.X], 220
  mov [Font.Y], 194
  mov si, offset Credits
  call DrawText
  call WaitRetrace
  call FlipBuffer

  mov ah, 01h
  int 16h
  jz Intro
  mov ah, 00h
  int 16h
  cmp al, 32
  je NewGame
  cmp ah, 01
  je @@Finalize
  jmp Intro
  NewGame:
  mov IntroMode, 0
  call InitializeGame
  call ClearScreen
  call FlipBuffer
  mov al, 32
  ret
  @@Finalize:
  call GameEnd
DrawIntro ENDP

GameEnd PROC
  mov ah, 0Ch
  mov al, 02h
  int 21h
  call clearscreen
  mov [Font.X], 40
  mov [Font.Y], 10
  mov si, offset finalcredits
  call DrawText
  mov [Font.X], 80
  mov [Font.Y], 187
  mov si, offset pressanykey
  call DrawText
  call flipbuffer
  Adeus:
  mov ah, 01h
  int 16h
  jz Adeus

  call TextMode
  mov ax, 4c00h
  int 21h
GameEnd ENDP

;-------------------------------------------------------------------------------
InitializeGame PROC
  call InitializeSnake

  mov IntroMode, 0
  mov Radius, 4
  Mov TempX, 0
  Mov TempY, 0
  mov degpi, 180
  mov angle, 360

  call PutDot

  call DrawGame

  mov ShowDebug, 0
  mov ShowStars, 1

  ret
InitializeGame ENDP

;-------------------------------------------------------------------------------
AutoPilot       PROC
  @TestX:
  mov al, DotX
  cmp SnakeX[0], al
  je @TestY
  cmp SnakeX[0], al
  jnb @GoLeft
  cmp dir, 0
  je @TestY
  mov dir, 1
  jmp @End
  @GoLeft:
  cmp dir, 1
  je @TestY
  mov dir, 0
  jmp @End

  @TestY:
  mov al, DotY
  cmp SnakeY[0], al
  jna @GoDown
  cmp dir, 3
  je @End
  cmp SnakeY[0], 2
  jb @GoQuicklyLeft
  mov dir, 2
  jmp @End
  @GoDown:
  cmp dir, 2
  je @End
  mov dir, 3
  jmp @End
  @GoQuicklyLeft:
  mov dir, 0
  @End:

  ColRight:
  cmp dir, 1
  jne ColUp
  mov cl, SnakeX[0]
  mov dl, SnakeY[0]
  inc cl
  call SnakeInXY
  cmp al, 1
  jne @ColEnd
  mov dir, 3
  dec cl
  inc dl
  call SnakeInXY
  cmp al, 1
  jne @ColEnd
  mov dir, 2

  ColUp:
  cmp dir, 2
  jne ColDown
  mov cl, SnakeX[0]
  mov dl, SnakeY[0]
  dec dl
  call SnakeInXY
  cmp al, 1
  jne @ColEnd
  mov dir, 0
  inc dl
  dec cl
  call SnakeInXY
  cmp al, 1
  jne @ColEnd
  mov dir,1

  ColDown:
  cmp dir, 3
  jne ColLeft
  mov cl, SnakeX[0]
  mov dl, SnakeY[0]
  inc dl
  call SnakeInXY
  cmp al, 1
  jne @ColEnd
  mov dir, 1
  inc cl
  dec dl
  call SnakeInXY
  cmp al, 1
  jne @ColEnd
  mov dir,0

  ColLeft:
  cmp dir, 0
  jne @ColEnd
  mov cl, SnakeX[0]
  mov dl, SnakeY[0]
  dec cl
  call SnakeInXY
  cmp al, 1
  jne @ColEnd
  mov dir, 2
  dec dl
  inc cl
  call SnakeInXY
  cmp al, 1
  jne @ColEnd
  mov dir, 1

  @ColEnd:

  ret
AutoPilot       ENDP

;-------------------------------------------------------------------------------
DrawRLELogo   PROC
  mov TempX, 0
  mov TempY, 0
  mov si, offset Logo
  mov ax, ds
  mov es, ax
  mov bx, 1220
  DrawLogo:
  mov dh, gs:[si]
  inc si
  mov dl, gs:[si]
  dec bx
  dec bx
  DrawLength:
  xor cl, cl
  DrawBits:
  mov ch, dl
  shr ch, cl
  and ch, 1
  jz jumpdrawbit
  mov di, offset buffer
  mov ax, TempY
  add ax, [Rect.Y]
  shl ax, 6
  add di,ax
  shl ax, 2
  add di,ax
  add di, TempX
  add di, [Rect.X]
  mov al, 23
  mov es:[di], al
  jumpdrawbit:
  inc TempX
  cmp TempX, 249
  jne JumpWrapLogoLine
  mov TempX, 0
  inc TempY
  JumpWrapLogoLine:
  inc cl
  cmp cl, 8
  jne DrawBits
  dec dh
  jnz DrawLength
  inc si
  or bx, bx
  jnz DrawLogo
ret
DrawRLELogo   ENDP

;===============================================================================
Start:
  mov ax, @data
  mov ds, ax

  mov ax, @dsegment2
  mov fs, ax

  mov ax, @dsegment3
  mov gs, ax

  mov ah, 2ch
  int 21h
  mov ax, Seed
  add ah, dl
  mul dx
  inc ax
  mov Seed, ax

  call Mode13h
  finit

  call InitStars
  call InitializeGame
  call DrawIntro
  jmp TestSpace
  MainLoop:
  call DrawGame

  mov ah, 01h
  int 16h
  jz MainLoop

  mov ah, 00h
  int 16h

  cmp Ah, 72
  jne TestDown
  cmp Dir, 3
  je TestEnd
  mov Dir, 2
  jmp TestEnd

  TestDown:
  cmp ah, 80
  jne TestLeft
  cmp Dir, 2
  je TestEnd
  mov Dir, 3
  jmp TestEnd

  TestLeft:
  cmp ah, 75
  jne TestRight
  cmp Dir, 1
  je TestEnd
  mov Dir, 0
  jmp TestEnd

  TestRight:
  cmp ah, 77
  jne TestReturn
  cmp Dir, 0
  je TestEnd
  mov Dir, 1
  jmp TestEnd

  TestReturn:
  cmp al, 13
  jne TestDebug
  cmp ShowDebug, 1
  jne TestEnd
  inc Level
  cmp Level, 9
  jna TestDebug
  mov Level, 0
  jmp TestEnd

  TestDebug:
  cmp al, 100
  jne TestStars
  cmp ShowDebug, 0
  je SetDebug
  mov ShowDebug,0
  jmp TestEnd
  SetDebug:
  mov ShowDebug, 1
  jmp TestEnd

  TestStars:
  cmp al, 115
  jne TestSpace
  cmp ShowStars, 0
  je SetStars
  mov ShowStars,0
  jmp TestEnd
  SetStars:
  mov ShowStars, 1
  jmp TestEnd


  TestSpace:
  cmp al, 32
  jne TestEnd
  PauseGame:
  call DrawInstructions
  call FlipBuffer
  mov ah, 01h
  int 16h
  jz PauseGame
  mov ah, 00h
  int 16h
  cmp al, 32
  jne Pausegame
  mov ah, 0

  TestEnd:
  mov bl, ah
  mov ah, 0Ch
  mov al, 02h
  int 21h
  cmp bl, 01
  jne MainLoop

  Fim:
  call GameEnd
END Start
;=============================================================================;
;eof
