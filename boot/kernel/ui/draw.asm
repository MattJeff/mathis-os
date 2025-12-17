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

; ════════════════════════════════════════════════════════════════════════════
; DRAW RECT (outline) - edi=x, esi=y, edx=w, ecx=h, r8d=color (32-bit BGRA)
; ════════════════════════════════════════════════════════════════════════════
draw_rect:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9
    push r10
    push r11

    mov r9d, [screen_pitch]         ; Save pitch
    mov r11d, edx                   ; Save width in pixels

    ; Calculate starting position: y * pitch + x * 4 + framebuffer (32-bit)
    mov eax, esi
    imul eax, r9d
    mov r10d, edi
    shl r10d, 2                     ; x * 4 for 32-bit
    add eax, r10d
    mov rbx, [screen_fb]
    add rbx, rax                    ; rbx = top-left corner

    ; Top line (32-bit)
    mov rdi, rbx
    push rcx
    mov ecx, r11d                   ; width in pixels
    mov eax, r8d
.top_line:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .top_line
    pop rcx

    ; Bottom line (32-bit)
    push rcx
    dec ecx
    mov eax, ecx
    imul eax, r9d
    mov rdi, rbx
    add rdi, rax                    ; rdi = bottom-left
    mov ecx, r11d                   ; width in pixels
    mov eax, r8d
.bottom_line:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .bottom_line
    pop rcx

    ; Left & right lines (32-bit pixels)
    push rcx
    mov rdi, rbx                    ; start at top-left
    mov r10d, r11d
    dec r10d
    shl r10d, 2                     ; offset to right edge pixel (in bytes)
    mov eax, r8d
.vert_loop:
    mov dword [rdi], eax            ; Left pixel
    mov rsi, rdi
    add rsi, r10
    mov dword [rsi], eax            ; Right pixel
    add rdi, r9                     ; next row (by pitch)
    dec ecx
    jnz .vert_loop
    pop rcx

    pop r11
    pop r10
    pop r9
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW TEXT - rdi=screen pos, rsi=string, r8d=color
; ════════════════════════════════════════════════════════════════════════════
draw_text:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14

    mov r9, rdi                     ; r9 = current X position base
    mov r12d, [screen_pitch]        ; r12 = pitch for row advance
    mov r14d, [screen_bpp]          ; r14 = bits per pixel

    ; Calculate bytes per pixel
    mov r13d, 1                     ; Default 1 byte
    cmp r14d, 24
    jne .not_24bpp_setup
    mov r13d, 3                     ; 24-bit = 3 bytes
    jmp .bpp_setup_done
.not_24bpp_setup:
    cmp r14d, 32
    jne .bpp_setup_done
    mov r13d, 4                     ; 32-bit = 4 bytes
.bpp_setup_done:

.text_loop:
    lodsb
    test al, al
    jz .text_done

    ; Get character bitmap pointer
    movzx rbx, al
    cmp bl, 32
    jl .skip_char
    cmp bl, 127
    jg .skip_char

    sub rbx, 32                     ; ASCII offset (space = 0)
    shl rbx, 3                      ; * 8 bytes per char
    lea r10, [font8x8 + rbx]

    ; Draw 8 rows of the character
    mov r11, r9                     ; r11 = current char position
    mov rcx, 8                      ; 8 rows
.draw_row:
    push rcx
    movzx ebx, byte [r10]           ; Get font row byte into BL (preserved)
    mov rdi, r11                    ; Set position for this row
    mov rcx, 8                      ; 8 pixels per row
.draw_pixel:
    test bl, 0x80                   ; Check leftmost bit
    jz .no_pixel

    ; Draw pixel based on BPP
    cmp r14d, 8
    je .draw_8bit
    cmp r14d, 24
    je .draw_24bit
    ; 32-bit
    mov dword [rdi], r8d            ; Write 4 bytes
    jmp .no_pixel
.draw_8bit:
    mov byte [rdi], r8b             ; Write 1 byte
    jmp .no_pixel
.draw_24bit:
    ; Write BGR (3 bytes) - use eax which won't clobber bl
    mov byte [rdi], r8b             ; Blue (low byte of r8d)
    mov eax, r8d
    shr eax, 8
    mov byte [rdi + 1], al          ; Green
    shr eax, 8
    mov byte [rdi + 2], al          ; Red

.no_pixel:
    shl bl, 1                       ; Next bit (using BL now, not AL)
    add rdi, r13                    ; Advance by bytes per pixel
    loop .draw_pixel

    inc r10                         ; Next font row
    add r11, r12                    ; Next screen row (use pitch)
    pop rcx
    loop .draw_row

    ; Move to next char position (8 pixels * bytes per pixel)
    mov eax, r13d
    shl eax, 3                      ; * 8
    add r9, rax
    jmp .text_loop

.skip_char:
    mov eax, r13d
    shl eax, 3
    add r9, rax
    jmp .text_loop

.text_done:
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
