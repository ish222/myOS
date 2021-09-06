; Entry point into the OS

global start ; Needs to be accessed during linking
extern long_mode_start ; Label in a different file, main64.asm

section .text ; Code section of the binary
bits 32 ; 32 bit instructions (for the time being)
start:
	; CPU uses esp register to determine the address of the current stack frame (aka stack pointer)
	mov esp, stack_top ; Store the address of the top of the stack into this register

	call check_multiboot ; Function which confirms if OS is loaded by multiboot2 bootloader
	call check_cpuid ; Function which provides various CPU information
	call check_long_mode ; Function which checks if the CPU supports long mode (necessary for 64 bit operation)

	; A requirement of entering long mode is setting up paging
	; Paging allows us to map virtual memory addresses to physical ones
	call setup_page_tables
	call enable_paging

	lgdt [gdt64.pointer] ; Load the global descriptor table with the set up pointer
	jmp gdt64.code_segment:long_mode_start ; Load code segment into the code selector, jumping into some 64 bit assembly code

	hlt ; instructs CPU to freeze and not run further instructions

check_multiboot:
	cmp eax, 0x36d76289 ; Compliant bootloaders will store this value in the eax register so it's checked for
	jne .no_multiboot ; Jump-not-equal jumps to the specified section if the comparison fails
	ret ; Return from the sub-routine

.no_multiboot:
	mov al, "M" ; Error code for the error message (M = multiboot)
	jmp error ; Jump to instruction which displays error message

check_cpuid:
	; We need to flip the id bit of the flags register, if flipable, CPUID is available
	pushfd ; Push flags register onto the stack
	pop eax ; Pop off the stack into the eax register
	mov ecx, eax ; Copy into the ecx register to allow for comparison if the bit successfully flipped
	xor eax, 1 << 21 ; Flip ID bit which is bit 21
	push eax
	popfd
	pushfd
	pop eax
	push ecx
	popfd
	cmp eax, ecx
	je .no_cpuid ; If they match, CPUID is not available
	ret

.no_cpuid:
	mov al, "C" ; Error code C for CPUID
	jmp error

check_long_mode:
	; We first need to check if CPUID supports extended processor info
	mov eax, 0x80000000
	cpuid
	cmp eax, 0x80000001 ; The cpuid instruction takes the number above (eax register) and returns a larger value if the CPU supports extended processor info
	jb .no_long_mode ; If the returned values is smaller

	mov eax, 0x80000001
	cpuid ; This time cpuid takes this new value which will then store a value into the edx register
	test edx, 1 << 29 ; If the lm bit is set then long mode is available (lm bit is at bit 29)
	jz .no_long_mode

	ret

.no_long_mode:
	mov al, "L" ; Error code for no long mode support (L = long mode)
	jmp error

setup_page_tables:
	; Identity map the first GB of pages
	mov eax, page_table_l3
	; log2(4096) shows that the first 12 bits of every entry will be 0, CPU will instead use these bits to store flags
	or eax, 0b11 ; Enable present, writable flags (located in first and second bits and both are set to 1)
	mov [page_table_l4], eax
	
	mov eax, page_table_l2
	or eax, 0b11
	mov [page_table_l3], eax

	; We can enable the huge page flag on any entry in the level 2 page table, this allows us to point directly to physical memory and allocate
	; a huge page that is 2 MB in size. This means level 1 tables are not necessary. The spare 9 bits will be used as an offset into this huge page
	; rather than an index into a level 1 table.

	; Fill up all 512 entries of the level 2 table, each entry is 2 MB, total = 1 GB to be identity mapped
	mov ecx, 0 ; Counter for a for loop, initiated at 0

.loop:
	mov eax, 0x200000 ; 2 MiB to be mapped
	mul ecx ; Multiply eax by counter ecx will yield the result of the next page
	or eax, 0b10000011 ; present, writable, huge page
	mov [page_table_l2 + ecx * 8], eax ; Put entry into the level 2 table with an offset of the index of the entry multiplied by 8 bytes for each entry

	inc ecx ; Increment counted for each iteration
	cmp ecx, 512 ; Checks if the whole table is mapped
	jne .loop ; If not, continue the loop

	ret

enable_paging:
	; Pass page table location to CPU, CPU looks for this in the CR3 register
	mov eax, page_table_l4
	mov cr3, eax

	; Enable physical address extension (PAE), necessary for 64 bit paging
	mov eax, cr4
	or eax, 1 << 5 ; Enable PAE flag in CR4 register, which is the 5th bit 
	mov cr4, eax
	
	; Enable long mode, to do this we need to work with model specific registers
	mov ecx, 0XC0000080
	rdmsr ; Use the read model specific register instruction, which load the value of the efer register into the eax register
	or eax, 1 << 8 ; Enable long mode flag which is at bit 8
	wrmsr ; Write this back into the model specific register, the efer register

	; Enable paging
	mov eax, cr0 ; Enable paging flag in the cr0 register
	or eax, 1 << 31 ; Paging bit is bit 31
	mov cr0, eax

	ret

error:
	; Print "ERR: X" where X is the error code
	mov dword [0xb8000], 0x4f524f45
	mov dword [0xb8004], 0x4f3a4f52
	mov dword [0xb8008], 0x4f204f20
	mov byte  [0xb800a], al
	hlt

; This section contains statically allocated variables
section .bss
align 4096 ; Each page table is 4 KB so all tables need to be aligned to 4 KB
page_table_l4: ; Level 4 page table, 4 KB reserved
	resb 4096
page_table_l3:
	resb 4096
page_table_l2:
	resb 4096
stack_bottom:
	resb  4096 * 4 ; Resrve 16 KB of memory for the stack space
stack_top:

; To enter 64 bit mode fully, a global descriptor table is necessary even though its obselete as we're using paging
section .rodata
gdt64:
	dq 0 ; Zero entry
.code_segment: equ $ - gdt64 ; Offset inside the descriptor table
	dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) ; Code segment, we need enable the executable flag, set descriptor type to 1, enable the present and 64 bit flags
.pointer: ; Pointer to this global descriptor table, longer pointer which also holds two bytes of the length of the table
	dw $ - gdt64 - 1 ; Length of the table is the difference between $ (the current memory address) minus the start of the table (gdt64) - 1
	dq gdt64 ; Store the pointer itself using the label
