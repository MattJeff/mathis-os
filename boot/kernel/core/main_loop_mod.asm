; ============================================================================
; MAIN_LOOP_MOD.ASM - Main Event Loop Module
; ============================================================================
; Main kernel loop: input processing, rendering, buffer flip
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; EXPORTS
; ============================================================================
global kernel_main_loop
global main_loop_running

; ============================================================================
; IMPORTS
; ============================================================================
extern key_pressed
extern wm_on_key
extern desktop_draw
extern video_flip

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; kernel_main_loop - Main kernel event loop
; Never returns (infinite loop)
; ----------------------------------------------------------------------------
kernel_main_loop:
    mov byte [main_loop_running], 1

.loop:
    ; Process keyboard input
    movzx edi, byte [key_pressed]
    test edi, edi
    jz .no_key

    mov byte [key_pressed], 0           ; Clear key
    call wm_on_key

.no_key:
    ; Draw desktop and all windows
    call desktop_draw

    ; Flip back buffer to screen
    call video_flip

    ; Wait for next interrupt (vsync-ish)
    hlt

    jmp .loop

; ============================================================================
; DATA
; ============================================================================
section .data

main_loop_running:  db 0
