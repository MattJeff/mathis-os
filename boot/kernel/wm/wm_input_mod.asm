; ============================================================================
; WM_INPUT_MOD.ASM - Window Input Handling
; ============================================================================
; Mouse and keyboard input for windows with Mac-style controls
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
WM_MAX_WINDOWS          equ 8
WIN_STRUCT_SIZE         equ 56
WIN_FLAGS               equ 0
WIN_X                   equ 8
WIN_Y                   equ 12
WIN_W                   equ 16
WIN_H                   equ 20
WIN_INPUT_CB            equ 40
WIN_SAVED_X             equ 48
WIN_SAVED_Y             equ 50
WIN_SAVED_W             equ 52
WIN_SAVED_H             equ 54
WIN_FLAG_VISIBLE        equ 0x01
WIN_FLAG_ACTIVE         equ 0x02
WIN_FLAG_MINIMIZED      equ 0x04
WIN_FLAG_MAXIMIZED      equ 0x08
WIN_FLAG_DRAGGING       equ 0x10
WIN_TITLE_HEIGHT        equ 24

; ============================================================================
; EXPORTS
; ============================================================================
global wm_on_click
global wm_on_drag
global wm_on_key
global wm_find_window_at
global wm_minimize_window
global wm_maximize_window
global wm_restore_window

; ============================================================================
; IMPORTS
; ============================================================================
extern wm_windows
extern wm_window_count
extern wm_active_index
extern wm_drag_offset_x
extern wm_drag_offset_y
extern wm_close_window
extern wm_controls_hit_test
extern desktop_on_click
extern screen_width
extern screen_height
extern files_on_key

; Window types
WIN_TYPE_FILES          equ 4
WIN_TYPE                equ 4

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; wm_on_click - Handle mouse click
; Input: EDI = x, ESI = y
; Output: AL = 1 if handled
; ----------------------------------------------------------------------------
wm_on_click:
    push rbx
    push r12
    push r13

    mov r12d, edi
    mov r13d, esi

    ; Find window under cursor
    call wm_find_window_at
    test rax, rax
    jz .not_handled

    mov rbx, rax

    ; Test control buttons (Mac-style)
    mov edi, r12d
    mov esi, r13d
    mov edx, [rbx + WIN_X]
    mov ecx, [rbx + WIN_Y]
    call wm_controls_hit_test

    cmp eax, 1
    je .do_close
    cmp eax, 2
    je .do_minimize
    cmp eax, 3
    je .do_maximize

    ; Check if title bar (start drag)
    mov eax, [rbx + WIN_Y]
    add eax, WIN_TITLE_HEIGHT
    cmp r13d, eax
    jg .client_area

    ; Start dragging
    or dword [rbx + WIN_FLAGS], WIN_FLAG_DRAGGING
    mov eax, r12d
    sub eax, [rbx + WIN_X]
    mov [wm_drag_offset_x], eax
    mov eax, r13d
    sub eax, [rbx + WIN_Y]
    mov [wm_drag_offset_y], eax
    jmp .handled

.client_area:
    ; Call window input handler
    mov rax, [rbx + WIN_INPUT_CB]
    test rax, rax
    jz .handled
    mov rdi, rbx
    mov esi, r12d
    mov edx, r13d
    call rax
    jmp .handled

.do_close:
    mov rdi, rbx
    call .get_window_index
    mov edi, eax
    call wm_close_window
    jmp .handled

.do_minimize:
    mov rdi, rbx
    call wm_minimize_window
    jmp .handled

.do_maximize:
    mov rdi, rbx
    call wm_maximize_window
    jmp .handled

.handled:
    mov al, 1
    jmp .done

.not_handled:
    mov edi, r12d
    mov esi, r13d
    call desktop_on_click
    mov al, 1

.done:
    pop r13
    pop r12
    pop rbx
    ret

; Get window index from pointer
.get_window_index:
    lea rax, [wm_windows]
    sub rdi, rax
    mov eax, edi
    xor edx, edx
    mov ecx, WIN_STRUCT_SIZE
    div ecx
    ret

; ----------------------------------------------------------------------------
; wm_minimize_window - Minimize window to taskbar
; Input: RDI = window pointer
; ----------------------------------------------------------------------------
wm_minimize_window:
    or dword [rdi + WIN_FLAGS], WIN_FLAG_MINIMIZED
    ret

