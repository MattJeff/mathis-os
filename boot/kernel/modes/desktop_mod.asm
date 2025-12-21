; ============================================================================
; DESKTOP_MOD.ASM - Desktop Mode Module
; ============================================================================
; Simple desktop with background, taskbar, and basic icons
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
DESKTOP_BG_COLOR        equ 0x003366AA  ; Blue background
TASKBAR_HEIGHT          equ 40
TASKBAR_COLOR           equ 0x002D2D2D  ; Dark gray
ICON_SIZE               equ 48
ICON_SPACING            equ 80
ICON_START_X            equ 20
ICON_START_Y            equ 20

; ============================================================================
; EXPORTS
; ============================================================================
global desktop_init
global desktop_draw
global desktop_handle_click

; ============================================================================
; IMPORTS
; ============================================================================
extern screen_fb
extern screen_width
extern screen_height
extern screen_pitch
extern draw_fill_rect
extern text_draw_string_xy
extern mouse_x
extern mouse_y

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; desktop_init - Initialize desktop mode
; ----------------------------------------------------------------------------
desktop_init:
    cmp byte [desktop_ready], 1
    je .done
    mov byte [desktop_ready], 1
.done:
    ret

; ----------------------------------------------------------------------------
; desktop_draw - Draw complete desktop
; ----------------------------------------------------------------------------
desktop_draw:
    call desktop_draw_background
    call desktop_draw_taskbar
    call desktop_draw_icons
    ret

; ----------------------------------------------------------------------------
; desktop_draw_background - Fill screen with background color
; ----------------------------------------------------------------------------
desktop_draw_background:
    push rdi
    push rsi
    push rdx
    push rcx
    push r8

    xor edi, edi
    xor esi, esi
    mov edx, [screen_width]
    mov ecx, [screen_height]
    sub ecx, TASKBAR_HEIGHT
    mov r8d, DESKTOP_BG_COLOR
    call draw_fill_rect

    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    ret

; ----------------------------------------------------------------------------
; desktop_draw_taskbar - Draw taskbar at bottom
; ----------------------------------------------------------------------------
desktop_draw_taskbar:
    push rdi
    push rsi
    push rdx
    push rcx
    push r8

    xor edi, edi
    mov esi, [screen_height]
    sub esi, TASKBAR_HEIGHT
    mov edx, [screen_width]
    mov ecx, TASKBAR_HEIGHT
    mov r8d, TASKBAR_COLOR
    call draw_fill_rect

    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    ret

; ----------------------------------------------------------------------------
; desktop_draw_icons - Draw desktop icons
; ----------------------------------------------------------------------------
desktop_draw_icons:
    push rdi
    push rsi
    push rdx
    push rcx
    push r8

    ; Icon 1: Terminal
    mov edi, ICON_START_X
    mov esi, ICON_START_Y
    mov edx, ICON_SIZE
    mov ecx, ICON_SIZE
    mov r8d, 0x00444444
    call draw_fill_rect

    ; Label
    mov edi, ICON_START_X
    mov esi, ICON_START_Y
    add esi, ICON_SIZE
    add esi, 4
    lea rdx, [str_terminal]
    mov ecx, 0x00FFFFFF
    call text_draw_string_xy

    ; Icon 2: Files
    mov edi, ICON_START_X
    mov esi, ICON_START_Y
    add esi, ICON_SPACING
    mov edx, ICON_SIZE
    mov ecx, ICON_SIZE
    mov r8d, 0x00886622
    call draw_fill_rect

    mov edi, ICON_START_X
    mov esi, ICON_START_Y
    add esi, ICON_SPACING
    add esi, ICON_SIZE
    add esi, 4
    lea rdx, [str_files]
    mov ecx, 0x00FFFFFF
    call text_draw_string_xy

    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    ret

; ----------------------------------------------------------------------------
; desktop_handle_click - Handle mouse click
; Input: EDI = x, ESI = y
; Output: AL = 1 if handled
; ----------------------------------------------------------------------------
desktop_handle_click:
    xor eax, eax
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

desktop_ready:          db 0
str_terminal:           db "Terminal", 0
str_files:              db "Files", 0
