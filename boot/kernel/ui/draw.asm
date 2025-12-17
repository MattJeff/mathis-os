; ============================================================================
; MathisOS - Draw primitives
; ============================================================================
; Primitives de dessin (sera rempli progressivement)
; - draw_line_h
; - draw_rect
; - fill_rect
; - draw_text
; - draw_line
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; DRAW LINE H - Simple horizontal line
; edi=x, esi=y, edx=x2, r8d=color
; ════════════════════════════════════════════════════════════════════════════
draw_line_h:
    push rax
    push rbx
    push rdi
    mov eax, esi
    imul eax, [screen_pitch]
    add eax, edi
    mov rbx, [screen_fb]
    add rax, rbx
    mov rdi, rax
.loop_h:
    mov byte [rdi], r8b
    inc rdi
    inc edi
    cmp edi, edx
    jle .loop_h
    pop rdi
    pop rbx
    pop rax
    ret
