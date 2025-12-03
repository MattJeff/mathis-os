; ════════════════════════════════════════════════════════════════════════════
; PAGING_CODE.ASM - Transition vers Long Mode (64-bit)
; ════════════════════════════════════════════════════════════════════════════
; TOUT en 32-bit sauf le petit trampoline final
; ════════════════════════════════════════════════════════════════════════════

[BITS 32]

; Adresses des page tables (zone libre à 0x70000)
PML4_ADDR   equ 0x70000
PDPT_ADDR   equ 0x71000
PD_ADDR     equ 0x72000

; Adresse du kernel 64-bit
KERNEL64_ADDR equ 0x200000

; ════════════════════════════════════════════════════════════════════════════
; ENTER_LONG_MODE - Point d'entrée (32-bit)
; ════════════════════════════════════════════════════════════════════════════
enter_long_mode:
    cli

    ; Étape 1: Effacer les page tables
    mov edi, PML4_ADDR
    xor eax, eax
    mov ecx, 3072
    rep stosd

    ; Étape 2: Identity mapping
    mov dword [PML4_ADDR], PDPT_ADDR | 0x03
    mov dword [PML4_ADDR + 4], 0
    mov dword [PDPT_ADDR], PD_ADDR | 0x03
    mov dword [PDPT_ADDR + 4], 0
    mov dword [PD_ADDR], 0x000000 | 0x83
    mov dword [PD_ADDR + 4], 0
    mov dword [PD_ADDR + 8], 0x200000 | 0x83
    mov dword [PD_ADDR + 12], 0

    ; Étape 3: Activer PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; Étape 4: Charger CR3
    mov eax, PML4_ADDR
    mov cr3, eax

    ; Étape 5: Activer Long Mode (EFER.LME)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; Étape 6: Activer paging
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; Étape 7: Charger GDT 64-bit et jump
    lgdt [gdt64_ptr]
    jmp 0x08:trampoline_64

; ════════════════════════════════════════════════════════════════════════════
; TRAMPOLINE 64-BIT (très court, juste le saut)
; ════════════════════════════════════════════════════════════════════════════
[BITS 64]
trampoline_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov rsp, 0x9F000
    mov rax, KERNEL64_ADDR
    jmp rax

; ════════════════════════════════════════════════════════════════════════════
; RETOUR EN 32-BIT IMMÉDIAT
; ════════════════════════════════════════════════════════════════════════════
[BITS 32]

; ════════════════════════════════════════════════════════════════════════════
; GDT 64-BIT (données, pas de code)
; ════════════════════════════════════════════════════════════════════════════
align 16
gdt64:
    dq 0
    dq 0x00AF9A000000FFFF  ; Code 64-bit
    dq 0x00CF92000000FFFF  ; Data
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64
