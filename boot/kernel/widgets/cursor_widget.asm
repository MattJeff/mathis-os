; ════════════════════════════════════════════════════════════════════════════
; CURSOR_WIDGET.ASM - Mouse Cursor as Widget (SOLID)
; ════════════════════════════════════════════════════════════════════════════
; Format: RGB (0x00RRGGBB)
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; CURSOR_DRAW - Draw cursor at mouse position
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

    ; Get mouse position
    movzx r12d, word [mouse_x]
    movzx r13d, word [mouse_y]

    ; Get framebuffer and pitch
    mov rdi, [screen_fb]
    mov r8d, [screen_pitch]

    ; Draw arrow cursor (12 pixels tall)
    ; Arrow shape:
    ;   X
    ;   XX
    ;   X X
    ;   X  X
    ;   X   X
    ;   X    X
    ;   X     X
    ;   X      X
    ;   X    XXXX
    ;   X  XX
    ;   X XX
    ;   XX

    ; Calculate starting address: fb + y*pitch + x*4
    mov eax, r13d
    imul eax, r8d
    add rdi, rax
    mov eax, r12d
    shl eax, 2
    add rdi, rax                    ; rdi = pixel at (mouse_x, mouse_y)

    ; Row 0: 1 pixel
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00000000   ; border
    add rdi, r8                     ; next row

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

    ; Row 8: bottom of arrow (5 pixels filled, then border)
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00FFFFFF
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00000000
    mov dword [rdi+20], 0x00000000
    mov dword [rdi+24], 0x00000000
    mov dword [rdi+28], 0x00000000
    mov dword [rdi+32], 0x00000000
    add rdi, r8

    ; Row 9: 2 + 2 pixels
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00FFFFFF
    mov dword [rdi+8], 0x00000000
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00FFFFFF
    mov dword [rdi+20], 0x00000000
    add rdi, r8

    ; Row 10: 1 + 2 pixels
    mov dword [rdi], 0x00FFFFFF
    mov dword [rdi+4], 0x00000000
    mov dword [rdi+8], 0x00000000
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00FFFFFF
    mov dword [rdi+20], 0x00000000
    add rdi, r8

    ; Row 11: tail
    mov dword [rdi], 0x00000000
    mov dword [rdi+8], 0x00000000
    mov dword [rdi+12], 0x00FFFFFF
    mov dword [rdi+16], 0x00000000

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
