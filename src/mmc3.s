
.include "common.inc"

.segment "FIXED"

; x = bank to switch to
FarCallCommon:
  lda CurrentBank
  pha
    lda #7 | PRG_FIXED_8
    sta BankShadow
    sta BANK_SELECT
    lda NextBank
    sta BANK_DATA
    sta CurrentBank
    jsr TargetAddrJmp
    lda #7 | PRG_FIXED_8
    sta BankShadow
    sta BANK_SELECT
  pla
  sta BANK_DATA
  sta CurrentBank
  rts
