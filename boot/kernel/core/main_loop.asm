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
    ; Legacy event processing (keyboard/mouse hardware)
    call evt_process
    call process_input

    ; Update input manager (dispatches to mode handlers)
    call input_manager_update

    ; Dispatch to mode (call, not jmp - so we return here for cursor)
    cmp byte [mode_flag], 4
    je .mode_files
    cmp byte [mode_flag], 3
    je .mode_3d
    cmp byte [mode_flag], 2
    je .mode_desktop
    cmp byte [mode_flag], 1
    je .mode_shell
    jmp .mode_graphics

.mode_files:
    call files_mode_frame
    jmp .draw_cursor

.mode_3d:
    jmp gui3d_mode              ; 3D has its own cursor

.mode_desktop:
    ; Initialize simple desktop
    call desktop_simple_init
    ; Always handle input (desktop_simple_input has its own click detection)
    call desktop_simple_input
    ; Clear mouse_clicked flag if set
    mov byte [mouse_clicked], 0
    ; Decrement close grace (must run every frame, not just on redraw)
    cmp byte [wm_close_grace], 0
    je .no_grace_dec
    dec byte [wm_close_grace]
.no_grace_dec:
    ; Only redraw if dirty (check both desktop and wm flags)
    cmp byte [desktop_needs_redraw], 1
    je .do_desktop_draw
    cmp byte [wm_dirty], 1
    je .do_desktop_draw
    jmp .draw_cursor
.do_desktop_draw:
    call desktop_simple_draw
    mov byte [desktop_needs_redraw], 0
    call cursor_invalidate          ; Background changed, invalidate cursor cache
    jmp .draw_cursor

.mode_shell:
    jmp shell_mode              ; Shell is text-only, no cursor

.mode_graphics:
    jmp graphics_mode           ; Legacy mode

.draw_cursor:
    ; Draw cursor on top of everything (for modes that return here)
    call cursor_draw

    ; Small delay
    mov ecx, 50000
.delay:
    pause
    dec ecx
    jnz .delay

    jmp main_loop

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_DRAW_FRAME - Draw one frame of desktop (returns to caller)
; ════════════════════════════════════════════════════════════════════════════
desktop_draw_frame:
    push rax
    push rdx
    push rcx
    push rdi
    push rsi
    push r8

    ; Draw blue background
    mov edi, 0
    mov esi, 0
    mov edx, [screen_width]
    mov ecx, [screen_height]
    mov r8d, 0x00305080             ; Teal blue (RGB)
    call fill_rect

    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rdx
    pop rax
    ret

; Legacy entry point (for compatibility)
desktop_mode_simple:
    call desktop_draw_frame
    call cursor_draw
    jmp main_loop

; Desktop input registration flag
desktop_input_registered: db 0
; Desktop redraw flag (1 = needs redraw)
desktop_needs_redraw: db 1

; ────────────────────────────────────────────────────────────────────────────
; DESKTOP_ON_KEY - Key handler for desktop (called by input_manager)
; Input: EDI = scancode
; ────────────────────────────────────────────────────────────────────────────
desktop_on_key:
    ; Handle TAB for mode switching
    cmp edi, 0x0F                   ; TAB scancode
    jne .not_tab
    mov byte [mode_flag], 4         ; Switch to files mode
    mov byte [desktop_input_registered], 0  ; Re-register on return
    ret
.not_tab:
    ret

; ────────────────────────────────────────────────────────────────────────────
; DESKTOP_ON_CLICK - Click handler for desktop (called by input_manager)
; Input: EDI = x, ESI = y, EDX = button
; ────────────────────────────────────────────────────────────────────────────
desktop_on_click:
    ; Use simple desktop click handler
    call desktop_handle_click
    ret

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
