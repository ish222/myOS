ENTRY(start)

SECTIONS /* Define individual sections of the binary */
{
	. = 1M; /* Set current address to 1 MB. This means all OS data will start 1 Mb in (convention) */

	.boot : /* Boot section */
	{
		KEEP(*(.multiboot_header))
	}

	.text : /* All CPU instructions */
	{
		*(.text)
	}
}