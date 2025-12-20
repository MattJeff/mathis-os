; ════════════════════════════════════════════════════════════════════════════
; ISR.ASM - Interrupt Service Routines
; ════════════════════════════════════════════════════════════════════════════
; Contains:
;   - syscall_isr64: System call handler (INT 0x80)
;   - mouse_isr64: PS/2 Mouse handler (IRQ12)
;
; Note: keyboard_isr64 is in input/keyboard.asm
;       timer_isr64 is in sys/timer.asm
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; SYSCALL ISR (INT 0x80) - Redirects to full syscall handler
; See syscalls.asm for complete syscall table (48 syscalls)
; ════════════════════════════════════════════════════════════════════════════
syscall_isr64:
    jmp syscall_handler         ; Jump to full syscall dispatcher

; ════════════════════════════════════════════════════════════════════════════
; MOUSE ISR (IRQ12) - PS/2 Mouse packet handler
; ════════════════════════════════════════════════════════════════════════════
; PS/2 mouse sends 3-byte packets:
;   Byte 0: Buttons + overflow + sign bits
;   Byte 1: X movement (signed)
;   Byte 2: Y movement (signed)
; ════════════════════════════════════════════════════════════════════════════
mouse_isr64:
    push rax
    push rbx
    push rcx

    in al, MOUSE_DATA
    movzx rbx, byte [mouse_cycle]

    cmp bl, 0
    je .byte0
    cmp bl, 1
    je .byte1
    jmp .byte2

.byte0:
    ; Validate byte0: bit 3 must be 1 (PS/2 protocol)
    test al, 0x08
    jz .mouse_done                      ; Invalid packet, resync
    mov [mouse_byte0], al
    inc byte [mouse_cycle]
    jmp .mouse_done

.byte1:
    mov [mouse_byte1], al
    inc byte [mouse_cycle]
    jmp .mouse_done

.byte2:
    mov [mouse_byte2], al
    mov byte [mouse_cycle], 0

    ; Process complete packet
    mov al, [mouse_byte0]
    mov [mouse_buttons], al

    ; Update X position
    ; mouse_byte1 is SIGNED delta, mouse_x is UNSIGNED position
    movsx eax, byte [mouse_byte1]       ; Signed delta (-128 to +127)
    movzx ebx, word [mouse_x]           ; Unsigned current pos (0 to 65535)
    add ebx, eax                        ; New position (can go negative)
    ; Clamp X: 0 to screen_width-16
    test ebx, ebx
    jns .x_min_ok                       ; Jump if not negative (SF=0)
    xor ebx, ebx                        ; Clamp to 0
.x_min_ok:
    mov eax, [screen_width]
    sub eax, 16
    cmp ebx, eax
    jle .x_max_ok
    mov ebx, eax
.x_max_ok:
    mov [mouse_x], bx

    ; Update Y position (inverted - PS/2 Y is opposite of screen Y)
    movsx eax, byte [mouse_byte2]       ; Signed delta
    neg eax                             ; Invert Y (PS/2 is upside down)
    movzx ebx, word [mouse_y]           ; Unsigned current pos
    add ebx, eax                        ; New position
    ; Clamp Y: 0 to screen_height-16
    test ebx, ebx
    jns .y_min_ok                       ; Jump if not negative
    xor ebx, ebx                        ; Clamp to 0
.y_min_ok:
    mov eax, [screen_height]
    sub eax, 16
    cmp ebx, eax
    jle .y_max_ok
    mov ebx, eax
.y_max_ok:
    mov [mouse_y], bx

    ; NOTE: Event posting disabled - causes crashes in ISR context
    ; Mouse position is already stored in mouse_x/y variables
    ; Main loop will poll these directly

    ; Check for click (with debounce + cooldown)
    mov ecx, [click_cooldown]
    test ecx, ecx
    jz .cooldown_ok
    dec dword [click_cooldown]
    jmp .no_click

.cooldown_ok:
    mov al, [mouse_byte0]
    and al, 1                           ; Isolate left button
    mov ah, [last_mouse_btn]
    mov [last_mouse_btn], al            ; Save current state
    test ah, ah                         ; Was button pressed before?
    jnz .no_click                       ; Yes = ignore (held down)
    test al, al                         ; Is button pressed now?
    jz .no_click                        ; No = no click

    ; Button just pressed (0->1 transition)
    mov dword [click_cooldown], 15      ; 15 packets cooldown (~150ms)

    ; Set click flag for main loop to process
    mov byte [mouse_clicked], 1

    call handle_mouse_click

.no_click:

.mouse_done:
    ; Send EOI to both PICs (IRQ12 is on slave PIC)
    mov al, 0x20
    out 0xA0, al
    out 0x20, al

    pop rcx
    pop rbx
    pop rax
    iretq
