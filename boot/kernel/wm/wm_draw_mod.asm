; ============================================================================
; WM_DRAW_MOD.ASM - Window Drawing
; ============================================================================
; Render windows with Mac-style title bar and controls
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
WM_MAX_WINDOWS          equ 8
WIN_STRUCT_SIZE         equ 56
WIN_FLAGS               equ 0
WIN_X                   equ 8
WIN_Y                   equ 12
WIN_W                   equ 16
WIN_H                   equ 20
WIN_TITLE               equ 24
WIN_DRAW_CB             equ 32
WIN_FLAG_VISIBLE        equ 0x01
WIN_FLAG_ACTIVE         equ 0x02
WIN_FLAG_MINIMIZED      equ 0x04
WIN_FLAG_MAXIMIZED      equ 0x08
WIN_TITLE_HEIGHT        equ 24
WIN_COLOR_TITLE_BG      equ 0x00353535
WIN_COLOR_TITLE_ACTIVE  equ 0x00454545
WIN_COLOR_BG            equ 0x00F0F0F0
WIN_COLOR_TITLE_TEXT    equ 0x00FFFFFF
TITLE_TEXT_OFFSET_X     equ 60          ; After control buttons

; ============================================================================
; EXPORTS
; ============================================================================
global wm_draw_all
global wm_draw_window

; ============================================================================
; IMPORTS
; ============================================================================
extern wm_windows
extern wm_window_count
extern draw_fill_rect
extern text_draw_string_xy
extern wm_draw_controls

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; wm_draw_all - Draw all visible windows
; ----------------------------------------------------------------------------
wm_draw_all:
    push rbx
    push r12

    cmp dword [wm_window_count], 0
    je .done

    lea rbx, [wm_windows]
    xor r12d, r12d

.loop:
    cmp r12d, WM_MAX_WINDOWS
    jge .done

    ; Skip if not visible or minimized
    mov eax, [rbx + WIN_FLAGS]
    test eax, WIN_FLAG_VISIBLE
    jz .next
    test eax, WIN_FLAG_MINIMIZED
    jnz .next

    mov rdi, rbx
    call wm_draw_window

.next:
    add rbx, WIN_STRUCT_SIZE
    inc r12d
    jmp .loop

.done:
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; wm_draw_window - Draw single window
; Input: RDI = window pointer
; ----------------------------------------------------------------------------
wm_draw_window:
    push rbx
    push r12
    mov rbx, rdi

    ; Check active state
    mov r12d, [rbx + WIN_FLAGS]
    and r12d, WIN_FLAG_ACTIVE

    ; Draw title bar background
    mov edi, [rbx + WIN_X]
    mov esi, [rbx + WIN_Y]
    mov edx, [rbx + WIN_W]
    mov ecx, WIN_TITLE_HEIGHT
    mov r8d, WIN_COLOR_TITLE_BG
    test r12d, r12d
    jz .draw_title
    mov r8d, WIN_COLOR_TITLE_ACTIVE
.draw_title:
    call draw_fill_rect

    ; Draw Mac-style control buttons
    mov edi, [rbx + WIN_X]
    mov esi, [rbx + WIN_Y]
    mov edx, r12d                   ; active flag
    call wm_draw_controls

    ; Draw title text (centered or after controls)
    mov rax, [rbx + WIN_TITLE]
    test rax, rax
    jz .no_title
    mov edi, [rbx + WIN_X]
    add edi, TITLE_TEXT_OFFSET_X
    mov esi, [rbx + WIN_Y]
    add esi, 6
    mov rdx, rax
    mov ecx, WIN_COLOR_TITLE_TEXT
    call text_draw_string_xy
.no_title:

    ; Draw client area
    mov edi, [rbx + WIN_X]
    mov esi, [rbx + WIN_Y]
    add esi, WIN_TITLE_HEIGHT
    mov edx, [rbx + WIN_W]
    mov ecx, [rbx + WIN_H]
    sub ecx, WIN_TITLE_HEIGHT
    mov r8d, WIN_COLOR_BG
    call draw_fill_rect

    ; Call custom draw callback
    mov rax, [rbx + WIN_DRAW_CB]
    test rax, rax
    jz .no_callback
    mov rdi, rbx
    call rax
.no_callback:

    pop r12
    pop rbx
    ret
