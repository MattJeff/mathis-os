; ═══════════════════════════════════════════════════════════════════════════
; PAGING.ASM - Setup PAE paging and transition to Long Mode
; ═══════════════════════════════════════════════════════════════════════════
; This code runs in 32-bit protected mode
; It sets up identity-mapped page tables and switches to 64-bit mode
; ═══════════════════════════════════════════════════════════════════════════

[BITS 32]

; Page table locations (must be page-aligned = 4KB aligned)
; Using memory at 0x70000-0x74000 (safe area)
PML4_ADDR   equ 0x70000     ; Page Map Level 4 (top level)
PDPT_ADDR   equ 0x71000     ; Page Directory Pointer Table
PD_ADDR     equ 0x72000     ; Page Directory
PT_ADDR     equ 0x73000     ; Page Table (not used with 2MB pages)

KERNEL64_ADDR equ 0x200000  ; Where kernel64.bin is loaded

; ═══════════════════════════════════════════════════════════════════════════
; ENTER_LONG_MODE - Main entry point called from shell.asm
; ═══════════════════════════════════════════════════════════════════════════
enter_long_mode:
    ; Disable interrupts
    cli

    ; Print debug: 'P' for Paging setup
    mov byte [0xB8000], 'P'
    mov byte [0xB8001], 0x0E

    ; ═══════════════════════════════════════════════════════════════════
    ; Step 1: Clear page table memory (16KB)
    ; ═══════════════════════════════════════════════════════════════════
    mov edi, PML4_ADDR
    xor eax, eax
    mov ecx, 4096           ; 16KB / 4 = 4096 dwords
    rep stosd

    ; Print debug: 'A' for Allocated
    mov byte [0xB8002], 'A'
    mov byte [0xB8003], 0x0E

    ; ═══════════════════════════════════════════════════════════════════
    ; Step 2: Set up identity mapping (first 4MB using 2MB pages)
    ; ═══════════════════════════════════════════════════════════════════

    ; PML4[0] -> PDPT
    mov dword [PML4_ADDR], PDPT_ADDR | 0x03     ; Present + Writable
    mov dword [PML4_ADDR + 4], 0                ; High 32 bits = 0

    ; PDPT[0] -> PD
    mov dword [PDPT_ADDR], PD_ADDR | 0x03       ; Present + Writable
    mov dword [PDPT_ADDR + 4], 0

    ; PD[0] -> 2MB page at 0x000000 (first 2MB identity mapped)
    mov dword [PD_ADDR], 0x000000 | 0x83        ; Present + Writable + PageSize(2MB)
    mov dword [PD_ADDR + 4], 0

    ; PD[1] -> 2MB page at 0x200000 (kernel64 area, 2-4MB identity mapped)
    mov dword [PD_ADDR + 8], 0x200000 | 0x83    ; Present + Writable + PageSize(2MB)
    mov dword [PD_ADDR + 12], 0

    ; Print debug: 'G' for paGes set up
    mov byte [0xB8004], 'G'
    mov byte [0xB8005], 0x0E

    ; ═══════════════════════════════════════════════════════════════════
    ; Step 3: Enable PAE (Physical Address Extension)
    ; ═══════════════════════════════════════════════════════════════════
    mov eax, cr4
    or eax, (1 << 5)        ; Set PAE bit (bit 5)
    mov cr4, eax

    ; Print debug: 'E' for PAE Enabled
    mov byte [0xB8006], 'E'
    mov byte [0xB8007], 0x0E

    ; ═══════════════════════════════════════════════════════════════════
    ; Step 4: Load PML4 address into CR3
    ; ═══════════════════════════════════════════════════════════════════
    mov eax, PML4_ADDR
    mov cr3, eax

    ; ═══════════════════════════════════════════════════════════════════
    ; Step 5: Enable Long Mode via EFER MSR
    ; ═══════════════════════════════════════════════════════════════════
    mov ecx, 0xC0000080     ; EFER MSR
    rdmsr
    or eax, (1 << 8)        ; Set LME (Long Mode Enable) bit
    wrmsr

    ; Print debug: 'L' for Long mode enabled
    mov byte [0xB8008], 'L'
    mov byte [0xB8009], 0x0E

    ; ═══════════════════════════════════════════════════════════════════
    ; Step 6: Enable paging (activates Long Mode)
    ; ═══════════════════════════════════════════════════════════════════
    mov eax, cr0
    or eax, (1 << 31)       ; Set PG (Paging) bit
    mov cr0, eax

    ; Print debug: '!' for Paging enabled
    mov byte [0xB800A], '!'
    mov byte [0xB800B], 0x0A

    ; ═══════════════════════════════════════════════════════════════════
    ; Step 7: Load 64-bit GDT and far jump to 64-bit code
    ; ═══════════════════════════════════════════════════════════════════
    lgdt [gdt64_ptr]

    ; Far jump to 64-bit code segment
    jmp 0x08:long_mode_entry

; ═══════════════════════════════════════════════════════════════════════════
; 64-BIT CODE - Trampoline to kernel64
; ═══════════════════════════════════════════════════════════════════════════
[BITS 64]

long_mode_entry:
    ; Set up 64-bit segment registers
    mov ax, 0x10            ; Data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Set up 64-bit stack
    mov rsp, 0x9F000

    ; Jump to kernel64 entry point
    mov rax, KERNEL64_ADDR
    jmp rax

; ═══════════════════════════════════════════════════════════════════════════
; 64-BIT GDT (Global Descriptor Table for Long Mode)
; ═══════════════════════════════════════════════════════════════════════════
align 16
gdt64:
    ; Null descriptor (required)
    dq 0

    ; Code segment (selector 0x08)
    ; Base=0, Limit=0 (ignored in 64-bit), L=1 (Long mode), P=1, DPL=0
    dw 0xFFFF               ; Limit low (ignored)
    dw 0x0000               ; Base low
    db 0x00                 ; Base middle
    db 0x9A                 ; Access: Present, Ring 0, Code, Execute/Read
    db 0xAF                 ; Flags: G=1, L=1 (64-bit), Limit high
    db 0x00                 ; Base high

    ; Data segment (selector 0x10)
    dw 0xFFFF               ; Limit low (ignored)
    dw 0x0000               ; Base low
    db 0x00                 ; Base middle
    db 0x92                 ; Access: Present, Ring 0, Data, Read/Write
    db 0xCF                 ; Flags: G=1, D=1 (32-bit operand size for data)
    db 0x00                 ; Base high
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1    ; GDT limit
    dq gdt64                     ; GDT base (64-bit address)

; ═══════════════════════════════════════════════════════════════════════════
; IMPORTANT: Restore 32-bit mode for any code that follows (data.asm)
; ═══════════════════════════════════════════════════════════════════════════
[BITS 32]
