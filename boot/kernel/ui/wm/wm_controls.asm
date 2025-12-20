; ============================================================================
; WM_CONTROLS.ASM - Window control buttons (macOS style)
; ============================================================================
; Single Responsibility: Draw and handle window control buttons
; ============================================================================

[BITS 64]

; Button colors (macOS traffic lights)
WM_COL_BTN_CLOSE    equ 0x00FF5F56  ; Red - close
WM_COL_BTN_MINIMIZE equ 0x00FFBD2E  ; Yellow - minimize
WM_COL_BTN_MAXIMIZE equ 0x0027C93F  ; Green - maximize
WM_COL_BTN_INACTIVE equ 0x00505050  ; Gray when unfocused

; ============================================================================
; WM_DRAW_CONTROLS - Draw 3 control buttons (close, minimize, maximize)
; Input: R12D = win_x, R13D = win_y, EBX = focused (0/1)
; ============================================================================
wm_draw_controls:
    push r14
    push r15

    ; Button Y position (centered in title bar)
    mov r15d, r13d
    add r15d, WM_BTN_MARGIN_Y

    ; Close button (red) - leftmost
    mov r14d, r12d
    add r14d, WM_BTN_MARGIN_X
    mov edi, r14d
    mov esi, r15d
    mov edx, WM_BTN_SIZE
    mov ecx, WM_BTN_SIZE
    mov r8d, WM_COL_BTN_CLOSE
    test ebx, ebx
    jnz .close_focused
    mov r8d, WM_COL_BTN_INACTIVE
.close_focused:
    call fill_rect

    ; Minimize button (yellow) - middle
    add r14d, WM_BTN_SIZE
    add r14d, WM_BTN_SPACING
    mov edi, r14d
    mov esi, r15d
    mov edx, WM_BTN_SIZE
    mov ecx, WM_BTN_SIZE
    mov r8d, WM_COL_BTN_MINIMIZE
    test ebx, ebx
    jnz .min_focused
    mov r8d, WM_COL_BTN_INACTIVE
.min_focused:
    call fill_rect

    ; Maximize button (green) - rightmost
    add r14d, WM_BTN_SIZE
    add r14d, WM_BTN_SPACING
    mov edi, r14d
    mov esi, r15d
    mov edx, WM_BTN_SIZE
    mov ecx, WM_BTN_SIZE
    mov r8d, WM_COL_BTN_MAXIMIZE
    test ebx, ebx
    jnz .max_focused
    mov r8d, WM_COL_BTN_INACTIVE
.max_focused:
    call fill_rect

    pop r15
    pop r14
    ret

; ============================================================================
; WM_HIT_TEST_CONTROLS - Test if click hits a control button
; Input: EDI = click_x, ESI = click_y, R12D = win_x, R13D = win_y
; Output: EAX = button index (0=close, 1=min, 2=max, -1=none)
; ============================================================================
wm_hit_test_controls:
    push rbx

    ; Check Y range
    mov eax, r13d
    add eax, WM_BTN_MARGIN_Y
    cmp esi, eax
    jl .none
    add eax, WM_BTN_SIZE
    cmp esi, eax
    jge .none

    ; Calculate button X positions
    mov ebx, r12d
    add ebx, WM_BTN_MARGIN_X

    ; Check close button
    cmp edi, ebx
    jl .none
    add ebx, WM_BTN_SIZE
    cmp edi, ebx
    jl .close

    ; Check minimize button
    add ebx, WM_BTN_SPACING
    cmp edi, ebx
    jl .none
    add ebx, WM_BTN_SIZE
    cmp edi, ebx
    jl .minimize

    ; Check maximize button
    add ebx, WM_BTN_SPACING
    cmp edi, ebx
    jl .none
    add ebx, WM_BTN_SIZE
    cmp edi, ebx
    jl .maximize

.none:
    mov eax, -1
    jmp .done
.close:
    xor eax, eax
    jmp .done
.minimize:
    mov eax, 1
    jmp .done
.maximize:
    mov eax, 2
.done:
    pop rbx
    ret

; ============================================================================
; WM_DRAW_RESIZE_HANDLE - Draw resize indicator in bottom-right corner
; Input: R12D = win_x, R13D = win_y, R14D = win_w, R15D = win_h
; ============================================================================
wm_draw_resize_handle:
    push rax
    ; Draw 3 diagonal lines in corner
    mov edi, r12d
    add edi, r14d
    sub edi, 3
    mov esi, r13d
    add esi, r15d
    sub esi, 12
    mov edx, 2
    mov ecx, 10
    mov r8d, 0x00606060
    call fill_rect

    mov edi, r12d
    add edi, r14d
    sub edi, 7
    mov esi, r13d
    add esi, r15d
    sub esi, 8
    mov edx, 2
    mov ecx, 6
    call fill_rect

    mov edi, r12d
    add edi, r14d
    sub edi, 11
    mov esi, r13d
    add esi, r15d
    sub esi, 4
    mov edx, 2
    mov ecx, 2
    call fill_rect

    pop rax
    ret

