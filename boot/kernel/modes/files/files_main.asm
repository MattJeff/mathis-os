; ============================================================================
; MathisOS - File Manager Main (REFACTORED with Widgets + Mouse)
; ============================================================================
; Entry point pour le mode FILES (mode 4)
; Uses widget system for UI + centralized mouse service
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; FILES MODE - Entry point (called from main_loop)
; ════════════════════════════════════════════════════════════════════════════
files_mode:
    ; Initialize widgets on first call
    call files_app_init

    ; Register mouse handler for this mode (once)
    cmp byte [files_mouse_registered], 1
    je .mouse_ok
    lea rdi, [files_on_mouse_click]
    call mouse_svc_set_handler
    mov byte [files_mouse_registered], 1
.mouse_ok:

    ; Poll for mouse clicks (processed in main loop, not ISR)
    call mouse_svc_poll_click
    test eax, eax
    jnz .force_redraw              ; Click processed, redraw

    ; Check if mouse moved (needs redraw for cursor)
    call mouse_svc_needs_redraw
    test eax, eax
    jnz .force_redraw

    ; Only redraw if dirty flag is set
    cmp byte [files_dirty], 0
    je .skip_draw

.force_redraw:
    mov byte [files_dirty], 0       ; Clear dirty flag

    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; Draw using widget system
    call files_app_draw

    ; Draw cursor on top (centralized)
    call mouse_svc_draw_cursor

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

.skip_draw:
    ; Small delay to reduce CPU usage
    mov ecx, 50000
.delay:
    pause
    dec ecx
    jnz .delay

    jmp main_loop

; Mouse registration flag
files_mouse_registered: db 0

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

    ; List state - check Back button and file list
.check_list:
    ; Check Back button (in header area, left side)
    ; Back button: x=10-70, y=2-22
    cmp r12d, 10
    jl .check_file_list
    cmp r12d, 70
    jg .check_file_list
    cmp r13d, 2
    jl .check_file_list
    cmp r13d, 22
    jg .check_file_list
    ; Back button clicked - return to desktop
    mov byte [mode_flag], 2
    mov byte [gui_needs_redraw], 1
    mov byte [files_mouse_registered], 0  ; Re-register on next entry
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
    mov byte [files_dirty], 1
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
    mov byte [files_dirty], 1
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
    mov byte [files_dirty], 1

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
