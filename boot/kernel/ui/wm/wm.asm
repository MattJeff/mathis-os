; ============================================================================
; WM.ASM - Window Manager (main include)
; ============================================================================
; Manages floating windows on the desktop.
; Usage:
;   1. wm_init() - Initialize manager
;   2. wm_create_window(type, x, y, w, h, title) - Create window
;   3. wm_draw_all() - Draw all windows (called each frame)
;   4. wm_on_click(x, y) - Handle clicks
; ============================================================================

[BITS 64]

%include "ui/wm/wm_types.asm"
%include "ui/wm/wm_state.asm"
%include "ui/wm/wm_create.asm"
%include "ui/wm/wm_draw.asm"
%include "ui/wm/wm_input.asm"
%include "ui/wm/wm_taskbar.asm"
%include "ui/wm/apps/wm_files.asm"
%include "ui/wm/apps/wm_editor.asm"
%include "ui/wm/apps/wm_calc.asm"
%include "ui/wm/apps/wm_clock.asm"

; ============================================================================
; WM_INIT - Initialize window manager
; ============================================================================
wm_init:
    cmp byte [wm_initialized], 1
    je .done

    ; Clear window array
    lea rdi, [wm_windows]
    mov ecx, WM_ENT_SIZE * WM_MAX_WINDOWS
    xor eax, eax
    rep stosb

    mov dword [wm_window_count], 0
    mov dword [wm_focused_idx], -1
    mov dword [wm_drag_idx], -1
    mov dword [wm_resize_idx], -1
    mov byte [wm_dirty], 1
    mov byte [wm_initialized], 1

.done:
    ret

; ============================================================================
; WM_HAS_WINDOWS - Check if any windows are open
; Output: EAX = 1 if windows exist
; ============================================================================
wm_has_windows:
    xor eax, eax
    cmp dword [wm_window_count], 0
    je .done
    ; Check if any visible
    push rbx
    push rcx
    mov ecx, [wm_window_count]
.loop:
    dec ecx
    js .none
    mov eax, ecx
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]
    test dword [rbx + WM_ENT_FLAGS], WM_WIN_VISIBLE
    jz .loop
    mov eax, 1
    pop rcx
    pop rbx
    jmp .done
.none:
    xor eax, eax
    pop rcx
    pop rbx
.done:
    ret

; ============================================================================
; WM_GET_WINDOW - Get window entry by index
; Input: EDI = index
; Output: RAX = entry pointer (or 0)
; ============================================================================
wm_get_window:
    cmp edi, [wm_window_count]
    jge .fail
    cmp edi, 0
    jl .fail
    mov eax, edi
    imul eax, WM_ENT_SIZE
    lea rax, [wm_windows + rax]
    ret
.fail:
    xor eax, eax
    ret

; ============================================================================
; WM_SET_WIDGET - Set content widget for window
; Input: EDI = window index, RSI = widget pointer
; ============================================================================
wm_set_widget:
    push rbx

    cmp edi, [wm_window_count]
    jge .done

    mov eax, edi
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]
    mov [rbx + WM_ENT_WIDGET], rsi

    ; Update widget position to window content area
    test rsi, rsi
    jz .done
    mov eax, [rbx + WM_ENT_X]
    add eax, 2                  ; Border
    mov [rsi + W_X], eax
    mov eax, [rbx + WM_ENT_Y]
    add eax, WM_TITLE_H
    mov [rsi + W_Y], eax

.done:
    pop rbx
    ret

; ============================================================================
; WM_SET_CLOSE_CB - Set close callback for window
; Input: EDI = window index, RSI = callback
; ============================================================================
wm_set_close_cb:
    cmp edi, [wm_window_count]
    jge .done
    mov eax, edi
    imul eax, WM_ENT_SIZE
    lea rax, [wm_windows + rax]
    mov [rax + WM_ENT_CLOSE], rsi
.done:
    ret
