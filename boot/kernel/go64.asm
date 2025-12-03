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

    ; STEP 1: Clear page tables
    mov edi, 0x70000
    mov ecx, 3072
    xor eax, eax
    rep stosd

    ; Setup page tables
    mov dword [0x70000], 0x71003
    mov dword [0x71000], 0x72003
    mov dword [0x72000], 0x00000083

    mov byte [0xB8004], 'P'
    mov byte [0xB8005], 0x0A

    ; STEP 2: Enable PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    mov byte [0xB8006], 'A'
    mov byte [0xB8007], 0x0A

    ; STEP 3: Load CR3
    mov eax, 0x70000
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

    cli
    hlt
