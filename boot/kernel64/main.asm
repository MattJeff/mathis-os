; ════════════════════════════════════════════════════════════════════════════
; KERNEL64 - Entry point pour transition 32-bit → 64-bit
; ════════════════════════════════════════════════════════════════════════════
; Ce code est chargé à 0x200000 par stage2
; Il reçoit le contrôle en 32-bit et passe en 64-bit
; ════════════════════════════════════════════════════════════════════════════

[BITS 32]
[ORG 0x200000]

; ════════════════════════════════════════════════════════════════════════════
; ENTRY POINT (appelé depuis kernel 32-bit)
; ════════════════════════════════════════════════════════════════════════════

kernel64_entry:
    cli

    ; Debug: afficher '1'
    mov byte [0xB8000], '1'
    mov byte [0xB8001], 0x0E

    ; ══════════════════════════════════════════════════════════════════
    ; Étape 1: Effacer les page tables à 0x70000
    ; ══════════════════════════════════════════════════════════════════
    mov edi, 0x70000
    xor eax, eax
    mov ecx, 4096           ; 16KB
    rep stosd

    ; Debug: '2'
    mov byte [0xB8002], '2'
    mov byte [0xB8003], 0x0E

    ; ══════════════════════════════════════════════════════════════════
    ; Étape 2: Identity mapping premiers 4MB
    ; ══════════════════════════════════════════════════════════════════

    ; PML4[0] -> PDPT
    mov dword [0x70000], 0x71003

    ; PDPT[0] -> PD
    mov dword [0x71000], 0x72003

    ; PD[0] -> 2MB page at 0 (pour VGA, code actuel)
    mov dword [0x72000], 0x000083

    ; PD[1] -> 2MB page at 0x200000 (kernel64)
    mov dword [0x72008], 0x200083

    ; Debug: '3'
    mov byte [0xB8004], '3'
    mov byte [0xB8005], 0x0E

    ; ══════════════════════════════════════════════════════════════════
    ; Étape 3: Activer PAE (CR4.PAE = 1)
    ; ══════════════════════════════════════════════════════════════════
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; ══════════════════════════════════════════════════════════════════
    ; Étape 4: Charger PML4 dans CR3
    ; ══════════════════════════════════════════════════════════════════
    mov eax, 0x70000
    mov cr3, eax

    ; Debug: '4'
    mov byte [0xB8006], '4'
    mov byte [0xB8007], 0x0E

    ; ══════════════════════════════════════════════════════════════════
    ; Étape 5: Activer Long Mode (EFER.LME = 1)
    ; ══════════════════════════════════════════════════════════════════
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; ══════════════════════════════════════════════════════════════════
    ; Étape 6: Activer Paging (CR0.PG = 1)
    ; ══════════════════════════════════════════════════════════════════
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; Debug: '5'
    mov byte [0xB8008], '5'
    mov byte [0xB8009], 0x0A

    ; ══════════════════════════════════════════════════════════════════
    ; Étape 7: Jump to 64-bit code
    ; ══════════════════════════════════════════════════════════════════
    lgdt [gdt64_ptr]
    jmp 0x08:long_mode_start

; ════════════════════════════════════════════════════════════════════════════
; CODE 64-BIT
; ════════════════════════════════════════════════════════════════════════════
[BITS 64]

long_mode_start:
    ; Setup segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x9F000

    ; Clear screen
    mov rdi, 0xB8000
    mov rax, 0x0F200F200F200F20
    mov rcx, 500
    rep stosq

    ; Afficher message
    mov rdi, 0xB8000
    mov rsi, msg_welcome
    mov ah, 0x0A
.print:
    lodsb
    test al, al
    jz .done
    stosw
    jmp .print
.done:

    ; Afficher "64-bit mode active!"
    mov rdi, 0xB80A0
    mov rsi, msg_64bit
    mov ah, 0x0E
.print2:
    lodsb
    test al, al
    jz .halt
    stosw
    jmp .print2

.halt:
    hlt
    jmp .halt

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
msg_welcome: db "=== MathisOS 64-BIT KERNEL ===", 0
msg_64bit:   db "Long Mode active! CPU running in 64-bit.", 0

; ════════════════════════════════════════════════════════════════════════════
; GDT 64-BIT
; ════════════════════════════════════════════════════════════════════════════
align 16
gdt64:
    dq 0                        ; Null
    dq 0x00AF9A000000FFFF       ; Code 64-bit (selector 0x08)
    dq 0x00CF92000000FFFF       ; Data (selector 0x10)
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64

; Padding to 4KB
times 4096 - ($ - $$) db 0
