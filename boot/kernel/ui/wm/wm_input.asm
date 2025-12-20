; ============================================================================
; WM_INPUT.ASM - Window manager input handling
; ============================================================================

[BITS 64]

; ============================================================================
; WM_ON_CLICK - Handle click on windows
; Input: EDI = x, ESI = y
; Output: EAX = 1 if handled
; ============================================================================
wm_on_click:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi               ; r12 = x
    mov r13d, esi               ; r13 = y

    ; Check windows from top to bottom (reverse order)
    mov r14d, [wm_window_count] ; r14 = loop counter (preserved)
    test r14d, r14d
    jz .not_handled

.loop:
    dec r14d
    js .not_handled

    mov eax, r14d
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]

    ; Skip if not visible
    test dword [rbx + WM_ENT_FLAGS], WM_WIN_VISIBLE
    jz .loop

    ; Hit test
    mov eax, [rbx + WM_ENT_X]
    cmp r12d, eax
    jl .loop
    add eax, [rbx + WM_ENT_W]
    cmp r12d, eax
    jge .loop
    mov eax, [rbx + WM_ENT_Y]
    cmp r13d, eax
    jl .loop
    add eax, [rbx + WM_ENT_H]
    cmp r13d, eax
    jge .loop

    ; Hit! Focus this window
    push rbx                        ; Save window pointer (wm_focus_window modifies rbx)
    mov edi, r14d
    call wm_focus_window
    pop rbx                         ; Restore window pointer

    ; Check if click is in title bar (y < win_y + title_h)
    mov eax, [rbx + WM_ENT_Y]
    add eax, WM_TITLE_H
    cmp r13d, eax
    jge .check_resize               ; Click is below title bar

    ; In title bar - check macOS-style control buttons
    mov edi, r12d
    mov esi, r13d
    push r12
    push r13
    push r14
    mov r12d, [rbx + WM_ENT_X]
    mov r13d, [rbx + WM_ENT_Y]
    mov r14d, [rbx + WM_ENT_W]
    call wm_hit_test_controls
    cmp eax, -1
    jne .got_ctrl_btn

    ; Check save button for editor windows
    cmp dword [rbx + WM_ENT_TYPE], WM_TYPE_EDITOR
    jne .no_save_btn
    call wm_hit_test_save
    test eax, eax
    jnz .do_save_btn
.no_save_btn:
    pop r14
    pop r13
    pop r12
    jmp .start_drag                 ; Not on any button

.do_save_btn:
    pop r14
    pop r13
    pop r12
    call wme_save_file
    jmp .handled

.got_ctrl_btn:
    pop r14
    pop r13
    pop r12

    ; Button clicked (but not during grace period)
    cmp byte [wm_close_grace], 0
    jne .start_drag

    ; Handle button: 0=close, 1=minimize, 2=maximize
    test eax, eax
    jz .do_close
    cmp eax, 1
    je .do_minimize
    cmp eax, 2
    je .do_maximize
    jmp .start_drag

.do_close:
    mov edi, r14d
    call wm_close_window
    jmp .handled

.do_minimize:
    ; Minimize: hide window and set minimized flag
    and dword [rbx + WM_ENT_FLAGS], ~WM_WIN_VISIBLE
    or dword [rbx + WM_ENT_FLAGS], WM_WIN_MINIMIZED
    ; Focus previous window
    call wm_focus_prev
    jmp .handled

.do_maximize:
    ; Toggle fullscreen
    call wm_toggle_maximize
    jmp .handled

.check_resize:
    ; Check if click is in resize corner (bottom-right)
    mov eax, [rbx + WM_ENT_X]
    add eax, [rbx + WM_ENT_W]
    sub eax, WM_RESIZE_HANDLE
    cmp r12d, eax
    jl .check_content
    mov eax, [rbx + WM_ENT_Y]
    add eax, [rbx + WM_ENT_H]
    sub eax, WM_RESIZE_HANDLE
    cmp r13d, eax
    jl .check_content
    ; Start resize
    mov [wm_resize_idx], r14d
    mov eax, r12d
    mov [wm_resize_start_x], eax
    mov eax, r13d
    mov [wm_resize_start_y], eax
    mov eax, [rbx + WM_ENT_W]
    mov [wm_resize_orig_w], eax
    mov eax, [rbx + WM_ENT_H]
    mov [wm_resize_orig_h], eax
    jmp .handled

.start_drag:
    ; Start drag
    mov [wm_drag_idx], r14d
    mov eax, r12d
    sub eax, [rbx + WM_ENT_X]
    mov [wm_drag_off_x], eax
    mov eax, r13d
    sub eax, [rbx + WM_ENT_Y]
    mov [wm_drag_off_y], eax
    or dword [rbx + WM_ENT_FLAGS], WM_WIN_DRAGGING
    jmp .handled

