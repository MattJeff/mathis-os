; ============================================================================
; DESKTOP_INPUT.ASM - Desktop input handling
; ============================================================================
; Single Responsibility: Handle keyboard and mouse input
; ============================================================================

[BITS 64]

; ============================================================================
; DESKTOP_SIMPLE_INPUT - Handle input (windows first, then desktop)
; ============================================================================
desktop_simple_input:
    ; Check if desktop dialog is open
    cmp byte [desktop_dlg_mode], 0
    je .no_dialog
    cmp byte [im_key_ready], 0
    je .check_mouse
    movzx edi, byte [im_key_scancode]
    call desktop_dlg_on_key
    mov byte [im_key_ready], 0
    ret

.no_dialog:
    cmp byte [im_key_ready], 0
    je .no_key
    movzx edi, byte [im_key_scancode]
    call wm_on_key
    test eax, eax
    jnz .key_handled
    ; Desktop shortcuts
    movzx edi, byte [im_key_scancode]
    cmp edi, 0x31               ; N key
    je .open_new_dialog
    jmp .no_key

.open_new_dialog:
    call desktop_dlg_open_new
    mov byte [im_key_ready], 0
    ret

.key_handled:
    mov byte [im_key_ready], 0

.no_key:
.check_mouse:
    cmp dword [wm_drag_idx], -1
    je .no_drag
    test byte [mouse_buttons], 1
    jz .end_drag
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call wm_on_drag
    ret
.end_drag:
    call wm_on_release

.no_drag:
    test byte [mouse_buttons], 1
    jz .no_click
    cmp byte [desktop_click_lock], 1
    je .no_click
    mov byte [desktop_click_lock], 1

    ; Check if click is in taskbar area first
    movzx esi, word [mouse_y]
    mov eax, [screen_height]
    sub eax, DESKTOP_TASKBAR_H
    cmp esi, eax
    jl .not_taskbar
    movzx edi, word [mouse_x]
    call wm_taskbar_click
    test eax, eax
    jnz .done

.not_taskbar:
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call wm_on_click
    test eax, eax
    jnz .done
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call desktop_handle_dicon_click
    test eax, eax
    jnz .done
    call desktop_handle_click
    jmp .done

.no_click:
    test byte [mouse_buttons], 1
    jnz .done
    mov byte [desktop_click_lock], 0

.done:
    ret

desktop_click_lock: db 0

; ============================================================================
; DESKTOP_HANDLE_DICON_CLICK - Handle click on dynamic icon
; Input: EDI = x, ESI = y
; Output: EAX = 1 if handled
; ============================================================================
desktop_handle_dicon_click:
    push rbx
    push r12
    call dicon_hit_test
    cmp eax, -1
    je .not_handled
    mov r12d, eax
    mov edi, r12d
    call dicon_get_entry
    test rax, rax
    jz .not_handled
    mov rbx, rax
    cmp dword [rbx + DICON_ENT_TYPE], 1
    je .open_folder
    ; Type 0 = file, open in editor
    mov rdi, [rbx + DICON_ENT_NAME]
    call desktop_open_file
    jmp .handled
.open_folder:
    mov rdi, [rbx + DICON_ENT_NAME]
    call desktop_open_folder
.handled:
    mov byte [desktop_needs_redraw], 1
    mov eax, 1
    jmp .done
.not_handled:
    xor eax, eax
.done:
    pop r12
    pop rbx
    ret
