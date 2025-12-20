; ============================================================================
; WM_CREATE.ASM - Create/destroy windows
; ============================================================================

[BITS 64]

; ============================================================================
; WM_CREATE_WINDOW - Create a new window
; Input: EDI = type, ESI = x, EDX = y, ECX = w, R8D = h, R9 = title
; Output: EAX = window index (-1 on failure)
; ============================================================================
wm_create_window:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rdi
    push rsi
    push rdx
    push rcx
    push r8
    push r9

    ; Check slot availability
    mov r12d, [wm_window_count]
    cmp r12d, WM_MAX_WINDOWS
    jge .fail

    ; Restore params from stack
    pop r9                      ; title
    pop r8                      ; h
    pop rcx                     ; w
    pop rdx                     ; y
    pop rsi                     ; x
    pop rdi                     ; type

    ; Calculate slot address
    mov eax, r12d
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]

    ; Initialize window entry
    mov dword [rbx + WM_ENT_FLAGS], WM_WIN_VISIBLE | WM_WIN_FOCUSED
    mov [rbx + WM_ENT_TYPE], edi
    mov [rbx + WM_ENT_X], esi
    mov [rbx + WM_ENT_Y], edx
    mov [rbx + WM_ENT_W], ecx
    mov [rbx + WM_ENT_H], r8d
    mov [rbx + WM_ENT_TITLE], r9
    mov qword [rbx + WM_ENT_WIDGET], 0
    mov qword [rbx + WM_ENT_CLOSE], 0

    ; Unfocus previous window
    mov eax, [wm_focused_idx]
    cmp eax, -1
    je .no_prev
    imul eax, WM_ENT_SIZE
    lea rax, [wm_windows + rax]
    and dword [rax + WM_ENT_FLAGS], ~WM_WIN_FOCUSED
.no_prev:

    ; Set as focused
    mov [wm_focused_idx], r12d
    inc dword [wm_window_count]
    mov byte [wm_dirty], 1
    mov byte [wm_close_grace], 10   ; 10 frames grace before ESC can close

    mov eax, r12d
    jmp .done

.fail:
    ; Clean up pushed params on failure
    add rsp, 48                 ; 6 * 8 bytes
    mov eax, -1

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WM_CLOSE_WINDOW - Close a window by index
; Input: EDI = window index
; ============================================================================
wm_close_window:
    push rbx
    push rcx

    cmp edi, [wm_window_count]
    jge .done
    cmp edi, 0
    jl .done

    ; Get window entry
    mov eax, edi
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]

    ; Call close callback if set
    mov rax, [rbx + WM_ENT_CLOSE]
    test rax, rax
    jz .no_callback
    push rdi
    call rax
    pop rdi
.no_callback:

    ; Clear flags (mark as closed)
    mov dword [rbx + WM_ENT_FLAGS], 0

    ; If was focused, focus previous
    cmp edi, [wm_focused_idx]
    jne .not_focused
    call wm_focus_prev
.not_focused:

    mov byte [wm_dirty], 1

.done:
    pop rcx
    pop rbx
    ret

; ============================================================================
; WM_FOCUS_PREV - Focus previous visible window
; ============================================================================
wm_focus_prev:
    push rbx
    push rcx

    mov dword [wm_focused_idx], -1
    mov ecx, [wm_window_count]
    test ecx, ecx
    jz .done

.loop:
    dec ecx
    js .done
    mov eax, ecx
    imul eax, WM_ENT_SIZE
    lea rbx, [wm_windows + rax]
    test dword [rbx + WM_ENT_FLAGS], WM_WIN_VISIBLE
    jz .loop
    mov [wm_focused_idx], ecx
    or dword [rbx + WM_ENT_FLAGS], WM_WIN_FOCUSED

.done:
    pop rcx
    pop rbx
    ret
