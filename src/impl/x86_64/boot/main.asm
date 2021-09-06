; Entry point into the OS

global start ; needs to be accessed during linking

section .text ; code section of the binary
bits 32 ; 32 bit instructions (for the time being)
start:
	; print 'OK'
	mov dword [0xb8000], 0x2f4b2f4f ; Moves hex representing 'OK' into video memory location (0xb8000)
	hlt ; instructs CPU to freeze and not run further instructions