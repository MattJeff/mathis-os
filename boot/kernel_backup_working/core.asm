; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - CORE MODULE
; Entry point, PIC, IDT - POSITION FIXE
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
    ; INITIALIZE PAGING via external memory module at 0x80000
    ; Tables are built but paging NOT enabled yet (for stability)
    ; ══════════════════════════════════════════════════════════════════
    ; call memory_init    ; DISABLED - testing if module loads correctly
    ; Note: To enable 64-bit, uncomment: call memory_enable_64bit
    
    ; ══════════════════════════════════════════════════════════════════
    ; PATCH IDT - Résout l'adresse de keyboard_isr dynamiquement
    ; Ceci permet à keyboard.asm de grandir sans casser le système
    ; ══════════════════════════════════════════════════════════════════
    mov eax, keyboard_isr           ; NASM calcule l'adresse réelle
    mov word [idt + 0x21*8], ax     ; Bits 0-15 de l'adresse
    shr eax, 16
    mov word [idt + 0x21*8 + 6], ax ; Bits 16-31 de l'adresse
    
    ; Load IDT (maintenant avec la bonne adresse)
    lidt [idt_ptr]
    
    ; Clear screen first
    mov edi, 0xB8000
    mov ecx, 2000
    mov eax, 0x0720
    rep stosd
    
    ; Display full banner
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
    
    ; Enable interrupts for keyboard
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
; SERIAL PORT (placeholder)
; ════════════════════════════════════════════════════════════════════════════
serial_init:
    ret

; ════════════════════════════════════════════════════════════════════════════
; MEMORY MODULE WRAPPERS - DISABLED (external module not loaded)
; ════════════════════════════════════════════════════════════════════════════
; MEMORY_MODULE       equ 0x80000
; 
; memory_init:
;     ; Call init_paging at 0x80000+0x00
;     call MEMORY_MODULE
;     ret
; 
; memory_enable_64bit:
;     ; Call enable_long_mode at 0x80000+0x05
;     call MEMORY_MODULE + 0x05
;     ret
; 
; memory_alloc_page:
;     ; Call alloc_page at 0x80000+0x0A
;     call MEMORY_MODULE + 0x0A
;     ret
; 
; memory_parse_e820:
;     ; Call parse_e820_map at 0x80000+0x0F
;     call MEMORY_MODULE + 0x0F
;     ret
; 
; memory_get_info:
;     ; Call get_memory_info at 0x80000+0x14
;     ; Returns: EAX=total memory, EBX=usable memory
;     call MEMORY_MODULE + 0x14
;     ret

; ════════════════════════════════════════════════════════════════════════════
; RADICAL RESTRUCTURE: VGA FIRST, then keyboard
; IDT is patched dynamically, so keyboard_isr can be ANYWHERE
; ════════════════════════════════════════════════════════════════════════════
%include "vga.asm"

; Keyboard can now grow freely - IDT patching handles the address
%include "keyboard.asm"
%include "shell.asm"
%include "vm.asm"
%include "fs.asm"
%include "parser.asm"

; ════════════════════════════════════════════════════════════════════════════
; MEMORY MANAGER - Paging, 64-bit preparation
; DISABLED - Causes address disruption
; ════════════════════════════════════════════════════════════════════════════
; %include "memory.asm"

%include "data.asm"