.check_content:
    ; Check window type for content handling
    mov eax, [rbx + WM_ENT_TYPE]
    cmp eax, WM_TYPE_FILES
    jne .check_editor_click

    ; Files window content click
    mov edi, r12d
    sub edi, [rbx + WM_ENT_X]
    sub edi, 2                  ; Border
    mov esi, r13d
    sub esi, [rbx + WM_ENT_Y]
    sub esi, WM_TITLE_H
    call wmf_on_click
    jmp .handled

.check_editor_click:
    cmp eax, WM_TYPE_EDITOR
    jne .try_widget

    ; Editor window content click
    mov edi, r12d
    sub edi, [rbx + WM_ENT_X]
    sub edi, 2
    mov esi, r13d
    sub esi, [rbx + WM_ENT_Y]
    sub esi, WM_TITLE_H
    call wme_on_click
    jmp .handled

.try_widget:
    ; Forward to window widget content
    mov rdi, [rbx + WM_ENT_WIDGET]
    test rdi, rdi
    jz .handled
    mov esi, r12d
    mov edx, r13d
    mov ecx, 1
    call widget_on_click

.handled:
    mov byte [wm_dirty], 1
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WM_ON_DRAG - Handle mouse drag (move or resize)
; Input: EDI = x, ESI = y
; ============================================================================
wm_on_drag:
    push rbx

    ; Check if resizing
    cmp dword [wm_resize_idx], -1
    je .check_drag
    call wm_do_resize
    jmp .done

.check_drag:
    mov eax, [wm_drag_idx]
    cmp eax, -1
    je .done

    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]

    ; Update position
    mov eax, edi
    sub eax, [wm_drag_off_x]
    mov [rbx + WM_ENT_X], eax

    mov eax, esi
    sub eax, [wm_drag_off_y]
    mov [rbx + WM_ENT_Y], eax

    ; Clear maximized if dragging
    and dword [rbx + WM_ENT_FLAGS], ~WM_WIN_MAXIMIZED

    mov byte [wm_dirty], 1

.done:
    pop rbx
    ret

; ============================================================================
; WM_ON_RELEASE - Handle mouse release
; ============================================================================
wm_on_release:
    push rbx

    ; End resize if active
    cmp dword [wm_resize_idx], -1
    je .check_drag
    call wm_end_resize

.check_drag:
    mov eax, [wm_drag_idx]
    cmp eax, -1
    je .done

    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]
    and dword [rbx + WM_ENT_FLAGS], ~WM_WIN_DRAGGING

    mov dword [wm_drag_idx], -1

.done:
    pop rbx
    ret

; ============================================================================
; WM_FOCUS_WINDOW - Focus a window by index
; Input: EDI = window index
; ============================================================================
wm_focus_window:
    push rbx
    push rcx

    ; Unfocus current
    mov eax, [wm_focused_idx]
    cmp eax, -1
    je .set_new
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]
    and dword [rbx + WM_ENT_FLAGS], ~WM_WIN_FOCUSED

.set_new:
    mov [wm_focused_idx], edi
    mov eax, edi
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]
    or dword [rbx + WM_ENT_FLAGS], WM_WIN_FOCUSED

    pop rcx
    pop rbx
    ret

; ============================================================================
; WM_ON_KEY - Forward key to focused window
; Input: EDI = scancode
; Output: EAX = 1 if handled
; ============================================================================
wm_on_key:
    push rbx
    push r12

    mov r12d, edi               ; Save scancode

    mov eax, [wm_focused_idx]
    cmp eax, -1
    je .not_handled

    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]

    ; ESC closes window (but not during grace period)
    cmp r12d, 0x01
    jne .not_esc
    cmp byte [wm_close_grace], 0
    jne .not_handled              ; Still in grace period, ignore ESC
    jmp .close_focused
.not_esc:

    ; Check window type
    mov eax, [rbx + WM_ENT_TYPE]
    cmp eax, WM_TYPE_FILES
    jne .check_editor_key

    ; Forward to files content
    mov edi, r12d
    call wmf_on_key
    jmp .done

.check_editor_key:
    cmp eax, WM_TYPE_EDITOR
    jne .try_widget

    ; Forward to editor
    mov edi, r12d
    call wme_on_key
    jmp .done

.try_widget:
    ; Forward to widget
    mov rdi, [rbx + WM_ENT_WIDGET]
    test rdi, rdi
    jz .not_handled
    mov esi, r12d
    call widget_on_key
    jmp .done

.close_focused:
    mov edi, [wm_focused_idx]
    call wm_close_window
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

; Include resize/maximize logic
%include "ui/wm/wm_resize.asm"
