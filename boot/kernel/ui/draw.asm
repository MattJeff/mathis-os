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

; ════════════════════════════════════════════════════════════════════════════
; FILL RECT - edi=x, esi=y, edx=w, ecx=h, r8d=color (32-bit BGRA)
; ════════════════════════════════════════════════════════════════════════════
fill_rect:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi
    push r9

    ; Calculate starting offset: y * pitch + x*4 + framebuffer (32-bit)
    mov eax, esi
    imul eax, [screen_pitch]
    mov r9d, edi
    shl r9d, 2                      ; x * 4 for 32-bit
    add eax, r9d
    mov rdi, [screen_fb]
    add rdi, rax
    mov ebx, edx                    ; width in pixels
    mov r9d, [screen_pitch]         ; save pitch for row advance

.fill_row:
    push rcx
    push rdi                        ; save row start
    mov ecx, ebx                    ; pixel count for this row
    mov eax, r8d                    ; color
.fill_pixel:
    mov dword [rdi], eax            ; Write 32-bit pixel
    add rdi, 4
    dec ecx
    jnz .fill_pixel
    pop rdi                         ; restore row start
    add rdi, r9                     ; advance to next row (by pitch)
    pop rcx
    dec ecx
    jnz .fill_row

    pop r9
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret
