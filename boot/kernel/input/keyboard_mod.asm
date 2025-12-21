; ============================================================================
; KEYBOARD_MOD.ASM - Keyboard Handler Module
; ============================================================================
; PS/2 Keyboard ISR and scancode translation
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
KEYBOARD_DATA           equ 0x60
PIC_EOI                 equ 0x20
PIC_MASTER_CMD          equ 0x20

SCAN_LEFT_SHIFT         equ 0x2A
SCAN_RIGHT_SHIFT        equ 0x36
SCAN_CTRL               equ 0x1D
SCAN_ALT                equ 0x38
KEY_RELEASE_BIT         equ 0x80

; ============================================================================
; EXPORTS
; ============================================================================
global keyboard_isr64
global scancode_to_ascii
global scancode_ascii
global scancode_shift

; ============================================================================
; IMPORTS
; ============================================================================
extern key_pressed
extern key_scancode
extern shift_state
extern ctrl_state
extern alt_state

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; keyboard_isr64 - Keyboard interrupt handler (IRQ1)
; Reads scancode, updates modifiers, stores key event
; ----------------------------------------------------------------------------
keyboard_isr64:
    push rax
    push rbx

    in al, KEYBOARD_DATA
    mov [key_scancode], al

    ; Check release (bit 7 set)
    test al, KEY_RELEASE_BIT
    jnz .handle_release

    ; === KEY PRESS ===
    cmp al, SCAN_LEFT_SHIFT
    je .shift_on
    cmp al, SCAN_RIGHT_SHIFT
    je .shift_on
    cmp al, SCAN_CTRL
    je .ctrl_on
    cmp al, SCAN_ALT
    je .alt_on

    ; Normal key - ignore repeats
    cmp al, [key_pressed]
    je .done

    ; Store new key
    mov [key_pressed], al
    jmp .done

.shift_on:
    mov byte [shift_state], 1
    jmp .done

.ctrl_on:
    mov byte [ctrl_state], 1
    jmp .done

.alt_on:
    mov byte [alt_state], 1
    jmp .done

    ; === KEY RELEASE ===
.handle_release:
    and al, 0x7F
    mov bl, al

    ; Clear key_pressed if this key released
    cmp bl, [key_pressed]
    jne .check_mods
    mov byte [key_pressed], 0

.check_mods:
    cmp bl, SCAN_LEFT_SHIFT
    je .shift_off
    cmp bl, SCAN_RIGHT_SHIFT
    je .shift_off
    cmp bl, SCAN_CTRL
    je .ctrl_off
    cmp bl, SCAN_ALT
    je .alt_off
    jmp .done

.shift_off:
    mov byte [shift_state], 0
    jmp .done

.ctrl_off:
    mov byte [ctrl_state], 0
    jmp .done

.alt_off:
    mov byte [alt_state], 0

.done:
    mov al, PIC_EOI
    out PIC_MASTER_CMD, al
    pop rbx
    pop rax
    iretq

; ----------------------------------------------------------------------------
; scancode_to_ascii - Convert scancode to ASCII
; Input:  DIL = scancode
;         SIL = shift state (0 or 1)
; Output: AL = ASCII character (0 if not printable)
; ----------------------------------------------------------------------------
scancode_to_ascii:
    movzx eax, dil
    cmp al, 58
    jae .invalid

    test sil, sil
    jnz .shifted
    mov al, [scancode_ascii + rax]
    ret

.shifted:
    mov al, [scancode_shift + rax]
    ret

.invalid:
    xor eax, eax
    ret

; ============================================================================
; DATA - Scancode Tables
; ============================================================================
section .rodata

; Normal (unshifted) scancode to ASCII
scancode_ascii:
    db 0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8, 9
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 13, 0
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\'
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '

; Shifted scancode to ASCII
scancode_shift:
    db 0, 27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 8, 9
    db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 13, 0
    db 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0, '|'
    db 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' '
