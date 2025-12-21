; ============================================================================
; MOUSE_MOD.ASM - PS/2 Mouse Handler Module
; ============================================================================
; Mouse initialization and interrupt handler
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
MOUSE_DATA              equ 0x60
MOUSE_STATUS            equ 0x64
MOUSE_CMD               equ 0x64

PS2_CMD_ENABLE_AUX      equ 0xA8
PS2_CMD_GET_STATUS      equ 0x20
PS2_CMD_SET_STATUS      equ 0x60
PS2_CMD_WRITE_MOUSE     equ 0xD4

MOUSE_CMD_DEFAULTS      equ 0xF6
MOUSE_CMD_ENABLE        equ 0xF4

PIC_EOI                 equ 0x20
PIC_MASTER_CMD          equ 0x20
PIC_SLAVE_CMD           equ 0xA0

CLICK_COOLDOWN_TICKS    equ 15
CURSOR_MARGIN           equ 16

; ============================================================================
; EXPORTS
; ============================================================================
global mouse_init

; ============================================================================
; IMPORTS
; ============================================================================
extern mouse_x
extern mouse_y
extern mouse_buttons
extern mouse_clicked
extern mouse_cycle
extern mouse_byte0
extern mouse_byte1
extern mouse_byte2
extern last_mouse_btn
extern click_cooldown
extern screen_width
extern screen_height

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; mouse_init - Initialize PS/2 mouse
; ----------------------------------------------------------------------------
mouse_init:
    push rax

    ; Enable auxiliary device
    call .wait_write
    mov al, PS2_CMD_ENABLE_AUX
    out MOUSE_CMD, al

    ; Get status byte
    call .wait_write
    mov al, PS2_CMD_GET_STATUS
    out MOUSE_CMD, al
    call .wait_read
    in al, MOUSE_DATA
    or al, 2                        ; Enable IRQ12
    and al, 0xDF                    ; Enable mouse clock
    mov ah, al

    ; Set status byte
    call .wait_write
    mov al, PS2_CMD_SET_STATUS
    out MOUSE_CMD, al
    call .wait_write
    mov al, ah
    out MOUSE_DATA, al

    ; Send "set defaults" to mouse
    call .wait_write
    mov al, PS2_CMD_WRITE_MOUSE
    out MOUSE_CMD, al
    call .wait_write
    mov al, MOUSE_CMD_DEFAULTS
    out MOUSE_DATA, al
    call .wait_read
    in al, MOUSE_DATA               ; ACK

    ; Enable data reporting
    call .wait_write
    mov al, PS2_CMD_WRITE_MOUSE
    out MOUSE_CMD, al
    call .wait_write
    mov al, MOUSE_CMD_ENABLE
    out MOUSE_DATA, al
    call .wait_read
    in al, MOUSE_DATA               ; ACK

    pop rax
    ret

.wait_write:
    in al, MOUSE_STATUS
    test al, 2
    jnz .wait_write
    ret

.wait_read:
    in al, MOUSE_STATUS
    test al, 1
    jz .wait_read
    ret

; Note: mouse_isr64 is in core/isr.asm (compiled separately)
