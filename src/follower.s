
.include "common.inc"

.import DividePDiff, DumpTwoSpr

.segment "WRAM"

.export FRAME_LAG_COUNT
FRAME_LAG_COUNT = 16

; Cloned Data
; F_Player_State:       .res FRAME_LAG_COUNT
F_PlayerFacingDir:    .res FRAME_LAG_COUNT
F_Player_X_Position:  .res FRAME_LAG_COUNT
F_Player_PageLoc:     .res FRAME_LAG_COUNT
F_Player_Y_HighPos:   .res FRAME_LAG_COUNT
F_Player_Y_Position:  .res FRAME_LAG_COUNT
F_Player_SprAttrib:   .res FRAME_LAG_COUNT
F_PlayerGfxOffset:    .res FRAME_LAG_COUNT

.export F_Player_Hideflag
; Special flags
F_Player_Hideflag:    .res 1

; Calculated Data
; F_Player_Rel_XPos: .res 1
; F_Player_Rel_YPos: .res 1
; F_Player_OffscreenBits: .res 1

; Other
; Write head of the circular buffer
F_Frame: .res 1

.segment "PLAYER"

.export InitFollower
.proc InitFollower
  lda #0
  sta F_Player_Hideflag
  lda #$ff
  ldx #FRAME_LAG_COUNT-1
  :
    sta F_Player_Y_Position,x
    dex
    bpl :-
  rts
.endproc

.export FreezeFollowerX
.proc FreezeFollowerX
  ldx F_Frame
  sta F_Player_X_Position,x
  rts
.endproc

.export FreezeFollowerY
.proc FreezeFollowerY
  ldx F_Frame
  sta F_Player_X_Position,x
  rts
.endproc

.export CopyPlayerStateToFollower
.proc CopyPlayerStateToFollower

  ldx F_Frame

  ; lda Player_State
  ; sta F_Player_State,x

  lda PlayerFacingDir
  sta F_PlayerFacingDir,x

  lda Player_X_Position
  sta F_Player_X_Position,x

  lda Player_PageLoc
  sta F_Player_PageLoc,x

  lda Player_Y_HighPos
  sta F_Player_Y_HighPos,x

  lda Player_Y_Position
  sta F_Player_Y_Position,x

  lda Player_SprAttrib
  sta F_Player_SprAttrib,x

  lda PlayerGfxOffset
  sta F_PlayerGfxOffset,x

  ; wrap the pointer around
  inx
  cpx #FRAME_LAG_COUNT
  bne :+
    ldx #0
:
  stx F_Frame
  rts
.endproc

.export RenderPlayerFollower
.proc RenderPlayerFollower

  ; Calculate follower position/offscreen information
  ; using the older data but with the current screen position
  ldx F_Frame

  lda #4
  sta R7
  ; sta R7                      ;store number of rows of sprites to draw

  lda F_Player_X_Position,x  ;load horizontal coordinate
  sec                         ;subtract left edge coordinate
  sbc ScreenLeft_X_Pos
  sta R5
  ; sta R5                      ;store it here also
  
  lda F_Player_Y_Position,x  ;load vertical coordinate low
  sta R2
  ; lda Player_Rel_YPos
  ; sta R2                      ;store player's vertical position
  
  lda F_PlayerFacingDir,x  ;load vertical coordinate low
  sta R3
  ; lda PlayerFacingDir
  ; sta R3                      ;store player's facing direction

  lda F_Player_SprAttrib,x  ;load vertical coordinate low
  sta R4
  ; lda Player_SprAttrib
  ; sta R4                      ;store player's sprite attributes

  lda F_PlayerGfxOffset,x
  tax
  ; ldx PlayerGfxOffset          ;load graphics table offset
  ldy FollowerOAMOffset
  ; ldy PlayerOAMOffset
DrawPlayerLoop:
.import PlayerGraphicsTable, DrawOneSpriteRow
    lda PlayerGraphicsTable,x    ;load player's left side
    ora #$40
    sta R0
    lda PlayerGraphicsTable+1,x  ;now load right side
    ora #$40
    jsr DrawOneSpriteRow
    dec R7                      ;decrement rows of sprites to draw
    bne DrawPlayerLoop           ;do this until all rows are drawn

  ldx F_Frame
  ; jsr F_GetOffscreen
  jsr F_YOffscreenBits
  sta R0

  ldx #3                      ;check all four rows of player sprites
  lda FollowerOAMOffset      ;get player's sprite data offset
  clc
  adc #$18                      ;add 24 bytes to start at bottom row
  tay
