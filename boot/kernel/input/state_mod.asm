; ============================================================================
; STATE_MOD.ASM - Input State Variables
; ============================================================================
; Centralized storage for keyboard and mouse state
; No code - data only module
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; EXPORTS
; ============================================================================
global key_pressed
global key_scancode
global key_buffer
global key_buffer_head
global key_buffer_tail

global mouse_x
global mouse_y
global mouse_buttons
global mouse_clicked
global mouse_cycle
global mouse_byte0
global mouse_byte1
global mouse_byte2
global last_mouse_btn
global click_cooldown

global shift_state
global ctrl_state
global alt_state

; ============================================================================
; CONSTANTS
; ============================================================================
KEY_BUFFER_SIZE         equ 16

; ============================================================================
; DATA
; ============================================================================
section .data

; Keyboard state
key_pressed:            db 0        ; Last key pressed (ASCII)
key_scancode:           db 0        ; Last raw scancode

; Modifier states
shift_state:            db 0        ; Shift key held
ctrl_state:             db 0        ; Ctrl key held
alt_state:              db 0        ; Alt key held

; Mouse state
mouse_x:                dw 0        ; Current X position
mouse_y:                dw 0        ; Current Y position
mouse_buttons:          db 0        ; Button state (bit 0=left, 1=right, 2=middle)
mouse_clicked:          db 0        ; Click event flag
mouse_cycle:            db 0        ; PS/2 packet byte counter (0-2)
mouse_byte0:            db 0        ; PS/2 packet byte 0
mouse_byte1:            db 0        ; PS/2 packet byte 1
mouse_byte2:            db 0        ; PS/2 packet byte 2
last_mouse_btn:         db 0        ; Previous button state (for edge detection)
click_cooldown:         dd 0        ; Click debounce counter

; ============================================================================
; BSS
; ============================================================================
section .bss

; Keyboard buffer (circular)
key_buffer:             resb KEY_BUFFER_SIZE
key_buffer_head:        resb 1
key_buffer_tail:        resb 1
