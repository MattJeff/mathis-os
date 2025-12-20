; ============================================================================
; WM_RESIZE.ASM - Window resize and maximize logic
; ============================================================================
; Single Responsibility: Handle window resizing and maximize toggle
; ============================================================================

[BITS 64]

; ============================================================================
; WM_TOGGLE_MAXIMIZE - Toggle window maximize/restore
; Uses: RBX = window pointer (from caller), R14D = window index
; ============================================================================
wm_toggle_maximize:
    push rax

    ; Check if already maximized
    test dword [rbx + WM_ENT_FLAGS], WM_WIN_MAXIMIZED
    jnz .restore

    ; Save current position/size
    mov eax, [rbx + WM_ENT_X]
    mov [rbx + WM_ENT_SAVE_X], eax
    mov eax, [rbx + WM_ENT_Y]
    mov [rbx + WM_ENT_SAVE_Y], eax
    mov eax, [rbx + WM_ENT_W]
    mov [rbx + WM_ENT_SAVE_W], eax
    mov eax, [rbx + WM_ENT_H]
    mov [rbx + WM_ENT_SAVE_H], eax

    ; Maximize: full screen (minus taskbar)
    mov dword [rbx + WM_ENT_X], 0
    mov dword [rbx + WM_ENT_Y], 0
    mov eax, [screen_width]
    mov [rbx + WM_ENT_W], eax
    mov eax, [screen_height]
    sub eax, 32                     ; Leave space for taskbar
    mov [rbx + WM_ENT_H], eax

    ; Set maximized flag
    or dword [rbx + WM_ENT_FLAGS], WM_WIN_MAXIMIZED
    jmp .done

.restore:
    ; Restore saved position/size
    mov eax, [rbx + WM_ENT_SAVE_X]
    mov [rbx + WM_ENT_X], eax
    mov eax, [rbx + WM_ENT_SAVE_Y]
    mov [rbx + WM_ENT_Y], eax
    mov eax, [rbx + WM_ENT_SAVE_W]
    mov [rbx + WM_ENT_W], eax
    mov eax, [rbx + WM_ENT_SAVE_H]
    mov [rbx + WM_ENT_H], eax

    ; Clear maximized flag
    and dword [rbx + WM_ENT_FLAGS], ~WM_WIN_MAXIMIZED

.done:
    mov byte [wm_dirty], 1
    pop rax
    ret

; ============================================================================
; WM_DO_RESIZE - Process resize drag
; Input: EDI = mouse_x, ESI = mouse_y
; ============================================================================
wm_do_resize:
    push rbx
    push rcx

    mov eax, [wm_resize_idx]
    cmp eax, -1
    je .done

    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]

    ; Calculate new width: orig_w + (mouse_x - start_x)
    mov eax, edi
    sub eax, [wm_resize_start_x]
    add eax, [wm_resize_orig_w]
    cmp eax, WM_MIN_W
    jge .w_ok
    mov eax, WM_MIN_W
.w_ok:
    mov [rbx + WM_ENT_W], eax

    ; Calculate new height: orig_h + (mouse_y - start_y)
    mov eax, esi
    sub eax, [wm_resize_start_y]
    add eax, [wm_resize_orig_h]
    cmp eax, WM_MIN_H
    jge .h_ok
    mov eax, WM_MIN_H
.h_ok:
    mov [rbx + WM_ENT_H], eax

    ; Clear maximized flag if resizing
    and dword [rbx + WM_ENT_FLAGS], ~WM_WIN_MAXIMIZED

    mov byte [wm_dirty], 1

.done:
    pop rcx
    pop rbx
    ret

; ============================================================================
; WM_END_RESIZE - End resize operation
; ============================================================================
wm_end_resize:
    mov dword [wm_resize_idx], -1
    ret

