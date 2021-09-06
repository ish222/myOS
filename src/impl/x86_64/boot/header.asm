; This contains data to be included in the OS binary
; This data is necessary so that boot loaders can recognise the OS
; This follows the multiboot2 specification

section .multiboot_header
header_start: 
	; magic number
	dd 0xe85250d6 ; multiboot2
	; architecture
	dd 0 ; protected mode i386
	; header length
	dd header_end - header_start
	; checksum
	dd 0x100000000 - (0xe85250d6 + 0 + (header_end - header_start))

	; end tag
	dw 0
	dw 0
	dd 8
header_end: