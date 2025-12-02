; ════════════════════════════════════════════════════════════════════════════
; DEBUG KEYBOARD ISR - STEP 1: PRINT 'X'
; ════════════════════════════════════════════════════════════════════════════

keyboard_isr:
    push eax
    push edi
    
    ; Read scancode
    in al, 0x60
    
    ; Send EOI immediately
    push eax            ; Save scancode
    mov al, 0x20
    out 0x20, al
    pop eax             ; Restore scancode
    
    ; Ignore key release (bit 7 set)
    test al, 0x80
    jnz .done
    
    ; Write 'X' to top-left corner
    mov edi, 0xB8000
    mov word [edi], 0x0F58  ; White on Black 'X'
    
.done:
    pop edi
    pop eax
    iret
