; ============================================================================
; CORE_ENTRY.ASM - Kernel Entry Point (Modular Architecture)
; ============================================================================
; Main entry point: 32-bit protected mode -> 64-bit long mode
; This module initializes the kernel and calls all subsystem inits
; ============================================================================

[BITS 32]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
MULTIBOOT_MAGIC         equ 0x2BADB002
VIDEO_INFO_FB           equ 0x500
VIDEO_INFO_W            equ 0x504
VIDEO_INFO_H            equ 0x508
VIDEO_INFO_VESA         equ 0x50C
VIDEO_INFO_PITCH        equ 0x510
VIDEO_INFO_BPP          equ 0x514

; ============================================================================
; IMPORTS (extern) - Functions from other modules
; ============================================================================
extern setup_idt64
extern setup_tss64
extern setup_pic64
extern setup_pit64
extern heap_init
extern video_init
extern video_flip
extern desktop_init
extern desktop_draw
extern key_pressed
extern wm_on_key

; ============================================================================
; EXPORTS (global) - Symbols visible to other modules
; ============================================================================
global kernel_entry
global long_mode_entry

; Data exports (defined in .data section below)
global screen_fb
global screen_width
global screen_height
global screen_pitch
global screen_bpp
global screen_centerx
global screen_centery
global tick_count

; ============================================================================
; ENTRY SECTION - Must start at exactly 0x10000
; ============================================================================
section .entry exec progbits alloc

kernel_entry:
    ; First instruction at 0x10000 - jump over multiboot header
    jmp short past_multiboot
    nop

; ============================================================================
; MULTIBOOT HEADER (within first 8KB for GRUB compatibility)
; ============================================================================
MULTIBOOT_HEADER_MAGIC  equ 0x1BADB002
MULTIBOOT_PAGE_ALIGN    equ 1 << 0
MULTIBOOT_MEMORY_INFO   equ 1 << 1
MULTIBOOT_FLAGS         equ MULTIBOOT_PAGE_ALIGN | MULTIBOOT_MEMORY_INFO
MULTIBOOT_CHECKSUM      equ -(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_FLAGS)

align 4
multiboot_header:
    dd MULTIBOOT_HEADER_MAGIC
    dd MULTIBOOT_FLAGS
    dd MULTIBOOT_CHECKSUM

past_multiboot:
    mov esp, 0x2FFFF

    ; Check for multiboot vs legacy boot
    cmp eax, MULTIBOOT_MAGIC
    jne .legacy_boot

    ; Multiboot: TODO parse info from EBX
    jmp .boot_continue

.legacy_boot:
    ; Legacy: Video info already at 0x500 from stage2

.boot_continue:
    ; Switch to 64-bit long mode
    jmp do_go64

; ============================================================================
; DO_GO64 - 32-bit to 64-bit transition
; ============================================================================
do_go64:
    cli

    ; Setup page tables at 0x1000
    ; Clear 5 pages: PML4, PDPT, PD0, PD3, spare
    mov edi, 0x1000
    mov ecx, 5120
    xor eax, eax
    rep stosd

    ; PML4[0] -> PDPT at 0x2000
    mov dword [0x1000], 0x2007

    ; PDPT[0] -> PD at 0x3000 (for 0-1GB)
    mov dword [0x2000], 0x3007

    ; PDPT[3] -> PD at 0x4000 (for 3-4GB, covers PCI MMIO)
    mov dword [0x2018], 0x4007

    ; PD0: Map first 32MB (heap needs 4-20MB)
    mov dword [0x3000], 0x00000087
    mov dword [0x3008], 0x00200087
    mov dword [0x3010], 0x00400087
    mov dword [0x3018], 0x00600087
    mov dword [0x3020], 0x00800087
    mov dword [0x3028], 0x00A00087
    mov dword [0x3030], 0x00C00087
    mov dword [0x3038], 0x00E00087
    mov dword [0x3040], 0x01000087
    mov dword [0x3048], 0x01200087
    mov dword [0x3050], 0x01400087
    mov dword [0x3058], 0x01600087
    mov dword [0x3060], 0x01800087
    mov dword [0x3068], 0x01A00087
    mov dword [0x3070], 0x01C00087
    mov dword [0x3078], 0x01E00087

    ; PD3: Map VESA LFB + PCI MMIO region 0xFD000000-0xFFFFFFFF
    mov edi, 0x4000 + (488 * 8)
    mov eax, 0xFD000087
    mov ecx, 24
