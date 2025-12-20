; ============================================================================
; FILES_INPUT.ASM - Input dispatcher
; ============================================================================
; Single Responsibility: Route input to appropriate handler
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_ON_CLICK - Handle click
; Input: EDI = x, ESI = y (relative to content area)
; Output: EAX = 1 if handled
; ============================================================================
wmf_on_click:
    push rbx
    push r12
    push r13

    ; Skip if window not yet drawn (geometry not set)
    cmp dword [wmf_win_w], 0
    je .handled

    ; Convert to absolute coords
    add edi, [wmf_win_x]
    add esi, [wmf_win_y]
    mov r12d, edi
    mov r13d, esi

    ; Route to sidebar
    mov eax, [wmf_win_x]
    add eax, WMF_SIDEBAR_W
    cmp r12d, eax
    jge .check_toolbar

    call wmf_handle_sidebar_click
    jmp .handled

.check_toolbar:
    ; Route to toolbar
    mov eax, [wmf_win_y]
    add eax, WMF_TOOLBAR_H
    cmp r13d, eax
    jge .check_content

    call wmf_handle_toolbar_click
    jmp .handled

.check_content:
    ; Route to content
    call wmf_handle_content_click

.handled:
    mov byte [wm_dirty], 1
    mov eax, 1
    pop r13
    pop r12
    pop rbx
    ret
