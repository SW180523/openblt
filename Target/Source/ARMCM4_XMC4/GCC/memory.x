OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(Reset_Handler)

stack_size = DEFINED(stack_size) ? stack_size : 2048;
no_init_size = 64;

MEMORY
{
    FLASH_1_cached(RX) : ORIGIN = 0x08000000, LENGTH = 0x00008000
    FLASH_1_uncached(RX) : ORIGIN = 0x0C000000, LENGTH = 0x00008000
    PSRAM_1(!RX) : ORIGIN = 0x1FFE8000, LENGTH = 0x18000
    DSRAM_1_system(!RX) : ORIGIN = 0x20000000, LENGTH = 0x20000
    DSRAM_2_comm(!RX) : ORIGIN = 0x20020000, LENGTH = 0x20000
    SRAM_combined(!RX) : ORIGIN = 0x1FFE8000, LENGTH = 0x00058000
}

SECTIONS
{
    /* TEXT section */

    .text :
    {
        sText = .;
        KEEP(*(.reset));
        *(.text .text.* .gnu.linkonce.t.*);

        /* C++ Support */
        KEEP(*(.init))
        KEEP(*(.fini))

        /* .ctors */
        *crtbegin.o(.ctors)
        *crtbegin?.o(.ctors)
        *(EXCLUDE_FILE(*crtend?.o *crtend.o) .ctors)
        *(SORT(.ctors.*))
        *(.ctors)

        /* .dtors */
        *crtbegin.o(.dtors)
        *crtbegin?.o(.dtors)
        *(EXCLUDE_FILE(*crtend?.o *crtend.o) .dtors)
        *(SORT(.dtors.*))
        *(.dtors)

        *(.rodata .rodata.*)
        *(.gnu.linkonce.r*)
        
        *(vtable)        
        . = ALIGN(4);        
    } > FLASH_1_cached AT > FLASH_1_uncached

    .eh_frame_hdr : ALIGN (4)
    {
      KEEP (*(.eh_frame_hdr))
    } > FLASH_1_cached AT > FLASH_1_uncached
  
    .eh_frame : ALIGN (4)
    {
      KEEP (*(.eh_frame))
    } > FLASH_1_cached AT > FLASH_1_uncached

    /* Exception handling, exidx needs a dedicated section */
    .ARM.extab : ALIGN(4)
    {
        *(.ARM.extab* .gnu.linkonce.armextab.*)
    } > FLASH_1_cached AT > FLASH_1_uncached

    . = ALIGN(4);
    __exidx_start = .;
    .ARM.exidx : ALIGN(4)
    {
        *(.ARM.exidx* .gnu.linkonce.armexidx.*)
    } > FLASH_1_cached AT > FLASH_1_uncached
    __exidx_end = .;
    . = ALIGN(4);
    
    /* DSRAM layout (Lowest to highest)*/
    Stack (NOLOAD) : 
    {
        __stack_start = .;
        . = . + stack_size;
        __stack_end = .;
        __initial_sp = .;
    } > SRAM_combined

    /* functions with __attribute__((section(".ram_code"))) */
    .ram_code :
    {
        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        __ram_code_start = .;
        *(.ram_code)
        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        __ram_code_end = .;
    } > SRAM_combined AT > FLASH_1_uncached
    __ram_code_load = LOADADDR (.ram_code);
    __ram_code_size = __ram_code_end - __ram_code_start;

    /* Standard DATA and user defined DATA/BSS/CONST sections */
    .data :
    {
        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        __data_start = .;
        * (.data);
        * (.data*);
        *(*.data);
        *(.gnu.linkonce.d*)
      
        . = ALIGN(4);
        /* preinit data */
        PROVIDE_HIDDEN (__preinit_array_start = .);
        KEEP(*(.preinit_array))
        PROVIDE_HIDDEN (__preinit_array_end = .);

        . = ALIGN(4);
        /* init data */
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array))
        PROVIDE_HIDDEN (__init_array_end = .);

        . = ALIGN(4);
        /* finit data */
        PROVIDE_HIDDEN (__fini_array_start = .);
        KEEP(*(SORT(.fini_array.*)))
        KEEP(*(.fini_array))
        PROVIDE_HIDDEN (__fini_array_end = .);

        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        __data_end = .;
    } > SRAM_combined AT > FLASH_1_uncached
    __data_load = LOADADDR (.data);
    __data_size = __data_end - __data_start;
        
    __text_size = (__exidx_end - sText) + __data_size + __ram_code_size;
    eText = sText + __text_size;

    /* BSS section */
    .bss (NOLOAD) : 
    {
        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        __bss_start = .;
        * (.bss);
        * (.bss*);
        * (COMMON);
        *(.gnu.linkonce.b*)
        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        __bss_end = .;
    } > SRAM_combined
    __bss_size = __bss_end - __bss_start;

    /* Shift location counter, so that ETH_RAM and USB_RAM are located above DSRAM_1_system */    
    __shift_loc =  (__bss_end >= ORIGIN(DSRAM_1_system)) ? 0 : (ORIGIN(DSRAM_1_system) - __bss_end);

    USB_RAM  (__bss_end + __shift_loc) (NOLOAD) :
    {
        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        USB_RAM_start = .;
        *(USB_RAM)
        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        USB_RAM_end = .;
    } > SRAM_combined
    USB_RAM_size = USB_RAM_end - USB_RAM_start;

    ETH_RAM (USB_RAM_end) (NOLOAD) :
    {
        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        ETH_RAM_start = .;
        *(ETH_RAM)
        . = ALIGN(4); /* section size must be multiply of 4. See startup.S file */
        ETH_RAM_end = .;
        . = ALIGN(8);
        Heap_Bank1_Start = .;
    } > SRAM_combined
    ETH_RAM_size = ETH_RAM_end - ETH_RAM_start;

    /* .no_init section contains chipid, SystemCoreClock and trimming data. See system.c file*/
    .no_init ORIGIN(SRAM_combined) + LENGTH(SRAM_combined) - no_init_size (NOLOAD) : 
    {
        Heap_Bank1_End = .;
        * (.no_init);
    } > SRAM_combined

    /* Heap - Bank1*/
    Heap_Bank1_Size  = Heap_Bank1_End - Heap_Bank1_Start;

    ASSERT(Heap_Bank1_Start <= Heap_Bank1_End, "region SRAM_combined overflowed no_init section")

    /DISCARD/ :
    {
        *(.comment)
    }

    .stab       0 (NOLOAD) : { *(.stab) }
    .stabstr    0 (NOLOAD) : { *(.stabstr) }

    /* DWARF 1 */
    .debug              0 : { *(.debug) }
    .line               0 : { *(.line) }

    /* GNU DWARF 1 extensions */
    .debug_srcinfo      0 : { *(.debug_srcinfo) }
    .debug_sfnames      0 : { *(.debug_sfnames) }

    /* DWARF 1.1 and DWARF 2 */
    .debug_aranges      0 : { *(.debug_aranges) }
    .debug_pubnames     0 : { *(.debug_pubnames) }
    .debug_pubtypes     0 : { *(.debug_pubtypes) }

    /* DWARF 2 */
    .debug_info         0 : { *(.debug_info .gnu.linkonce.wi.*) }
    .debug_abbrev       0 : { *(.debug_abbrev) }
    .debug_line         0 : { *(.debug_line) }
    .debug_frame        0 : { *(.debug_frame) }
    .debug_str          0 : { *(.debug_str) }
    .debug_loc          0 : { *(.debug_loc) }
    .debug_macinfo      0 : { *(.debug_macinfo) }

    /* DWARF 2.1 */
    .debug_ranges       0 : { *(.debug_ranges) }

    /* SGI/MIPS DWARF 2 extensions */
    .debug_weaknames    0 : { *(.debug_weaknames) }
    .debug_funcnames    0 : { *(.debug_funcnames) }
    .debug_typenames    0 : { *(.debug_typenames) }
    .debug_varnames     0 : { *(.debug_varnames) }

    /* Build attributes */
    .build_attributes   0 : { *(.ARM.attributes) }
}
