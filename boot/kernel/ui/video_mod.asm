; ============================================================================
; VIDEO_MOD.ASM - Video Primitives with Double Buffering
; ============================================================================
; Low-level framebuffer drawing with back buffer for flicker-free rendering
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; EXPORTS
; ============================================================================
global video_init
global video_flip
global video_clear
global video_put_pixel
global video_draw_rect
global video_draw_hline
global video_draw_vline
global back_buffer

; ============================================================================
; IMPORTS
; ============================================================================
extern screen_fb
extern screen_width
extern screen_height
extern screen_pitch
extern heap_alloc

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; video_init - Initialize double buffering
; Allocates back buffer from heap
; Output: RAX = back buffer address (0 if failed)
; ----------------------------------------------------------------------------
video_init:
    push rbx
    push rcx

    ; Calculate buffer size: width * height * 4
    mov eax, [screen_width]
    imul eax, [screen_height]
    shl eax, 2                          ; * 4 bytes per pixel

    ; Allocate from heap
    mov edi, eax
    call heap_alloc

    ; Store back buffer address
    mov [back_buffer], rax

    ; If allocation failed, use screen_fb directly (no buffering)
    test rax, rax
    jnz .done
    mov rax, [screen_fb]
    mov [back_buffer], rax

.done:
    pop rcx
    pop rbx
    ret

; ----------------------------------------------------------------------------
; video_flip - Copy back buffer to screen (fast memcpy)
; Uses REP MOVSQ for fast 64-bit copies
; ----------------------------------------------------------------------------
video_flip:
    push rax
    push rcx
    push rsi
    push rdi

    ; Check if back buffer is same as screen (no double buffer)
    mov rsi, [back_buffer]
    mov rdi, [screen_fb]
    cmp rsi, rdi
    je .done                            ; Same buffer, no copy needed

    ; Calculate size in qwords: (width * height * 4) / 8
    mov eax, [screen_width]
    imul eax, [screen_height]
    shr eax, 1                          ; /2 because 4 bytes/pixel, 8 bytes/qword

    mov ecx, eax
    rep movsq                           ; Fast copy

.done:
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

; ----------------------------------------------------------------------------
; video_clear - Clear screen with color
; Input: EDI = color (ARGB)
; ----------------------------------------------------------------------------
video_clear:
    push rax
    push rcx
    push rdi
    push r8

    mov eax, edi                    ; Color
    mov r8, [back_buffer]           ; Use back buffer
    mov rdi, r8

    mov ecx, [screen_width]
    imul ecx, [screen_height]

.fill:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .fill

    pop r8
    pop rdi
    pop rcx
    pop rax
    ret

; ----------------------------------------------------------------------------
; video_put_pixel - Draw single pixel
; Input: EDI = x, ESI = y, EDX = color
; ----------------------------------------------------------------------------
video_put_pixel:
    push rax
    push rbx

    ; Bounds check
    cmp edi, [screen_width]
    jae .done
    cmp esi, [screen_height]
    jae .done

    ; Calculate offset: (y * pitch) + (x * 4)
    xor rax, rax
    mov eax, esi
    imul eax, [screen_pitch]
    xor rbx, rbx
    mov ebx, edi
    shl ebx, 2
    add rax, rbx

    ; Get back buffer base (64-bit)
    mov rbx, [back_buffer]
    add rbx, rax

    ; Write pixel
    mov [rbx], edx

.done:
    pop rbx
    pop rax
    ret

; ----------------------------------------------------------------------------
; video_draw_rect - Draw filled rectangle
; Input: EDI = x, ESI = y, EDX = width, ECX = height, R8D = color
; ----------------------------------------------------------------------------
video_draw_rect:
    push rax
    push rbx
    push r9
    push r10
    push r11

    mov r9d, edi                    ; x
    mov r10d, esi                   ; y
    mov r11d, edx                   ; width

    ; Calculate starting offset
    xor rax, rax
    mov eax, esi
    imul eax, [screen_pitch]
    xor rbx, rbx
    mov ebx, edi
    shl ebx, 2
    add rax, rbx
    mov rbx, [back_buffer]          ; Use back buffer
    add rbx, rax

.row_loop:
    test ecx, ecx
    jz .done

    push rcx
    mov ecx, r11d                   ; width

.col_loop:
    mov [rbx], r8d
    add rbx, 4
    dec ecx
    jnz .col_loop

    ; Move to next row
    xor rax, rax
    mov eax, [screen_pitch]
    mov ecx, r11d
    shl ecx, 2
    sub eax, ecx                    ; pitch - width*4
    add rbx, rax

    pop rcx
    dec ecx
    jmp .row_loop

.done:
    pop r11
    pop r10
    pop r9
    pop rbx
    pop rax
    ret

; ----------------------------------------------------------------------------
; video_draw_hline - Draw horizontal line
; Input: EDI = x, ESI = y, EDX = length, ECX = color
; ----------------------------------------------------------------------------
video_draw_hline:
    push rax
    push rbx
    push rdx

    ; Calculate offset
    xor rax, rax
    mov eax, esi
    imul eax, [screen_pitch]
    xor rbx, rbx
    mov ebx, edi
    shl ebx, 2
    add rax, rbx
    mov rbx, [back_buffer]          ; Use back buffer
    add rbx, rax

.draw:
    mov [rbx], ecx
    add rbx, 4
    dec edx
    jnz .draw

    pop rdx
    pop rbx
    pop rax
    ret

; ----------------------------------------------------------------------------
; video_draw_vline - Draw vertical line
; Input: EDI = x, ESI = y, EDX = length, ECX = color
; ----------------------------------------------------------------------------
video_draw_vline:
    push rax
    push rbx
    push rdx
    push r8

    xor rax, rax
    mov eax, esi
    imul eax, [screen_pitch]
    xor rbx, rbx
    mov ebx, edi
    shl ebx, 2
    add rax, rbx
    mov rbx, [back_buffer]          ; Use back buffer
    add rbx, rax

    xor r8, r8
    mov r8d, [screen_pitch]

.draw:
    mov [rbx], ecx
    add rbx, r8
    dec edx
    jnz .draw

    pop r8
    pop rdx
    pop rbx
    pop rax
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

; Back buffer pointer (initialized by video_init)
back_buffer:            dq 0

section .bss