PROfsLoop:
    lda #$f8                      ;load offscreen Y coordinate just in case
    lsr R0                       ;shift bit into carry
    bcc :+                 ;if bit not set, skip, do not move sprites
      jsr DumpTwoSpr                ;otherwise dump offscreen Y coordinate into sprite data
:
    tya
    sec                           ;subtract eight bytes to do
    sbc #$08                      ;next row up
    tay
    dex                           ;decrement row counter
    bpl PROfsLoop                 ;do this until all sprite rows are checked
  rts                             ;then we are done!

.endproc

;; Copy pasted and edited to work for the follower

.proc F_GetOffscreen
  jsr F_XOffscreenBits  ;do subroutine here
  lsr                    ;move high nybble to low
  lsr
  lsr
  lsr
  sta R0                ;store here
  jsr F_YOffscreenBits
  asl                         ;move low nybble to high nybble
  asl
  asl
  asl
  ora R0                     ;mask together with previously saved low nybble
  sta R0                     ;store both here
  rts
.endproc

.proc F_XOffscreenBits
  stx R4                     ;save position in buffer to here
  ldy #$01                    ;start with right side of screen
XOfsLoop:
    lda ScreenEdge_X_Pos,y      ;get pixel coordinate of edge
    sec                         ;get difference between pixel coordinate of edge
    sbc F_Player_X_Position,x  ;and pixel coordinate of object position
    sta R7                     ;store here
    lda ScreenEdge_PageLoc,y    ;get page location of edge
    sbc F_Player_PageLoc,x     ;subtract page location of object position from it
    ldx DefaultXOnscreenOfs,y   ;load offset value here
    cmp #$00
    bmi Skip                ;if beyond right edge or in front of left edge, branch
      ldx DefaultXOnscreenOfs+1,y ;if not, load alternate offset value here
      cmp #$01      
      bpl Skip                ;if one page or more to the left of either edge, branch
        lda #$38                    ;if no branching, load value here and store
        sta R6
        lda #$08                    ;load some other value and execute subroutine
        jsr DividePDiff
Skip:
    lda XOffscreenBitsData,x    ;get bits here
    ldx R4                     ;reobtain position in buffer
    cmp #$00                    ;if bits not zero, branch to leave
    bne :+
    dey                         ;otherwise, do left side of screen now
    bpl XOfsLoop                ;branch if not already done with left side
:
  rts

XOffscreenBitsData:
  .byte $7f, $3f, $1f, $0f, $07, $03, $01, $00
  .byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff

DefaultXOnscreenOfs:
  .byte $07, $0f, $07
.endproc

.proc F_YOffscreenBits
  stx R4                      ;save position in buffer to here
  ldy #$01                     ;start with top of screen
YOfsLoop:
  lda HighPosUnitData,y        ;load coordinate for edge of vertical unit
  sec
  sbc F_Player_Y_Position,x   ;subtract from vertical coordinate of object
  sta R7                      ;store here
  lda #$01                     ;subtract one from vertical high byte of object
  sbc F_Player_Y_HighPos,x
  ldx DefaultYOnscreenOfs,y    ;load offset value here
  cmp #$00
  bmi YLdBData                 ;if under top of the screen or beyond bottom, branch
  ldx DefaultYOnscreenOfs+1,y  ;if not, load alternate offset value here
  cmp #$01
  bpl YLdBData                 ;if one vertical unit or more above the screen, branch
  lda #$20                     ;if no branching, load value here and store
  sta R6
  lda #$04                     ;load some other value and execute subroutine
  jsr DividePDiff
YLdBData:
  lda YOffscreenBitsData,x     ;get offscreen data bits using offset
  ldx R4                      ;reobtain position in buffer
  cmp #$00
  bne ExYOfsBS                 ;if bits not zero, branch to leave
  dey                          ;otherwise, do bottom of the screen now
  bpl YOfsLoop
ExYOfsBS: rts

YOffscreenBitsData:
  .byte $00, $08, $0c, $0e
  .byte $0f, $07, $03, $01
  .byte $00

DefaultYOnscreenOfs:
  .byte $04, $00, $04

HighPosUnitData:
  .byte $ff, $00

.endproc