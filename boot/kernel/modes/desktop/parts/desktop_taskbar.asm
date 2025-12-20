; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_TASKBAR.ASM - Draw taskbar at bottom
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_DRAW_TASKBAR - Draw taskbar
; ════════════════════════════════════════════════════════════════════════════
desktop_draw_taskbar:
    push rax
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    ; Calculate taskbar Y position
    mov ecx, [screen_height]
    sub ecx, DESKTOP_TASKBAR_H      ; y = screen_height - taskbar_h

    ; Draw taskbar background
    xor edi, edi                    ; x = 0
    mov esi, ecx                    ; y
    mov edx, [screen_width]         ; w
    mov ecx, DESKTOP_TASKBAR_H      ; h
    mov r8d, DESKTOP_TASKBAR_COLOR
    call fill_rect

    ; Draw "Start" button (left side)
    mov edi, 4                      ; x = 4
    mov esi, [screen_height]
    sub esi, DESKTOP_TASKBAR_H
    add esi, 4                      ; y = taskbar_y + 4
    mov edx, 50                     ; w = 50
    mov ecx, 20                     ; h = 20
    mov r8d, 0x00404040             ; Darker gray
    call fill_rect

    ; Draw "Start" text
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, DESKTOP_TASKBAR_H
    add eax, 8                      ; y = taskbar_y + 8
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 12 * 4                 ; x = 12
    lea rsi, [desktop_str_start]
    mov r8d, 0x00FFFFFF             ; White
    call draw_text

    ; Draw clock (right side)
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, DESKTOP_TASKBAR_H
    add eax, 8
    imul eax, [screen_pitch]
    add rdi, rax
    mov eax, [screen_width]
    sub eax, 50                     ; x = screen_width - 50
    shl eax, 2
    add rdi, rax
    lea rsi, [desktop_str_clock]
    mov r8d, 0x00FFFFFF
    call draw_text

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret
