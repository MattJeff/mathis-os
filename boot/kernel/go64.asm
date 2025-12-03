; ════════════════════════════════════════════════════════════════════════════
; GO64.ASM - Transition 32-bit vers 64-bit Long Mode
; ════════════════════════════════════════════════════════════════════════════

do_go64:
    cli

    ; Setup page tables at 0x1000 (identity map first 2MB)
    ; PML4 at 0x1000, PDPT at 0x2000, PD at 0x3000
    mov edi, 0x1000
    mov ecx, 3072
    xor eax, eax
    rep stosd

    ; PML4[0] -> PDPT at 0x2000
    mov dword [0x1000], 0x2003
    mov dword [0x1004], 0x0
    ; PDPT[0] -> PD at 0x3000
    mov dword [0x2000], 0x3003
    mov dword [0x2004], 0x0
    ; PD[0] -> 2MB page at 0 (Present + RW + PS)
    mov dword [0x3000], 0x00000083
    mov dword [0x3004], 0x0

    ; Enable PAE in CR4
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

    ; Enable Paging (activates Long Mode)
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; Far jump to 64-bit code
    jmp 0x08:long_mode_entry

; ════════════════════════════════════════════════════════════════════════════
; 64-bit Long Mode Entry Point
; ════════════════════════════════════════════════════════════════════════════
[BITS 64]
long_mode_entry:
    ; Disable interrupts - no 64-bit IDT yet
    cli

    ; Setup 64-bit data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Clear screen and display 64-bit message
    mov rdi, 0xB8000
    mov rcx, 2000
    mov rax, 0x0F200F20
    rep stosq

    ; Display line 1
    mov rdi, 0xB8000
    mov rsi, msg_line1
    mov ah, 0x0A
.print1:
    lodsb
    test al, al
    jz .line2
    mov [rdi], ax
    add rdi, 2
    jmp .print1

.line2:
    ; Display line 2
    mov rdi, 0xB8000 + 160
    mov rsi, msg_line2
    mov ah, 0x0E
.print2:
    lodsb
    test al, al
    jz .done
    mov [rdi], ax
    add rdi, 2
    jmp .print2

.done:
    hlt
    jmp .done

msg_line1: db "MATHIS OS - 64-bit Long Mode", 0
msg_line2: db "Type 'reboot' in 32-bit shell to return", 0

[BITS 32]

; ════════════════════════════════════════════════════════════════════════════
; GDT 64-bit
; ════════════════════════════════════════════════════════════════════════════
align 16
gdt64:
    dq 0                         ; Null descriptor
    dq 0x00209A0000000000        ; 0x08: 64-bit code segment
    dq 0x0000920000000000        ; 0x10: 64-bit data segment
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64
