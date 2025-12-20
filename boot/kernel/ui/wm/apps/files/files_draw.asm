; ============================================================================
; FILES_DRAW.ASM - Main draw entry point
; ============================================================================
; Single Responsibility: Orchestrate drawing of all Files UI components
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_DRAW_CONTENT - Main draw entry point
; Input: EDI = x, ESI = y, EDX = w, ECX = h
; ============================================================================
wmf_draw_content:
    push r12
    push r13
    push r14
    push r15

    ; Save geometry
    mov [wmf_win_x], edi
    mov [wmf_win_y], esi
    mov [wmf_win_w], edx
    mov [wmf_win_h], ecx

    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15d, ecx

    ; Draw sidebar background
    mov edi, r12d
    mov esi, r13d
    mov edx, WMF_SIDEBAR_W
    mov ecx, r15d
    mov r8d, WMF_COL_SIDEBAR
    call fill_rect

    call wmf_draw_sidebar

    ; Draw toolbar background
    mov edi, r12d
    add edi, WMF_SIDEBAR_W
    mov esi, r13d
    mov edx, r14d
    sub edx, WMF_SIDEBAR_W
    mov ecx, WMF_TOOLBAR_H
    mov r8d, WMF_COL_TOOLBAR
    call fill_rect

    call wmf_draw_toolbar

    ; Draw content background
    mov edi, r12d
    add edi, WMF_SIDEBAR_W
    mov esi, r13d
    add esi, WMF_TOOLBAR_H
    mov edx, r14d
    sub edx, WMF_SIDEBAR_W
    mov ecx, r15d
    sub ecx, WMF_TOOLBAR_H
    mov r8d, WMF_COL_CONTENT
    call fill_rect

    call wmf_draw_files

    pop r15
    pop r14
    pop r13
    pop r12
    ret
