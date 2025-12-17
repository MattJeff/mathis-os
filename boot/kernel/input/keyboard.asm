; ============================================================================
; MathisOS - Keyboard Handler (Simplified)
; ============================================================================
; ISR simplifie : lit scancode, gere modifiers, stocke event
; Le traitement des touches est fait par le dispatcher
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; KEYBOARD ISR - Simplified Event-Driven
; ════════════════════════════════════════════════════════════════════════════
; Entree: IRQ1 declenche
; Sortie: key_pressed et key_ready mis a jour
; ════════════════════════════════════════════════════════════════════════════
keyboard_isr64_new:
    push rax
    push rbx

    in al, 0x60                         ; Lire scancode
    mov [last_scancode], al             ; Stocker pour debug

    ; Check release (bit 7 set)
    test al, 0x80
    jnz .handle_release

    ; === KEY PRESS ===
    ; Check modifiers
    cmp al, 0x2A                        ; Left shift
    je .shift_on
    cmp al, 0x36                        ; Right shift
    je .shift_on
    cmp al, 0x1D                        ; Ctrl
    je .ctrl_on
    cmp al, 0x38                        ; Alt
    je .alt_on

    ; Normal key - store event
    mov [key_pressed], al
    mov byte [key_ready], 1             ; Signal nouvelle touche
    jmp .done

.shift_on:
    mov byte [shift_state], 1
    jmp .done

.ctrl_on:
    mov byte [ctrl_state], 1
    jmp .done

.alt_on:
    mov byte [alt_state], 1
    jmp .done

    ; === KEY RELEASE ===
.handle_release:
    and al, 0x7F                        ; Remove release bit
    cmp al, 0x2A
    je .shift_off
    cmp al, 0x36
    je .shift_off
    cmp al, 0x1D
    je .ctrl_off
    cmp al, 0x38
    je .alt_off
    jmp .done

.shift_off:
    mov byte [shift_state], 0
    jmp .done

.ctrl_off:
    mov byte [ctrl_state], 0
    jmp .done

.alt_off:
    mov byte [alt_state], 0

.done:
    mov al, 0x20
    out 0x20, al                        ; EOI to PIC
    pop rbx
    pop rax
    iretq