; ----------------------------------------------------------------------------
; wm_maximize_window - Toggle maximize/restore
; Input: RDI = window pointer
; ----------------------------------------------------------------------------
wm_maximize_window:
    push rbx
    mov rbx, rdi

    test dword [rbx + WIN_FLAGS], WIN_FLAG_MAXIMIZED
    jnz .restore

    ; Save current position
    mov ax, [rbx + WIN_X]
    mov [rbx + WIN_SAVED_X], ax
    mov ax, [rbx + WIN_Y]
    mov [rbx + WIN_SAVED_Y], ax
    mov ax, [rbx + WIN_W]
    mov [rbx + WIN_SAVED_W], ax
    mov ax, [rbx + WIN_H]
    mov [rbx + WIN_SAVED_H], ax

    ; Set to full screen (minus taskbar)
    mov dword [rbx + WIN_X], 0
    mov dword [rbx + WIN_Y], 0
    mov eax, [screen_width]
    mov [rbx + WIN_W], eax
    mov eax, [screen_height]
    sub eax, 32                     ; Taskbar height
    mov [rbx + WIN_H], eax
    or dword [rbx + WIN_FLAGS], WIN_FLAG_MAXIMIZED
    jmp .done

.restore:
    call wm_restore_window

.done:
    pop rbx
    ret

; ----------------------------------------------------------------------------
; wm_restore_window - Restore window from minimized/maximized
; Input: RDI = window pointer
; ----------------------------------------------------------------------------
wm_restore_window:
    push rbx
    mov rbx, rdi

    ; Clear minimized flag
    and dword [rbx + WIN_FLAGS], ~WIN_FLAG_MINIMIZED

    ; Restore from maximized if needed
    test dword [rbx + WIN_FLAGS], WIN_FLAG_MAXIMIZED
    jz .done

    movzx eax, word [rbx + WIN_SAVED_X]
    mov [rbx + WIN_X], eax
    movzx eax, word [rbx + WIN_SAVED_Y]
    mov [rbx + WIN_Y], eax
    movzx eax, word [rbx + WIN_SAVED_W]
    mov [rbx + WIN_W], eax
    movzx eax, word [rbx + WIN_SAVED_H]
    mov [rbx + WIN_H], eax
    and dword [rbx + WIN_FLAGS], ~WIN_FLAG_MAXIMIZED

.done:
    pop rbx
    ret

; ----------------------------------------------------------------------------
; wm_find_window_at - Find window at coordinates
; Input: EDI = x, ESI = y
; Output: RAX = window pointer (0 if none)
; ----------------------------------------------------------------------------
wm_find_window_at:
    push rbx
    push r12

    lea rbx, [wm_windows + (WM_MAX_WINDOWS - 1) * WIN_STRUCT_SIZE]
    mov r12d, WM_MAX_WINDOWS

.loop:
    dec r12d
    js .not_found

    ; Skip if not visible or minimized
    mov eax, [rbx + WIN_FLAGS]
    test eax, WIN_FLAG_VISIBLE
    jz .next
    test eax, WIN_FLAG_MINIMIZED
    jnz .next

    ; Check bounds
    cmp edi, [rbx + WIN_X]
    jl .next
    mov eax, [rbx + WIN_X]
    add eax, [rbx + WIN_W]
    cmp edi, eax
    jge .next
    cmp esi, [rbx + WIN_Y]
    jl .next
    mov eax, [rbx + WIN_Y]
    add eax, [rbx + WIN_H]
    cmp esi, eax
    jge .next

    mov rax, rbx
    jmp .done

.next:
    sub rbx, WIN_STRUCT_SIZE
    jmp .loop

.not_found:
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; wm_on_key - Handle key press
; Input: EDI = scancode
; Output: AL = 1 if handled
; ----------------------------------------------------------------------------
wm_on_key:
    push rbx
    push r12
    mov r12d, edi                       ; save scancode

    ; Get active window
    mov eax, [wm_active_index]
    cmp eax, -1
    je .not_handled
    cmp eax, WM_MAX_WINDOWS
    jge .not_handled

    ; Calculate window pointer
    mov ecx, WIN_STRUCT_SIZE
    imul eax, ecx
    lea rbx, [wm_windows + rax]

    ; Check if visible
    test dword [rbx + WIN_FLAGS], WIN_FLAG_VISIBLE
    jz .not_handled
    test dword [rbx + WIN_FLAGS], WIN_FLAG_MINIMIZED
    jnz .not_handled

    ; Route by window type
    mov eax, [rbx + WIN_TYPE]
    cmp eax, WIN_TYPE_FILES
    je .files_key

    ; No handler for this type
    jmp .not_handled

.files_key:
    mov edi, r12d
    call files_on_key
    mov al, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; wm_on_drag - Handle window dragging
; ----------------------------------------------------------------------------
wm_on_drag:
    ret
