;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Optimized block change - imamelia, mario90
;; This rewrites the original block change routine and allows much more blocks to be changed
;; in a single frame without overflowing V-blank (black bars on the top of the screen)
;;
;; VRAM base address = $3000
;; small-scale upload table = $7FB700 (index at $06F9)
;; large-scale upload table = $7FB800 (index at $06FB)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

if read1($00FFD5) == $23
	sa1rom	
	!sa1 = 1
	!base1	= $3000
	!base2	= $6000
	!base3	= $000000
else	
	lorom	
	!sa1 = 0
	!base1	= $0000
	!base2	= $0000
	!base3	= $800000
endif
	!dp		= !base1
	!addr	= !base2
	!bank	= !base3
	
;You can change the ram here if needed
;lorom
!VRAMUploadTblSmall = $7FB700
!VRAMUploadTblLarge = $7FB800
!VRAMUploadTblSmallIndex = $06F9
!VRAMUploadTblLargeIndex = $06FB

;SA-1
!VRAMUploadTblSmallSA1 = $40A000
!VRAMUploadTblLargeSA1 = $40A100
!VRAMUploadTblSmallIndexSA1 = $66F9
!VRAMUploadTblLargeIndexSA1 = $66FB

if !sa1
!VRAMUploadTblSmall = !VRAMUploadTblSmallSA1
!VRAMUploadTblLarge = !VRAMUploadTblLargeSA1
!VRAMUploadTblSmallIndex = !VRAMUploadTblSmallIndexSA1
!VRAMUploadTblLargeIndex = !VRAMUploadTblLargeIndexSA1
endif

org $00C13E
BlockChangeRewrite:
	LDX !VRAMUploadTblSmallIndex
	CPX #$0100
	BCS Return
	LDA $98
	SEC
	SBC $1C
	CLC
	ADC #$0020
	CMP #$0120
	BCS Return
	LDA $1933|!addr
	BNE .Layer2
.Layer1
	autoclean JML SetLayer1Addr
.Layer2
	autoclean JML SetLayer2Addr
StoreAddress:
	STA !VRAMUploadTblSmall,x
	INC
	STA !VRAMUploadTblSmall+8,x
	CLC
	ADC #$001F
	STA !VRAMUploadTblSmall+4,x
	INC
	STA !VRAMUploadTblSmall+12,x
	BRA Label00C17A

org $00C17A
Label00C17A:

org $00C17F
	STA $04
	LDA [$04]
	STA !VRAMUploadTblSmall+2,x
	LDY #$0002
	LDA [$04],y
	STA !VRAMUploadTblSmall+6,x
	LDY #$0004
	LDA [$04],y
	STA !VRAMUploadTblSmall+10,x
	LDY #$0006
	LDA [$04],y
	STA !VRAMUploadTblSmall+14,x
	TXA
	CLC
	ADC #$0010
	STA !VRAMUploadTblSmallIndex
Return:
	RTS


freecode

SetLayer1Addr:
	LDA $06
	XBA
	CMP #$3800
	BCS .End
	AND #$07FF
	ORA #$3000
.End
	JML StoreAddress

SetLayer2Addr:
	LDA $06
	XBA
	CMP #$3800
	BCS .End
	AND #$07FF
	ORA #$3000
	CLC
	ADC #$0800
.End
	JML StoreAddress
