; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - CORE MODULE v3.2
; ════════════════════════════════════════════════════════════════════════════
; NOUVELLE ARCHITECTURE:
;   1. CODE: Tout le code exécutable d'abord
;   2. DATA: Toutes les données à la fin (data_all.asm)
;
; Règle: On peut ajouter du code ou des données sans casser les adresses
; ════════════════════════════════════════════════════════════════════════════

[BITS 32]
[ORG 0x10000]

; ════════════════════════════════════════════════════════════════════════════
; ENTRY POINT
; ════════════════════════════════════════════════════════════════════════════

kernel_entry:
    mov esp, 0x2FFFF

    ; Copy embedded bytecode to 0x20000
    mov esi, embedded_program
    mov edi, 0x20000
    mov ecx, embedded_program_end - embedded_program
    rep movsb

    ; Initialize PIC
    mov al, 0x11
    out 0x20, al
    out 0xA0, al
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al
    mov al, 0x01
    out 0x21, al
    out 0xA1, al
    mov al, 0xFD            ; Enable keyboard only
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al

    ; ══════════════════════════════════════════════════════════════════
    ; PATCH IDT - Résout l'adresse de keyboard_isr dynamiquement
    ; ══════════════════════════════════════════════════════════════════
    mov eax, keyboard_isr           ; NASM calcule l'adresse réelle
    mov word [idt + 0x21*8], ax     ; Bits 0-15 de l'adresse
    shr eax, 16
    mov word [idt + 0x21*8 + 6], ax ; Bits 16-31 de l'adresse

    ; Load IDT
    lidt [idt_ptr]

    ; Clear screen
    mov edi, 0xB8000
    mov ecx, 2000
    mov eax, 0x0720
    rep stosd

    ; Display banner
    mov esi, banner_line1
    mov edi, 0xB8000
    mov ah, 0x0A
    call print_string

    mov esi, banner_line2
    mov edi, 0xB80A0
    call print_string

    mov esi, banner_line3
    mov edi, 0xB8140
    call print_string

    mov esi, banner_line4
    mov edi, 0xB81E0
    call print_string

    mov esi, banner_line5
    mov edi, 0xB8280
    call print_string

    mov esi, banner_line6
    mov edi, 0xB8320
    call print_string

    ; Info message
    mov esi, msg_info
    mov edi, 0xB8460
    mov ah, 0x07
    call print_string

    ; Prompt
    mov esi, msg_prompt
    mov edi, 0xB8550
    mov ah, 0x0A
    call print_string

    ; Initialize shell state
    mov dword [cursor_offset], 4
    mov dword [cmd_length], 0
    mov dword [prompt_line], 9

    ; Enable interrupts
    sti

.halt:
    hlt
    jmp .halt

; ════════════════════════════════════════════════════════════════════════════
; PRINT STRING - ESI=string, EDI=VGA offset, AH=color
; ════════════════════════════════════════════════════════════════════════════
print_string:
    lodsb
    test al, al
    jz .done
    stosw
    jmp print_string
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; SECTION CODE - Tous les modules de code
; ════════════════════════════════════════════════════════════════════════════

%include "vga.asm"
%include "keyboard_code.asm"
%include "shell.asm"
%include "vm.asm"
%include "fs.asm"
%include "parser.asm"

; ════════════════════════════════════════════════════════════════════════════
; SECTION DATA - Toutes les données (strings, variables, tables, IDT)
; ════════════════════════════════════════════════════════════════════════════

%include "data_all.asm"

; ════════════════════════════════════════════════════════════════════════════
; PADDING TO 64KB
; ════════════════════════════════════════════════════════════════════════════
times 0x10000 - ($ - $$) db 0
