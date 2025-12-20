; ============================================================================
; DESKTOP_INPUT.ASM - Desktop input handling
; ============================================================================
; Single Responsibility: Handle keyboard and mouse input
; ============================================================================

[BITS 64]

; State for icon drag detection
dicon_click_start_x:    dw 0
dicon_click_start_y:    dw 0
dicon_click_idx:        dd -1       ; Icon clicked (for drag or open)
DICON_DRAG_THRESHOLD    equ 5       ; Pixels before drag starts

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
    ; Check window drag first
    cmp dword [wm_drag_idx], -1
    je .check_icon_drag
    test byte [mouse_buttons], 1
    jz .end_wm_drag
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call wm_on_drag
    ret
.end_wm_drag:
    call wm_on_release
    jmp .check_click

.check_icon_drag:
    ; Check if dragging an icon
    call dicon_is_dragging
    test eax, eax
    jz .check_pending_drag

    ; Currently dragging icon
    test byte [mouse_buttons], 1
    jz .end_icon_drag
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call dicon_update_drag
    ret

.end_icon_drag:
    call dicon_end_drag
    mov byte [desktop_click_lock], 0
    ret

.check_pending_drag:
    ; Check if we have a pending click that might become drag
    cmp dword [dicon_click_idx], -1
    je .check_click

    test byte [mouse_buttons], 1
    jz .release_pending

    ; Mouse still down, check if moved enough to start drag
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    movzx eax, word [dicon_click_start_x]
    sub edi, eax
    ; Absolute value
    test edi, edi
    jns .x_pos
    neg edi
.x_pos:
    movzx eax, word [dicon_click_start_y]
    sub esi, eax
    test esi, esi
    jns .y_pos
    neg esi
.y_pos:
    add edi, esi                ; Total movement
    cmp edi, DICON_DRAG_THRESHOLD
    jl .done                    ; Not moved enough, wait

    ; Start actual drag
    mov edi, [dicon_click_idx]
    movzx esi, word [mouse_x]
    movzx edx, word [mouse_y]
    call dicon_start_drag
    mov dword [dicon_click_idx], -1
    ret

.release_pending:
    ; Released without much movement = click to open
    mov edi, [dicon_click_idx]
    call dicon_open_by_idx
    mov dword [dicon_click_idx], -1
    mov byte [desktop_click_lock], 0
    ret

.check_click:
    test byte [mouse_buttons], 1
    jz .no_click
    cmp byte [desktop_click_lock], 1
    je .done
    mov byte [desktop_click_lock], 1

    ; Check taskbar first
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
    ; Check windows
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call wm_on_click
    test eax, eax
    jnz .done

    ; Check dynamic icons (start potential drag)
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call dicon_hit_test
    cmp eax, -1
    je .check_static

    ; Clicked on dynamic icon - store for potential drag
    mov [dicon_click_idx], eax
    mov ax, [mouse_x]
    mov [dicon_click_start_x], ax
    mov ax, [mouse_y]
    mov [dicon_click_start_y], ax
    jmp .done

.check_static:
    ; Check static icons (Terminal, Files, Calc)
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
; DICON_OPEN_BY_IDX - Open icon by index
; Input: EDI = icon index
; ============================================================================
dicon_open_by_idx:
    push rbx

    call dicon_get_entry
    test rax, rax
    jz .done
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

.done:
    pop rbx
    ret
