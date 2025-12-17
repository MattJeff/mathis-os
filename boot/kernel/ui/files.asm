; ============================================================================
; MathisOS - File Manager UI
; ============================================================================
; File manager 2D (sera rempli progressivement)
; - draw_files_window
; - files_mode logic
; - navigation clavier fichiers
; - CRUD fichiers/dossiers
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; DRAW FILES WINDOW CONTENT
; ════════════════════════════════════════════════════════════════════════════
draw_files_window:
    push rbx
    push r13
    push r14

    movzx r13, word [rbx + 2]       ; x
    movzx r14, word [rbx + 4]       ; y

    ; Draw files list at (x+10, y+TITLEBAR_H+6)
    mov rdi, [screen_fb]
    mov eax, r14d
    add eax, TITLEBAR_H + 6
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, r13
    add rdi, 10
    mov rsi, str_file1
    mov r8d, COL_YELLOW
    call draw_text

    ; Second file at (x+10, y+TITLEBAR_H+18)
    mov rdi, [screen_fb]
    mov eax, r14d
    add eax, TITLEBAR_H + 18
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, r13
    add rdi, 10
    mov rsi, str_file2
    mov r8d, COL_YELLOW
    call draw_text

    ; Third file at (x+10, y+TITLEBAR_H+30)
    mov rdi, [screen_fb]
    mov eax, r14d
    add eax, TITLEBAR_H + 30
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, r13
    add rdi, 10
    mov rsi, str_file3
    mov r8d, COL_CYAN
    call draw_text

    pop r14
    pop r13
    pop rbx
    ret
