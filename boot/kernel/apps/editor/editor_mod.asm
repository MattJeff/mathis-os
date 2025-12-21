; ============================================================================
; EDITOR_MOD.ASM - Text Editor Application
; ============================================================================
; Simple text editor window
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
EDITOR_WIDTH            equ 400
EDITOR_HEIGHT           equ 300
WIN_DRAW_CB             equ 32
WIN_TYPE_EDITOR         equ 3
EDITOR_COLOR_BG         equ 0x00FFFFFF
EDITOR_COLOR_TEXT       equ 0x00000000
EDITOR_MAX_CHARS        equ 1024

; ============================================================================
; EXPORTS
; ============================================================================
global editor_open
global editor_draw
global editor_on_key

; ============================================================================
; IMPORTS
; ============================================================================
extern wm_create_window
extern draw_fill_rect
extern text_draw_string_xy

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; editor_open - Open editor window
; Output: RAX = window pointer
; ----------------------------------------------------------------------------
editor_open:
    push rbx

    ; Clear buffer
    lea rdi, [editor_buffer]
    xor al, al
    mov ecx, EDITOR_MAX_CHARS
    rep stosb
    mov dword [editor_cursor], 0

    ; Create window
    mov edi, WIN_TYPE_EDITOR
    mov esi, 150
    mov edx, 80
    mov ecx, EDITOR_WIDTH
    mov r8d, EDITOR_HEIGHT
    lea r9, [str_editor_title]
    call wm_create_window

    test rax, rax
    jz .done

    mov rbx, rax
    lea rcx, [editor_draw]
    mov [rbx + WIN_DRAW_CB], rcx

.done:
    pop rbx
    ret

; ----------------------------------------------------------------------------
; editor_draw - Draw editor content
; Input: RDI = window pointer
; ----------------------------------------------------------------------------
editor_draw:
    push rbx
    push r12
    push r13
    mov rbx, rdi

    ; Get client area
    mov r12d, [rbx + 8]
    mov r13d, [rbx + 12]
    add r13d, 24

    ; Draw white background
    mov edi, r12d
    mov esi, r13d
    mov edx, EDITOR_WIDTH
    mov ecx, EDITOR_HEIGHT - 24
    mov r8d, EDITOR_COLOR_BG
    call draw_fill_rect

    ; Draw text content
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 10
    lea rdx, [editor_buffer]
    mov ecx, EDITOR_COLOR_TEXT
    call text_draw_string_xy

    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; editor_on_key - Handle key input
; Input: EDI = scancode
; ----------------------------------------------------------------------------
editor_on_key:
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_editor_title:       db "Editor", 0

section .data

editor_cursor:          dd 0

section .bss

editor_buffer:          resb EDITOR_MAX_CHARS
