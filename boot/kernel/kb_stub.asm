; ════════════════════════════════════════════════════════════════════════════
; KEYBOARD STUB - MINIMAL ISR (must stay small!)
; Position: Fixed at 0x10200
; Job: Read scancode, send EOI, call handler
; ════════════════════════════════════════════════════════════════════════════

keyboard_isr:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    ; Read scancode into EBX
    in al, 0x60
    movzx ebx, al
    
    ; Send EOI
    mov al, 0x20
    out 0x20, al
    
    ; Call full handler (in variable zone)
    call kb_handler
    
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    iret

; Pad to exactly 64 bytes - stub must be tiny!
    times 64 - ($ - keyboard_isr) db 0x90
