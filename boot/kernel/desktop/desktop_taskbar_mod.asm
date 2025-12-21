; ============================================================================
; DESKTOP_TASKBAR_MOD.ASM - Desktop Taskbar
; ============================================================================
; Bottom taskbar with start button, window list, and clock
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
TASKBAR_HEIGHT          equ 40
TASKBAR_COLOR_BG        equ 0x002D2D2D
TASKBAR_COLOR_BTN       equ 0x00404040
TASKBAR_COLOR_BTN_MIN   equ 0x00353535
TASKBAR_COLOR_BTN_ACT   equ 0x00505050
TASKBAR_COLOR_TEXT      equ 0x00FFFFFF
START_BTN_WIDTH         equ 100
WIN_BTN_WIDTH           equ 120
WIN_BTN_GAP             equ 5
WIN_LIST_START_X        equ 115
WM_MAX_WINDOWS          equ 8
WIN_STRUCT_SIZE         equ 56
WIN_FLAGS               equ 0
WIN_TITLE               equ 24
WIN_FLAG_VISIBLE        equ 0x01
WIN_FLAG_ACTIVE         equ 0x02
WIN_FLAG_MINIMIZED      equ 0x04

; ============================================================================
; EXPORTS
; ============================================================================
global desktop_draw_taskbar
global taskbar_on_click
global taskbar_height

; ============================================================================
; IMPORTS
; ============================================================================
extern draw_fill_rect
extern text_draw_string_xy
extern screen_width
extern screen_height
extern wm_windows
extern wm_window_count
extern wm_restore_window

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; desktop_draw_taskbar - Draw taskbar at bottom
; ----------------------------------------------------------------------------
desktop_draw_taskbar:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, [screen_height]
    sub r12d, TASKBAR_HEIGHT

    ; Draw taskbar background
    xor edi, edi
    mov esi, r12d
    mov edx, [screen_width]
    mov ecx, TASKBAR_HEIGHT
    mov r8d, TASKBAR_COLOR_BG
    call draw_fill_rect

    ; Draw start button
    mov edi, 5
    mov esi, r12d
    add esi, 5
    mov edx, START_BTN_WIDTH
    mov ecx, TASKBAR_HEIGHT - 10
    mov r8d, TASKBAR_COLOR_BTN
    call draw_fill_rect

    ; Draw start text
    mov edi, 25
    mov esi, r12d
    add esi, 12
    lea rdx, [str_start]
    mov ecx, TASKBAR_COLOR_TEXT
    call text_draw_string_xy

    ; Draw window list
    call .draw_window_list

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Draw all visible windows in taskbar
.draw_window_list:
    lea rbx, [wm_windows]
    xor r13d, r13d                      ; window index
    mov r14d, WIN_LIST_START_X          ; current x position

.win_loop:
    cmp r13d, WM_MAX_WINDOWS
    jge .win_done

    mov eax, [rbx + WIN_FLAGS]
    test eax, WIN_FLAG_VISIBLE
    jz .win_next

    ; Draw window button
    mov edi, r14d
    mov esi, r12d
    add esi, 5
    mov edx, WIN_BTN_WIDTH
    mov ecx, TASKBAR_HEIGHT - 10
    ; Choose color based on state
    mov r8d, TASKBAR_COLOR_BTN
    test eax, WIN_FLAG_MINIMIZED
    jz .not_min
    mov r8d, TASKBAR_COLOR_BTN_MIN
.not_min:
    test eax, WIN_FLAG_ACTIVE
    jz .not_active
    mov r8d, TASKBAR_COLOR_BTN_ACT
.not_active:
    push r12
    push rbx
    call draw_fill_rect
    pop rbx
    pop r12

    ; Draw window title
    mov edi, r14d
    add edi, 8
    mov esi, r12d
    add esi, 12
    mov rdx, [rbx + WIN_TITLE]
    test rdx, rdx
    jz .no_title
    mov ecx, TASKBAR_COLOR_TEXT
    push r12
    push rbx
    call text_draw_string_xy
    pop rbx
    pop r12
.no_title:

    ; Move to next position
    add r14d, WIN_BTN_WIDTH + WIN_BTN_GAP

.win_next:
    add rbx, WIN_STRUCT_SIZE
    inc r13d
    jmp .win_loop

.win_done:
    ret

; ----------------------------------------------------------------------------
; taskbar_on_click - Handle taskbar click
; Input: EDI = x, ESI = y
; Output: AL = 1 if handled
; ----------------------------------------------------------------------------
taskbar_on_click:
    push rbx
    push r12
    push r13

    mov r12d, edi                       ; save x

    ; Check if in window list area
    cmp r12d, WIN_LIST_START_X
    jl .not_handled

    ; Calculate which window button was clicked
    sub r12d, WIN_LIST_START_X
    mov eax, r12d
    xor edx, edx
    mov ecx, WIN_BTN_WIDTH + WIN_BTN_GAP
    div ecx
    ; eax = button index (but we need to map to visible window)

    ; Find the nth visible window
    lea rbx, [wm_windows]
    xor r13d, r13d                      ; current button index
    mov ecx, WM_MAX_WINDOWS

.find_loop:
    test ecx, ecx
    jz .not_handled
    mov r8d, [rbx + WIN_FLAGS]
    test r8d, WIN_FLAG_VISIBLE
    jz .find_next
    cmp r13d, eax
    je .found
    inc r13d
.find_next:
    add rbx, WIN_STRUCT_SIZE
    dec ecx
    jmp .find_loop

.found:
    ; Restore this window
    mov rdi, rbx
    call wm_restore_window
    mov al, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_start:              db "MathisOS", 0

section .data

taskbar_height:         dd TASKBAR_HEIGHT
