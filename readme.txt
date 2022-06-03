
This consists of two things: a system for easily uploading data to VRAM, and a rewrite to SMW's block change routine to use that system instead of the stripe image one that it normally uses.

The block-changing routine doesn't require anything different from how you'd normally use it; you can call $00BEB0 or the custom Map16 change routine the same as you would before.  Now that it uses DMA instead of stripe image, however, it allows many more blocks to be changed within a single frame than were possible before.  With the old system, changing more than 3 or 4 blocks at once would cause screen flicker, but now, you can change up to 16 depending on how much other stuff is running in the level (or possibly more than that; the default defines make the table large enough for 16 blocks, but that can be changed).  Naturally, anything that requires heavy processing, such as dynamic sprites, will reduce the limit.

You'll need UberASM for the following or this patch won't work. These steps assume you're using UberASM tool specifically. First patch optimize_block_change.asm to your ROM. Then open UberASM_Global_NMI_code.txt and either copy and paste it under nmi in global_code.asm or if you're running more code under nmi, then paste it at the bottom of the file, give it its own label and JSR to it. Make sure to paste the ram defines somewhere in the file as well. You likely won't need to change the default ram addresses, but if they conflict with something, you can. Just make sure they match in both the block patch and the UberASM portion. If you just want to use this patch to optimize the block change, then you can stop reading here.

The VRAM upload queue system is for advanced use.  It consists of two tables, which are 0x100 and 0x400 bytes long by default (or 256 and 1024) and each have a 16-bit index associated with them.  The indexes should be 16-bit addresses, and the tables should be 24-bit addresses.

The small table has 4 bytes per entry, allowing for up to 64 entries.  The first 2 bytes indicate a VRAM address to upload to (note that it's divided by 2, so, for instance, if you want to upload to the start of the sprite graphics at $C000, put $6000 here), and the second two bytes are data to upload to that address.  This can be used for changing single 8x8 tiles, or multiple 8x8 tiles with multiple entries, which is what the rewritten block change routine does; it uses one entry for each 8x8 tile of the block that is being changed.

The large table is more complex.  It has 12 bytes per entry (the last 4 bytes are actually unused, since 1024 doesn't divide evenly by 12) specifying various parameters.  The first byte is the DMA settings, which gets transferred to register $4300.  The second byte is the register to affect.  Normally, this is #$18, indicating register $2118, which writes data to VRAM, but it can also be #$19 (the high byte of $2118; use this if you're only changing the high byte of VRAM data, not the low byte), #$39 (register $2139, used for reading data from VRAM instead of writing it), or #$3A (the high byte of $2139).  It can even be a register unrelated to VRAM if you want to point the DMA somewhere else, as long as it's in the $21xx range (the high byte is always #$21).  The third, fourth, and fifth bytes are the source address for the DMA, i.e., where the data you want to transfer is.  This can be anywhere, including ROM, regular RAM, or SRAM (though pointing it to hardware registers or an undefined area would be unwise), and it gets transferred to $4302-04.  The sixth and seventh bytes are the size of the data, how many bytes should be uploaded, and it gets transferred to $4305-06.  This is not 1 less as some things are; putting #$0006 here will transfer 6 bytes.  (Putting #$0000 will actually transfer $10000 bytes rather than 0, but that's not practical outside of F-blank anyway.)  The eighth byte is the VRAM settings, which get transferred to $2115.  The ninth and tenth bytes are the destination address in VRAM, which gets transferred to $2116-17.  Finally, the eleventh and twelfth bytes are a delay timer.  If this is a nonzero value, the DMA will be delayed by that many frames.

In summary:

Small table format:
- 4 bytes per entry
- Bytes 1-2: VRAM address to affect.
- Bytes 3-4: Data to write.

Large table format:
- 12 bytes per entry
- Byte 1: DMA settings (value of $4300).
- Byte 2: Register to affect (value of $4301).
- Bytes 3-5: DMA source address (values of $4302-$4304).
- Bytes 6-7: Size of data (values of $4305-$4306).
- Byte 8: VRAM settings (value of $2115).
- Bytes 9-10: Destination VRAM address (values of $2116-$2117).
- Bytes 11-12: Delay timer.  If this is set, the DMA will be delayed by this many frames.  In addition, the data will be shunted to the beginning of the buffer, and the index to it will end up being a value other than 0 after all the other DMAs finish.

For both tables, you must index them with the corresponding index, check to make sure it hasn't overflowed the table, and when you're done writing your data, you should increment the index by the number of bytes you used (usually 4 for the small table and 12/#$0C for the large one; can be more if you used multiple entries).  Some example code might look like this:

WriteSmallTable:
	REP #$30
	LDX !VRAMUploadTblSmallIndex
; make sure the index isn't bigger than the table size
	CPX #$0100
	BCS .Invalid
; VRAM address destination
	LDA #$1234
	STA !VRAMUploadTblSmall,x
; data to write
	LDA #$5678
	STA !VRAMUploadTblSmall+2,x
; we only used 1 entry, which is 4 bytes, so add 4 to the index
	TXA
	CLC
	ADC #$0004
	STA !VRAMUploadTblSmallIndex
.Invalid
	SEP #$30
	RTS

WriteLargeTable:
	REP #$30
	LDX !VRAMUploadTblLargeIndex
	CPX #$0400
	BCS .Invalid
; byte 1: DMA settings - CPU -> PPU, direct, increment, 2 registers write once
; byte 2: register to affect = $2118
	LDA #$1801
	STA !VRAMUploadTblLarge,x
; bytes 3-4: low and high bytes of the source address (using $7F9500 as an example)
	LDA #$9500
	STA !VRAMUploadTblLarge+2,x
; byte 5: bank byte of the source address (writing the middle byte twice because we're in 16-bit mode and this is 3 bytes long))
	LDA #$7F95
	STA !VRAMUploadTblLarge+3,x
; bytes 6-7: how many bytes of data we're uploading (using #$0200 as an example)
	LDA #$0200
	STA !VRAMUploadTblLarge+5,x
; byte 8: VRAM settings - increment after writing $2119 (the high byte here doesn't matter; it will just be overwritten next anyway)
	LDA #$0080
	STA !VRAMUploadTblLarge+7,x
; bytes 9-10: destination VRAM address (this time using the start of the second page of sprite graphics as an example)
	LDA #$7000
	STA !VRAMUploadTblLarge+8,x
; bytes 11-12: delay timer (this usually isn't set anyway)
	LDA #$0000
	STA !VRAMUploadTblLarge+10,x
; we only used 1 entry, which is 12 bytes, so add #$0C to the index
	TXA
	CLC
	ADC #$000C
	STA !VRAMUploadTblLargeIndex
.Invalid
	SEP #$30
	RTS
