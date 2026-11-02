/*
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.
*/

ENTRY(_start)

MEMORY {
    rom : ORIGIN = 0x00000000, LENGTH = 0xFF00   /* 65280 bytes for code */
    vec : ORIGIN = 0x0000FF00, LENGTH = 0x0100   /* 256 bytes for vectors */
}

SECTIONS {
    .irq_mem 0xFF00 : {
        KEEP(*(.irq_vector))
    } > vec                        /* isolated region, can never overlap */

    .memory : {
        . = 0x000000;
        testall*(.text);
        *(.text);
        end = .;
        . = ALIGN(4);
    } > rom                        /* linker errors if rom is full */

}

