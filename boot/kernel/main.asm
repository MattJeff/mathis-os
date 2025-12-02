; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - Main Entry Point
; ════════════════════════════════════════════════════════════════════════════

[BITS 32]
[ORG 0x10000]

kernel_entry:
    ; Setup stack
    mov esp, 0x2FFFF
    
    ; Copy embedded bytecode to 0x20000
    mov esi, embedded_program
    mov edi, 0x20000
    mov ecx, embedded_program_end - embedded_program
    rep movsb
    
    ; Initialize PIC
    call init_pic
    
    ; Load IDT
    lidt [idt_ptr]
    
    ; Initialize serial port for JARVIS
    call serial_init
    
    ; Enable interrupts
    sti
    
    ; Clear screen and show banner
    call clear_screen
    call show_banner
    
    ; Main loop
.halt:
    hlt
    jmp .halt
