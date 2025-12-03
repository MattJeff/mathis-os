; ════════════════════════════════════════════════════════════════════════════
; GO64.ASM - Trampoline vers kernel 64-bit
; ════════════════════════════════════════════════════════════════════════════
; Ce fichier est inclus EN DERNIER avant data_all.asm
; Modifier ce fichier ne décale pas keyboard_code.asm
; ════════════════════════════════════════════════════════════════════════════

do_go64:
    ; Afficher '64' pour confirmer qu'on est dans go64
    mov byte [0xB8000], '6'
    mov byte [0xB8001], 0x4E
    mov byte [0xB8002], '4'
    mov byte [0xB8003], 0x4E

    ; ══════════════════════════════════════════════════════════════════
    ; STEP 1: Setup page tables at 0x70000
    ; ══════════════════════════════════════════════════════════════════

    ; Clear page table area (3 pages = 12KB)
    mov edi, 0x70000
    mov ecx, 0x3000 / 4
    xor eax, eax
    rep stosd

    ; PML4[0] -> PDPT at 0x71000
    mov dword [0x70000], 0x71003

    ; PDPT[0] -> PD at 0x72000
    mov dword [0x71000], 0x72003

    ; PD[0] -> 2MB page at 0x00000000
    mov dword [0x72000], 0x00000083

    mov byte [0xB8004], 'P'
    mov byte [0xB8005], 0x0A

    ; ══════════════════════════════════════════════════════════════════
    ; STEP 2: Enable PAE (CR4.PAE = 1)
    ; ══════════════════════════════════════════════════════════════════
    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax

    mov byte [0xB8006], 'A'
    mov byte [0xB8007], 0x0A

    ; ══════════════════════════════════════════════════════════════════
    ; STEP 3: Load PML4 address into CR3
    ; ══════════════════════════════════════════════════════════════════
    mov eax, 0x70000
    mov cr3, eax

    mov byte [0xB8008], '3'
    mov byte [0xB8009], 0x0A

    ; ══════════════════════════════════════════════════════════════════
    ; STEP 4: Enable Long Mode (EFER.LME = 1)
    ; ══════════════════════════════════════════════════════════════════
    mov ecx, 0xC0000080
    rdmsr
    or eax, (1 << 8)
    wrmsr

    mov byte [0xB800A], 'L'
    mov byte [0xB800B], 0x0A

    ; Debug: check if paging already ON
    mov eax, cr0
    test eax, (1 << 31)
    jz .paging_off
    mov byte [0xB800C], 'Y'    ; Paging already ON
    jmp .done_check
.paging_off:
    mov byte [0xB800C], 'N'    ; Paging OFF
.done_check:
    mov byte [0xB800D], 0x0E

    ; STOP HERE
    cli
    hlt
