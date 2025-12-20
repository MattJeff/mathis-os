; ============================================================================
; FILES_INPUT_TOOLBAR.ASM - Toolbar click handling
; ============================================================================
; Single Responsibility: Handle toolbar button clicks
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_HANDLE_TOOLBAR_CLICK - Handle toolbar click
; Uses: r12d = abs_x from wmf_on_click
; ============================================================================
wmf_handle_toolbar_click:
    mov eax, r12d
    sub eax, [wmf_win_x]
    sub eax, WMF_SIDEBAR_W

    ; Back button (10-38)
    cmp eax, 10
    jl .done
    cmp eax, 38
    jle .back

    ; Forward button (42-70)
    cmp eax, 42
    jl .done
    cmp eax, 70
    jle .fwd

    ; NEW button (right side)
    mov ecx, [wmf_win_w]
    sub ecx, WMF_SIDEBAR_W
    sub ecx, 60
    cmp eax, ecx
    jl .done
    add ecx, 50
    cmp eax, ecx
    jg .done
    jmp .new

.back:
    call wmf_history_back
    ret

.fwd:
    call wmf_history_fwd
    ret

.new:
    call wmf_create_folder
    ret

.done:
    ret
