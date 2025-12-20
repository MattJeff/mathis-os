; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_BG.ASM - Draw desktop background
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_DRAW_BG - Draw solid background
; ════════════════════════════════════════════════════════════════════════════
desktop_draw_bg:
    push rax
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    ; Draw blue background
    xor edi, edi                    ; x = 0
    xor esi, esi                    ; y = 0
    mov edx, [screen_width]         ; w
    mov ecx, [screen_height]        ; h
    mov r8d, DESKTOP_BG_COLOR
    call fill_rect

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret
