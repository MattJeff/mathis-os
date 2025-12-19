; ============================================================================
; MathisOS - Graphics Mode (3D Demo)
; ============================================================================
; Mode 0 - Fullscreen 3D cube demo
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; GRAPHICS MODE - 3D Cube (fullscreen)
; ════════════════════════════════════════════════════════════════════════════
graphics_mode:
    ; Clear screen to dark gray (32-bit mode)
    push rbx
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    mov ebx, [screen_height]
    imul eax, ebx               ; EAX = total pixels
    mov ecx, eax                ; ECX = number of pixels
    mov eax, 0x00303030         ; BGRA: dark gray
.gfx_clear_loop:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .gfx_clear_loop
    pop rbx

    ; Draw 3D mode text at center of screen
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 100
    add rdi, rax
    add rdi, 120
    mov rsi, str_3d_mode
    mov r8d, COL_GREEN
    call draw_text

    ; Draw help text near bottom
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, 50
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 10
    mov rsi, str_help_gfx
    mov r8d, 7
    call draw_text

    mov rcx, 1000000
.gfx_delay:
    dec rcx
    jnz .gfx_delay

    jmp main_loop
