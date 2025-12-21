; ============================================================================
; MANAGER_MOD.ASM - Centralized Input Manager
; ============================================================================
; Unified input state and event handling
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
INPUT_EVENT_NONE        equ 0
INPUT_EVENT_KEY         equ 1
INPUT_EVENT_CLICK       equ 2
INPUT_EVENT_MOVE        equ 3

; ============================================================================
; EXPORTS
; ============================================================================
global input_init
global input_update
global input_get_key
global input_get_mouse_x
global input_get_mouse_y
global input_is_clicked
global input_clear_click

; ============================================================================
; IMPORTS
; ============================================================================
extern key_pressed
extern key_scancode
extern mouse_x
extern mouse_y
extern mouse_clicked
extern shift_state

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; input_init - Initialize input manager
; ----------------------------------------------------------------------------
input_init:
    mov byte [input_ready], 1
    ret

; ----------------------------------------------------------------------------
; input_update - Process pending input events
; Called each frame from main loop
; ----------------------------------------------------------------------------
input_update:
    push rax

    ; Check for key event
    mov al, [key_pressed]
    test al, al
    jz .check_mouse
    mov [last_key], al

.check_mouse:
    ; Update last mouse position
    movzx eax, word [mouse_x]
    mov [last_mouse_x], ax
    movzx eax, word [mouse_y]
    mov [last_mouse_y], ax

    pop rax
    ret

; ----------------------------------------------------------------------------
; input_get_key - Get last pressed key
; Output: AL = scancode (0 if none)
; ----------------------------------------------------------------------------
input_get_key:
    mov al, [key_pressed]
    ret

; ----------------------------------------------------------------------------
; input_get_mouse_x - Get mouse X position
; Output: EAX = x coordinate
; ----------------------------------------------------------------------------
input_get_mouse_x:
    movzx eax, word [mouse_x]
    ret

; ----------------------------------------------------------------------------
; input_get_mouse_y - Get mouse Y position
; Output: EAX = y coordinate
; ----------------------------------------------------------------------------
input_get_mouse_y:
    movzx eax, word [mouse_y]
    ret

; ----------------------------------------------------------------------------
; input_is_clicked - Check if mouse was clicked
; Output: AL = 1 if clicked, 0 otherwise
; ----------------------------------------------------------------------------
input_is_clicked:
    mov al, [mouse_clicked]
    ret

; ----------------------------------------------------------------------------
; input_clear_click - Clear click flag
; ----------------------------------------------------------------------------
input_clear_click:
    mov byte [mouse_clicked], 0
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

input_ready:            db 0
last_key:               db 0
last_mouse_x:           dw 0
last_mouse_y:           dw 0
