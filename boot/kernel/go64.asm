; ════════════════════════════════════════════════════════════════════════════
; GO64.ASM - Trampoline vers kernel 64-bit
; ════════════════════════════════════════════════════════════════════════════
; Ce fichier est inclus EN DERNIER avant data_all.asm
; Modifier ce fichier ne décale pas keyboard_code.asm
; ════════════════════════════════════════════════════════════════════════════

do_go64:
    mov byte [0xB8000], '6'
    mov byte [0xB8001], 0x4E
    mov byte [0xB8002], '4'
    mov byte [0xB8003], 0x4E

    ; STEP 1: Clear page tables at 0x1000
    mov edi, 0x1000
    mov ecx, 3072
    xor eax, eax
    rep stosd

    ; Setup page tables (8-byte entries for 64-bit mode)
    ; PML4[0] -> PDPT at 0x2000
    mov dword [0x1000], 0x2003
    mov dword [0x1004], 0x0
    ; PDPT[0] -> PD at 0x3000
    mov dword [0x2000], 0x3003
    mov dword [0x2004], 0x0
    ; PD[0] -> 2MB page at 0 (Present + RW + PS)
    mov dword [0x3000], 0x00000083
    mov dword [0x3004], 0x0

    mov byte [0xB8004], 'P'
    mov byte [0xB8005], 0x0A

    ; STEP 2: Enable PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    mov byte [0xB8006], 'A'
    mov byte [0xB8007], 0x0A

    ; STEP 3: Load CR3
    mov eax, 0x1000
    mov cr3, eax

    mov byte [0xB8008], '3'
    mov byte [0xB8009], 0x0A

    ; STEP 4: Enable Long Mode in EFER
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    mov byte [0xB800A], 'L'
    mov byte [0xB800B], 0x0A

    ; Load 64-bit GDT
    lgdt [gdt64_ptr]

    mov byte [0xB800C], 'G'
    mov byte [0xB800D], 0x0A

    ; STEP 6: Enable Paging (this crashes)
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; If we get here, it worked
    mov byte [0xB800E], '!'
    mov byte [0xB800F], 0x0E

    cli
    hlt

; ══════════════════════════════════════════════════════════════════
; GDT 64-bit
; ══════════════════════════════════════════════════════════════════
align 16
gdt64:
    dq 0                         ; Null descriptor
gdt64_code:
    dq 0x00209A0000000000        ; 64-bit code segment
gdt64_data:
    dq 0x0000920000000000        ; 64-bit data segment
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64
