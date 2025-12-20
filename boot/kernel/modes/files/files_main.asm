; ============================================================================
; MathisOS - File Manager Main (REFACTORED with Widgets + Mouse)
; ============================================================================
; Entry point pour le mode FILES (mode 4)
; Uses widget system for UI + centralized mouse service
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; FILES MODE - Entry point (legacy compatibility)
; ════════════════════════════════════════════════════════════════════════════
; Note: main_loop now calls files_mode_frame directly
; This is kept for any legacy code that jumps here
files_mode:
    call files_mode_frame
    call cursor_draw
    jmp main_loop

; ════════════════════════════════════════════════════════════════════════════
; FILES_MODE_FRAME - Single frame update (returns to caller)
; ════════════════════════════════════════════════════════════════════════════
; Called from main_loop, returns after drawing one frame
; Cursor is drawn by main_loop via input_manager
; ════════════════════════════════════════════════════════════════════════════
files_mode_frame:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; Initialize widgets on first call
    cmp byte [fa_initialized], 1
    je .skip_init
    call files_app_init
.skip_init:

    ; Check for mouse click
    cmp byte [mouse_clicked], 1
    jne .no_click
    mov byte [mouse_clicked], 0     ; Clear flag
    ; Call click handler with mouse position
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    mov edx, 1                      ; Left button
    call files_on_mouse_click
.no_click:

    ; Always redraw (cursor needs clean background)
    call files_app_draw

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Redraw flag
files_needs_redraw: db 1

; Input registration flag
files_input_registered: db 0

; ════════════════════════════════════════════════════════════════════════════
; FILES_ON_KEY - Keyboard handler (called by input_manager)
; Input: EDI = scancode
; ════════════════════════════════════════════════════════════════════════════
files_on_key:
    ; Delegate to existing key handler
    mov esi, edi
    jmp handle_files_keys          ; In handlers/files_keys.asm

; ════════════════════════════════════════════════════════════════════════════
; FILES_ON_CLICK - Click handler (called by input_manager)
; Input: EDI = x, ESI = y, EDX = button
; ════════════════════════════════════════════════════════════════════════════
files_on_click:
    jmp files_on_mouse_click       ; Use existing handler

; ════════════════════════════════════════════════════════════════════════════
; FILES_ON_MOUSE_CLICK - Handle mouse clicks in files mode
; Input: EDI = x, ESI = y, DL = button
; ════════════════════════════════════════════════════════════════════════════
files_on_mouse_click:
    push rbx
    push rcx
    push r12
    push r13

    mov r12d, edi                   ; r12 = x
    mov r13d, esi                   ; r13 = y

    ; Check current state
    mov eax, [fa_state]

    ; If dialog open, check dialog clicks first
    cmp eax, FA_STATE_DIALOG_NEW
    je .check_dialog
    cmp eax, FA_STATE_DIALOG_DEL
    je .check_dialog
    cmp eax, FA_STATE_DIALOG_REN
    je .check_dialog

    ; If editor open, check editor clicks
    cmp eax, FA_STATE_EDITOR
    je .check_editor

    ; List state - check Back button, sidebar, and file list
.check_list:
    ; Check Back button (in header area, left side)
    ; Back button: x=10-70, y=2-22
    cmp r12d, 10
    jl .check_sidebar
    cmp r12d, 70
    jg .check_sidebar
    cmp r13d, 2
    jl .check_sidebar
    cmp r13d, 22
    jg .check_sidebar
    ; Back button clicked - return to desktop
    mov byte [mode_flag], 2
    mov byte [files_needs_redraw], 1      ; Redraw on return
    mov byte [files_input_registered], 0  ; Re-register on next entry
    jmp .done

.check_sidebar:
    ; Check sidebar click (x < SIDEBAR_WIDTH, y > 24)
    cmp r12d, SIDEBAR_WIDTH
    jge .check_file_list
    cmp r13d, 24
    jl .check_file_list
    ; Click in sidebar - forward to sidebar handler
    mov edi, r12d
    mov esi, r13d
    call sidebar_on_click
    test eax, eax
    jz .check_file_list             ; Not handled, try file list
    mov byte [files_needs_redraw], 1
    jmp .done

.check_file_list:
    ; Check if click is in file list area
    mov rdi, [fa_file_list]
    test rdi, rdi
    jz .done
    mov esi, r12d
    mov edx, r13d
    call mouse_svc_hit_test
    test eax, eax
    jz .done

    ; Click is in file list - forward to widget
    mov rdi, [fa_file_list]
    mov esi, r12d                   ; x
    mov edx, r13d                   ; y
    mov ecx, 1                      ; left button
    call file_list_on_click
    mov byte [files_needs_redraw], 1
    jmp .done

.check_dialog:
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .done

    ; Check dialog bounds
    mov esi, r12d
    mov edx, r13d
    call mouse_svc_hit_test
    test eax, eax
    jz .done

    ; Click in dialog - forward to dialog
    mov rdi, [fa_dialog]
    mov esi, r12d
    mov edx, r13d
    call dialog_on_click
    mov byte [files_needs_redraw], 1
    jmp .done

.check_editor:
    ; ESC button in header to close editor
    cmp r12d, 10
    jl .done
    cmp r12d, 70
    jg .done
    cmp r13d, 2
    jl .done
    cmp r13d, 22
    jg .done
    ; Close editor
    mov rdi, [fa_editor]
    test rdi, rdi
    jz .back_to_list_click
    call widget_destroy
    mov qword [fa_editor], 0
.back_to_list_click:
    mov dword [fa_state], FA_STATE_LIST
    mov rdi, [fa_header]
    mov rsi, fa_title_files
    call header_set_title
    mov byte [files_needs_redraw], 1

.done:
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; Include widget-based app controller
%include "modes/files/files_app.asm"

; Legacy data (still needed for some variables)
%include "modes/files/files_data.asm"

; Legacy draw functions (kept for reference, will be removed later)
; %include "modes/files/files_draw.asm"
; %include "modes/files/files_view.asm"
