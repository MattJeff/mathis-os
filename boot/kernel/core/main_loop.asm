; ════════════════════════════════════════════════════════════════════════════
; MAIN_LOOP.ASM - Main dispatch loop for all modes
; ════════════════════════════════════════════════════════════════════════════
; Modes:
;   0 = graphics_mode (legacy)
;   1 = shell_mode (text shell)
;   2 = gui_mode (desktop)
;   3 = gui3d_mode (3D interface)
;   4 = files_mode (file manager)
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; MAIN LOOP - Dispatches to appropriate mode handler
; ════════════════════════════════════════════════════════════════════════════
main_loop:
    ; Process keyboard events (event-driven system)
    call process_input

    ; Dispatch based on mode_flag
    cmp byte [mode_flag], 4
    je files_mode
    cmp byte [mode_flag], 3
    je gui3d_mode
    cmp byte [mode_flag], 2
    je gui_mode
    cmp byte [mode_flag], 1
    je shell_mode
    jmp graphics_mode

; ════════════════════════════════════════════════════════════════════════════
; 3D GUI MODE - Revolutionary 3D Navigation Interface
; ════════════════════════════════════════════════════════════════════════════
gui3d_mode:
    ; Reset screen center (might be corrupted by other modes)
    push rax
    mov eax, [screen_width]
    shr eax, 1
    mov [screen_centerx], eax
    mov eax, [screen_height]
    shr eax, 1
    mov [screen_centery], eax
    ; Also reset camera position directly (extra safety)
    mov dword [camera_x], 0
    mov dword [camera_y], 0
    mov dword [camera_z], 0x00050000  ; z = 5.0
    pop rax

    ; Initialize 3D engine
    call ui3d_init

    ; Enter 3D main loop
    call ui3d_main

    ; When ui3d_main returns, mode_flag was already changed
    jmp main_loop
