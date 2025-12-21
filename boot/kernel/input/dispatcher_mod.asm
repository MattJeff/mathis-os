; ============================================================================
; DISPATCHER_MOD.ASM - Input Event Dispatcher
; ============================================================================
; Routes keyboard events to appropriate handlers based on mode
; Called from main loop, NOT from ISR
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
MODE_GRAPHICS           equ 0
MODE_SHELL              equ 1
MODE_GUI                equ 2
MODE_3D                 equ 3
MODE_FILES              equ 4

; ============================================================================
; EXPORTS
; ============================================================================
global dispatch_input
global get_current_mode
global set_current_mode

; ============================================================================
; IMPORTS
; ============================================================================
extern key_pressed

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; dispatch_input - Process pending key and route to handler
; Input:  RDI = handler table pointer (array of 5 function pointers)
; Output: AL = 1 if key was handled, 0 otherwise
; ----------------------------------------------------------------------------
dispatch_input:
    push rbx
    push rcx
    push rdx

    ; Check if key pending
    mov al, [key_pressed]
    test al, al
    jz .no_key

    ; Get current mode
    movzx ecx, byte [current_mode]
    cmp ecx, MODE_FILES
    ja .no_key

    ; Get handler from table
    mov rdx, [rdi + rcx * 8]
    test rdx, rdx
    jz .no_key

    ; Call handler with scancode in DIL
    mov dil, al
    call rdx

    mov al, 1
    jmp .done

.no_key:
    xor eax, eax

.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; ----------------------------------------------------------------------------
; get_current_mode - Get current input mode
; Output: AL = mode (0-4)
; ----------------------------------------------------------------------------
get_current_mode:
    mov al, [current_mode]
    ret

; ----------------------------------------------------------------------------
; set_current_mode - Set current input mode
; Input: DIL = mode (0-4)
; ----------------------------------------------------------------------------
set_current_mode:
    cmp dil, MODE_FILES
    ja .invalid
    mov [current_mode], dil
.invalid:
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

current_mode:           db MODE_GUI