.map_mmio:
    mov [edi], eax
    mov dword [edi+4], 0
    add edi, 8
    add eax, 0x200000
    loop .map_mmio

    ; Enable PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; Load CR3 with PML4 address
    mov eax, 0x1000
    mov cr3, eax

    ; Enable Long Mode in EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; Load 64-bit GDT
    lgdt [gdt64_ptr]

    ; Enable paging
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; Far jump to 64-bit code
    jmp 0x08:long_mode_entry

; ============================================================================
; 64-BIT GDT
; ============================================================================
align 16
gdt64:
    dq 0x0000000000000000       ; Null descriptor
    dq 0x00AF9A000000FFFF       ; 64-bit code segment
    dq 0x00AF92000000FFFF       ; 64-bit data segment
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dq gdt64

; ============================================================================
; 64-BIT LONG MODE ENTRY
; ============================================================================
[BITS 64]
long_mode_entry:
    ; Setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000

    ; Read video info from stage2 at 0x500
    mov eax, [VIDEO_INFO_FB]
    mov qword [screen_fb], rax      ; Zero-extend to 64-bit
    mov eax, [VIDEO_INFO_W]
    mov [screen_width], eax
    mov eax, [VIDEO_INFO_H]
    mov [screen_height], eax
    mov eax, [VIDEO_INFO_PITCH]
    mov [screen_pitch], eax
    mov eax, [VIDEO_INFO_BPP]
    mov [screen_bpp], eax

    ; Calculate screen center
    mov eax, [screen_width]
    shr eax, 1
    mov [screen_centerx], eax
    mov eax, [screen_height]
    shr eax, 1
    mov [screen_centery], eax

    ; Initialize tick counter
    mov qword [tick_count], 0

    ; Clear screen with blue color (test)
    call clear_screen_blue

    ; Initialize interrupt system
    call setup_idt64
    call setup_tss64
    call setup_pic64
    call setup_pit64

    ; Initialize memory management
    call heap_init

    ; Initialize video double buffering
    call video_init

    ; Initialize desktop
    call desktop_init

    ; Enable interrupts
    sti

    ; Main loop
.main_loop:
    ; Process keyboard input
    movzx edi, byte [key_pressed]
    test edi, edi
    jz .no_key
    mov byte [key_pressed], 0           ; Clear key
    call wm_on_key
.no_key:

    ; Draw desktop
    call desktop_draw

    ; Flip back buffer to screen
    call video_flip

    ; Small delay (wait for vsync-ish)
    hlt

    jmp .main_loop

; ============================================================================
; CLEAR_SCREEN_BLUE - Test function to verify boot works
; ============================================================================
clear_screen_blue:
    push rax
    push rcx
    push rdi

    ; Get framebuffer address
    mov rdi, [screen_fb]            ; 64-bit load

    ; Calculate total pixels
    mov eax, [screen_width]
    mov ecx, [screen_height]
    imul ecx, eax

    ; Blue color (0x0000FF for 24-bit, 0xFF0000FF for 32-bit)
    mov eax, 0xFF0000FF         ; ARGB blue

.fill_loop:
    mov [rdi], eax
    add rdi, 4                  ; 32-bit per pixel
    dec rcx
    jnz .fill_loop

    pop rdi
    pop rcx
    pop rax
    ret

; ============================================================================
; DATA SECTION - Kernel global variables
; ============================================================================
section .data

; Screen/Video info
screen_fb:          dq 0            ; 64-bit for pointer
screen_width:       dd 0
screen_height:      dd 0
screen_pitch:       dd 0
screen_bpp:         dd 0
screen_centerx:     dd 0
screen_centery:     dd 0

; Timer
tick_count:         dq 0

; ============================================================================
; BSS SECTION - Uninitialized data
; ============================================================================
section .bss
