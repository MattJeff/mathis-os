; ════════════════════════════════════════════════════════════════════════════
; CURSOR_WIDGET.ASM - Mouse Cursor with Background Save/Restore
; ════════════════════════════════════════════════════════════════════════════
; Saves pixels under cursor before drawing, restores when cursor moves
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; Cursor dimensions
CURSOR_W        equ 9
CURSOR_H        equ 12

; State
cursor_last_x:      dd 0xFFFF       ; Last drawn position (0xFFFF = none)
cursor_last_y:      dd 0xFFFF
cursor_bg_saved:    db 0            ; 1 if background is saved
cursor_bg_buffer:   times (CURSOR_W * CURSOR_H * 4) db 0  ; 432 bytes

; ════════════════════════════════════════════════════════════════════════════
; CURSOR_INVALIDATE - Invalidate saved background (call when screen redraws)
; ════════════════════════════════════════════════════════════════════════════
cursor_invalidate:
    mov byte [cursor_bg_saved], 0
    mov dword [cursor_last_x], 0xFFFF
    mov dword [cursor_last_y], 0xFFFF
    ret

; ════════════════════════════════════════════════════════════════════════════
; CURSOR_DRAW - Draw cursor at mouse position (with background save/restore)
; ════════════════════════════════════════════════════════════════════════════
cursor_draw:
cursor_widget_draw:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r12
    push r13

    ; Get current mouse position
    movzx r12d, word [mouse_x]
    movzx r13d, word [mouse_y]

    ; Check if position changed
    cmp r12d, [cursor_last_x]
    jne .position_changed
    cmp r13d, [cursor_last_y]
    jne .position_changed
    jmp .done                       ; Same position, nothing to do

.position_changed:
    ; Restore old background if saved
    cmp byte [cursor_bg_saved], 0
    je .no_restore
    call cursor_restore_bg

.no_restore:
    ; Save background at new position
    call cursor_save_bg

    ; Update last position
    mov [cursor_last_x], r12d
    mov [cursor_last_y], r13d

    ; Draw cursor
    call cursor_draw_arrow

.done:
    pop r13
    pop r12
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; CURSOR_SAVE_BG - Save pixels under cursor (at r12, r13)
; ════════════════════════════════════════════════════════════════════════════
cursor_save_bg:
    push rax
    push rcx
    push rdi
    push rsi
    push r8

    mov rsi, [screen_fb]
    mov r8d, [screen_pitch]

    ; Calculate source address: fb + y*pitch + x*4
    mov eax, r13d
    imul eax, r8d
    add rsi, rax
    mov eax, r12d
    shl eax, 2
    add rsi, rax                    ; rsi = pixel at (x, y)

    lea rdi, [cursor_bg_buffer]
    mov ecx, CURSOR_H

.save_row:
    push rcx
    push rsi
    mov ecx, CURSOR_W
    rep movsd                       ; Copy row (CURSOR_W dwords)
    pop rsi
    add rsi, r8                     ; Next row in framebuffer
    pop rcx
    dec ecx
    jnz .save_row

    mov byte [cursor_bg_saved], 1

    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; CURSOR_RESTORE_BG - Restore pixels at last cursor position
; ════════════════════════════════════════════════════════════════════════════
cursor_restore_bg:
    push rax
    push rcx
    push rdi
    push rsi
    push r8

    mov rdi, [screen_fb]
    mov r8d, [screen_pitch]

    ; Calculate dest address at last position
    mov eax, [cursor_last_y]
    imul eax, r8d
    add rdi, rax
    mov eax, [cursor_last_x]
    shl eax, 2
    add rdi, rax                    ; rdi = pixel at (last_x, last_y)

    lea rsi, [cursor_bg_buffer]
    mov ecx, CURSOR_H

.restore_row:
    push rcx
    push rdi
    mov ecx, CURSOR_W
    rep movsd                       ; Copy row back
    pop rdi
    add rdi, r8                     ; Next row
    pop rcx
    dec ecx
    jnz .restore_row

    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; CURSOR_DRAW_ARROW - Draw arrow shape at (r12, r13)
; ════════════════════════════════════════════════════════════════════════════
cursor_draw_arrow:
    push rdi
    push r8

    mov rdi, [screen_fb]
    mov r8d, [screen_pitch]

    ; Calculate address
    mov eax, r13d
    imul eax, r8d
    add rdi, rax
    mov eax, r12d
    shl eax, 2
    add rdi, rax

    ; Row 0: 1 pixel
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00000000
    add rdi, r8

    ; Row 1: 2 pixels
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00000000
    add rdi, r8

    ; Row 2: 3 pixels
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00FFFFFF
    mov dword [rdi+12], 0x00000000
    add rdi, r8

    ; Row 3: 4 pixels
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00FFFFFF
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00000000
    add rdi, r8

    ; Row 4: 5 pixels
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00FFFFFF
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00FFFFFF
    mov dword [rdi+20], 0x00000000
    add rdi, r8

    ; Row 5: 6 pixels
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00FFFFFF
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00FFFFFF
    mov dword [rdi+20], 0x00FFFFFF
    mov dword [rdi+24], 0x00000000
    add rdi, r8

    ; Row 6: 7 pixels
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00FFFFFF
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00FFFFFF
    mov dword [rdi+20], 0x00FFFFFF
    mov dword [rdi+24], 0x00FFFFFF
    mov dword [rdi+28], 0x00000000
    add rdi, r8

    ; Row 7: 8 pixels
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00FFFFFF
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00FFFFFF
    mov dword [rdi+20], 0x00FFFFFF
    mov dword [rdi+24], 0x00FFFFFF
    mov dword [rdi+28], 0x00FFFFFF
    mov dword [rdi+32], 0x00000000
    add rdi, r8

    ; Row 8: bottom part
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00FFFFFF
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00000000
    add rdi, r8

    ; Row 9: split
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00000000
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00FFFFFF
    mov dword [rdi+20], 0x00000000
    add rdi, r8

    ; Row 10: split
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00000000
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00FFFFFF
    mov dword [rdi+20], 0x00000000
    add rdi, r8

    ; Row 11: tail
    mov dword [rdi], 0x00000000
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00000000

    pop r8
    pop rdi
    ret
