; ============================================================================
; DESKTOP_MOD.ASM - Desktop Entry Point
; ============================================================================
; Main desktop initialization and rendering
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; EXPORTS
; ============================================================================
global desktop_init
global desktop_draw
global desktop_on_click

; ============================================================================
; IMPORTS
; ============================================================================
extern desktop_draw_background
extern desktop_draw_taskbar
extern desktop_draw_icons
extern desktop_icon_click
extern taskbar_on_click
extern taskbar_height
extern wm_init
extern wm_update
extern wm_has_windows
extern calc_open
extern clock_open
extern files_open
extern term_open
extern cursor_draw
extern screen_height

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; desktop_init - Initialize desktop
; ----------------------------------------------------------------------------
desktop_init:
    call wm_init
    mov byte [desktop_ready], 1
    ret

; ----------------------------------------------------------------------------
; desktop_draw - Draw complete desktop
; ----------------------------------------------------------------------------
desktop_draw:
    cmp byte [desktop_ready], 0
    je .done

    ; Draw background
    call desktop_draw_background

    ; Draw icons
    call desktop_draw_icons

    ; Draw taskbar
    call desktop_draw_taskbar

    ; Update window manager
    call wm_update

    ; Draw cursor on top
    call cursor_draw

.done:
    ret

; ----------------------------------------------------------------------------
; desktop_on_click - Handle mouse click
; Input: EDI = x, ESI = y
; ----------------------------------------------------------------------------
desktop_on_click:
    push rbx
    push r12
    push r13

    mov r12d, edi
    mov r13d, esi

    ; Check if click is in taskbar
    mov eax, [screen_height]
    sub eax, [taskbar_height]
    cmp r13d, eax
    jl .check_icons

    ; Handle taskbar click
    mov edi, r12d
    mov esi, r13d
    call taskbar_on_click
    jmp .done

.check_icons:
    ; Check icon click
    mov edi, r12d
    mov esi, r13d
    call desktop_icon_click
    cmp eax, -1
    je .done

    ; Launch app based on type
    mov ebx, eax
    shl ebx, 2
    mov eax, [icon_types + rbx]

    cmp eax, 1
    je .open_calc
    cmp eax, 2
    je .open_clock
    cmp eax, 4
    je .open_files
    cmp eax, 5
    je .open_term
    jmp .done

.open_calc:
    call calc_open
    jmp .done

.open_clock:
    call clock_open
    jmp .done

.open_files:
    call files_open
    jmp .done

.open_term:
    call term_open

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; IMPORTS (data)
; ============================================================================
extern icon_types

; ============================================================================
; DATA
; ============================================================================
section .data

desktop_ready:          db 0
