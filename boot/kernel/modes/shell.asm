; ============================================================================
; MathisOS - Shell Mode
; ============================================================================
; Mode 1 - Text-based shell interface
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; SHELL MODE
; ════════════════════════════════════════════════════════════════════════════
shell_mode:
    ; Clear screen to dark blue (32-bit mode)
    push rbx
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    mov ebx, [screen_height]
    imul eax, ebx               ; EAX = total pixels
    mov ecx, eax                ; ECX = number of pixels
    mov eax, 0x00000060         ; BGRA: dark blue (B=0x60)
.shell_clear_loop:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .shell_clear_loop
    pop rbx

    ; Draw banner at (10, 10)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 10
    add rdi, rax
    add rdi, 10
    mov rsi, str_banner
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; Draw help at bottom
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, 40
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 10
    mov rsi, str_help_shell
    mov r8d, 7
    call draw_text

    mov rcx, 500000
.shell_delay:
    dec rcx
    jnz .shell_delay

    jmp main_loop
