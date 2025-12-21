; ============================================================================
; ISR_MOD.ASM - Interrupt Service Routines Module
; ============================================================================
; Contains: mouse_isr64 (PS/2 Mouse handler for IRQ12)
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
MOUSE_DATA              equ 0x60
CLICK_COOLDOWN_TICKS    equ 15
CURSOR_MARGIN           equ 16

; ============================================================================
; EXPORTS
; ============================================================================
global mouse_isr64

; ============================================================================
; IMPORTS
; ============================================================================
extern mouse_x
extern mouse_y
extern mouse_buttons
extern mouse_clicked
extern mouse_cycle
extern mouse_byte0
extern mouse_byte1
extern mouse_byte2
extern last_mouse_btn
extern click_cooldown
extern screen_width
extern screen_height

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; mouse_isr64 - Mouse interrupt handler (IRQ12)
; Processes 3-byte PS/2 packets
; ----------------------------------------------------------------------------
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
    jz .mouse_done
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

    ; Store buttons
    mov al, [mouse_byte0]
    mov [mouse_buttons], al

    ; Update X position
    movsx eax, byte [mouse_byte1]
    movzx ebx, word [mouse_x]
    add ebx, eax
    ; Clamp X: 0 to screen_width-16
    test ebx, ebx
    jns .x_min_ok
    xor ebx, ebx
.x_min_ok:
    mov eax, [screen_width]
    sub eax, CURSOR_MARGIN
    cmp ebx, eax
    jle .x_max_ok
    mov ebx, eax
.x_max_ok:
    mov [mouse_x], bx

    ; Update Y (inverted)
    movsx eax, byte [mouse_byte2]
    neg eax
    movzx ebx, word [mouse_y]
    add ebx, eax
    test ebx, ebx
    jns .y_min_ok
    xor ebx, ebx
.y_min_ok:
    mov eax, [screen_height]
    sub eax, CURSOR_MARGIN
    cmp ebx, eax
    jle .y_max_ok
    mov ebx, eax
.y_max_ok:
    mov [mouse_y], bx

    ; Click detection with debounce
    mov ecx, [click_cooldown]
    test ecx, ecx
    jz .cooldown_ok
    dec dword [click_cooldown]
    jmp .mouse_done

.cooldown_ok:
    mov al, [mouse_byte0]
    and al, 1
    mov ah, [last_mouse_btn]
    mov [last_mouse_btn], al
    test ah, ah
    jnz .mouse_done
    test al, al
    jz .mouse_done

    ; Click detected
    mov dword [click_cooldown], CLICK_COOLDOWN_TICKS
    mov byte [mouse_clicked], 1

.mouse_done:
    ; Send EOI to both PICs (IRQ12 is on slave PIC)
    mov al, 0x20
    out 0xA0, al
    out 0x20, al

    pop rcx
    pop rbx
    pop rax
    iretq
