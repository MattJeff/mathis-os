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
    jge .check_content              ; Click is below title bar

    ; In title bar - check if close button (X) clicked
    ; Close button is at: x = win_x + win_w - 20, width = 16
    mov eax, [rbx + WM_ENT_X]
    add eax, [rbx + WM_ENT_W]
    sub eax, 20                     ; Close button X start
    cmp r12d, eax
    jl .start_drag                  ; Not on close button, start drag
    add eax, 16                     ; Close button X end
    cmp r12d, eax
    jge .start_drag                 ; Past close button

    ; Close button clicked!
    mov edi, r14d
    call wm_close_window
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
    jne .try_widget

    ; Files window content click
    mov edi, r12d
    sub edi, [rbx + WM_ENT_X]
    sub edi, 2                  ; Border
    mov esi, r13d
    sub esi, [rbx + WM_ENT_Y]
    sub esi, WM_TITLE_H
    call wmf_on_click
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
; WM_ON_DRAG - Handle mouse drag
; Input: EDI = x, ESI = y
; ============================================================================
wm_on_drag:
    push rbx

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

    mov byte [wm_dirty], 1

.done:
    pop rbx
    ret

; ============================================================================
; WM_ON_RELEASE - Handle mouse release
; ============================================================================
wm_on_release:
    push rbx

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

    ; ESC closes window
    cmp r12d, 0x01
    je .close_focused

    ; Check window type
    mov eax, [rbx + WM_ENT_TYPE]
    cmp eax, WM_TYPE_FILES
    jne .try_widget

    ; Forward to files content
    mov edi, r12d
    call wmf_on_key
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
