; ============================================================================
; DRAW_MOD.ASM - High-Level Drawing Primitives
; ============================================================================
; 32-bit BGRA drawing operations
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
BYTES_PER_PIXEL         equ 4

; ============================================================================
; EXPORTS
; ============================================================================
global draw_fill_rect
global draw_rect_outline
global draw_hline
global draw_vline

; ============================================================================
; IMPORTS
; ============================================================================
extern back_buffer
extern screen_width
extern screen_height
extern screen_pitch

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; draw_fill_rect - Draw filled rectangle
; Input: EDI = x, ESI = y, EDX = width, ECX = height, R8D = color
; ----------------------------------------------------------------------------
draw_fill_rect:
    push rax
    push rbx
    push r9
    push r10
    push r11

    mov r9d, edx                    ; width
    mov r10d, ecx                   ; height
    xor r11, r11
    mov r11d, [screen_pitch]        ; zero-extend pitch

    ; Calculate start address
    xor rax, rax
    mov eax, esi
    imul eax, r11d
    xor rbx, rbx
    mov ebx, edi
    shl ebx, 2
    add rax, rbx                    ; use rax (was eax)
    mov rbx, [back_buffer]
    add rbx, rax

.row_loop:
    test r10d, r10d
    jz .done

    mov ecx, r9d
    mov rax, rbx

.pixel_loop:
    mov [rax], r8d
    add rax, BYTES_PER_PIXEL
    dec ecx
    jnz .pixel_loop

    add rbx, r11
    dec r10d
    jmp .row_loop

.done:
    pop r11
    pop r10
    pop r9
    pop rbx
    pop rax
    ret

; ----------------------------------------------------------------------------
; draw_rect_outline - Draw rectangle outline
; Input: EDI = x, ESI = y, EDX = width, ECX = height, R8D = color
; ----------------------------------------------------------------------------
draw_rect_outline:
    push rdi
    push rsi
    push rdx
    push rcx

    ; Top line
    push rcx
    mov ecx, r8d
    call draw_hline
    pop rcx

    ; Bottom line
    push rdi
    push rsi
    push rdx
    add esi, ecx
    dec esi
    mov ecx, r8d
    call draw_hline
    pop rdx
    pop rsi
    pop rdi

    ; Left line
    push rdx
    mov edx, ecx
    mov ecx, r8d
    call draw_vline
    pop rdx

    ; Right line
    add edi, edx
    dec edi
    mov ecx, r8d
    call draw_vline

    pop rcx
    pop rdx
    pop rsi
    pop rdi
    ret

; ----------------------------------------------------------------------------
; draw_hline - Draw horizontal line
; Input: EDI = x, ESI = y, EDX = length, ECX = color
; ----------------------------------------------------------------------------
draw_hline:
    push rax
    push rbx

    xor rax, rax
    mov eax, esi
    imul eax, [screen_pitch]
    xor rbx, rbx
    mov ebx, edi
    shl ebx, 2
    add rax, rbx
    mov rbx, [back_buffer]
    add rbx, rax

.loop:
    mov [rbx], ecx
    add rbx, BYTES_PER_PIXEL
    dec edx
    jnz .loop

    pop rbx
    pop rax
    ret

; ----------------------------------------------------------------------------
; draw_vline - Draw vertical line
; Input: EDI = x, ESI = y, EDX = length, ECX = color
; ----------------------------------------------------------------------------
draw_vline:
    push rax
    push rbx
    push r8

    xor rax, rax
    mov eax, esi
    imul eax, [screen_pitch]
    xor rbx, rbx
    mov ebx, edi
    shl ebx, 2
    add rax, rbx
    mov rbx, [back_buffer]
    add rbx, rax
    xor r8, r8
    mov r8d, [screen_pitch]

.loop:
    mov [rbx], ecx
    add rbx, r8
    dec edx
    jnz .loop

    pop r8
    pop rbx
    pop rax
    ret
