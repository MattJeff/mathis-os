; ============================================================================
; TEXT_MOD.ASM - Text Rendering Module
; ============================================================================
; High-level text drawing functions using 8x8 font
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
CHAR_WIDTH              equ 8
CHAR_HEIGHT             equ 8
FIRST_PRINTABLE         equ 32
LAST_PRINTABLE          equ 126

; ============================================================================
; EXPORTS
; ============================================================================
global text_draw_char
global text_draw_string
global text_draw_string_xy

; ============================================================================
; IMPORTS
; ============================================================================
extern font8x8
extern back_buffer
extern screen_width
extern screen_pitch
extern screen_bpp

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; text_draw_char - Draw single character at screen position
; Input:  EDI = x, ESI = y, DL = ASCII char, ECX = color
; ----------------------------------------------------------------------------
text_draw_char:
    push rax
    push rbx
    push r8
    push r9
    push r10
    push r11

    ; Validate character
    movzx eax, dl
    cmp al, FIRST_PRINTABLE
    jl .done
    cmp al, LAST_PRINTABLE
    jg .done

    ; Get glyph pointer
    sub al, FIRST_PRINTABLE
    shl eax, 3
    lea r8, [font8x8 + rax]

    ; Calculate screen position
    mov eax, esi
    imul eax, [screen_pitch]
    mov r9d, edi
    shl r9d, 2
    add eax, r9d
    mov r10, [back_buffer]
    add r10, rax

    ; Draw 8 rows
    mov r11d, CHAR_HEIGHT
.row:
    movzx eax, byte [r8]
    mov rbx, r10
    push r11
    mov r11d, CHAR_WIDTH

.pixel:
    test al, 0x80
    jz .skip
    mov [rbx], ecx
.skip:
    shl al, 1
    add rbx, 4
    dec r11d
    jnz .pixel

    pop r11
    inc r8
    add r10, [screen_pitch]
    dec r11d
    jnz .row

.done:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbx
    pop rax
    ret

; ----------------------------------------------------------------------------
; text_draw_string - Draw string at screen address
; Input:  RDI = screen address, RSI = string ptr, R8D = color
; ----------------------------------------------------------------------------
text_draw_string:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9
    push r10
    push r11

    mov r9, rdi
    mov r10d, [screen_pitch]

.loop:
    lodsb
    test al, al
    jz .done

    ; Check printable
    cmp al, FIRST_PRINTABLE
    jl .skip
    cmp al, LAST_PRINTABLE
    jg .skip

    ; Get glyph
    movzx ebx, al
    sub ebx, FIRST_PRINTABLE
    shl ebx, 3
    lea r11, [font8x8 + rbx]

    ; Draw 8 rows
    mov rcx, r9
    mov edx, CHAR_HEIGHT
.draw_row:
    push rdx
    movzx eax, byte [r11]
    mov rdi, rcx
    mov edx, CHAR_WIDTH

.draw_pixel:
    test al, 0x80
    jz .no_pixel
    mov [rdi], r8d
.no_pixel:
    shl al, 1
    add rdi, 4
    dec edx
    jnz .draw_pixel

    inc r11
    add rcx, r10
    pop rdx
    dec edx
    jnz .draw_row

.skip:
    add r9, CHAR_WIDTH * 4
    jmp .loop

.done:
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

; ----------------------------------------------------------------------------
; text_draw_string_xy - Draw string at x,y coordinates
; Input:  EDI = x, ESI = y, RDX = string ptr, ECX = color
; Convenience wrapper for text_draw_string
; ----------------------------------------------------------------------------
text_draw_string_xy:
    push rax
    push rdi
    push rsi
    push r8

    ; Calculate screen address
    mov eax, esi
    imul eax, [screen_pitch]
    mov r8d, edi
    shl r8d, 2
    add eax, r8d
    mov rdi, [back_buffer]
    add rdi, rax

    ; Setup params
    mov rsi, rdx
    mov r8d, ecx

    call text_draw_string

    pop r8
    pop rsi
    pop rdi
    pop rax
    ret
