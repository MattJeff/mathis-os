; ============================================================================
; CLOCK_INPUT.ASM - Clock input handling
; ============================================================================

[BITS 64]

; ============================================================================
; WMCLK_ON_KEY - Handle keyboard input
; Input: EDI = scancode
; Output: EAX = 1 if handled
; ============================================================================
wmclk_on_key:
    ; Let ESC pass through for window close
    cmp edi, 0x01
    je .not_handled

    ; Space or M toggles mode
    cmp edi, 0x39                   ; Space
    je .toggle
    cmp edi, 0x32                   ; M key
    je .toggle
    jmp .not_handled

.toggle:
    call wmclk_toggle_mode
    mov eax, 1
    ret

.not_handled:
    xor eax, eax
    ret

; ============================================================================
; WMCLK_ON_CLICK - Handle mouse click
; Input: EDI = x (relative), ESI = y (relative)
; Output: EAX = 1
; ============================================================================
wmclk_on_click:
    push rbx

    ; Check if click is in mode button area (bottom 30 pixels)
    mov eax, [clock_content_h]
    sub eax, 30
    cmp esi, eax
    jl .done

    ; Clicked in button area - toggle mode
    call wmclk_toggle_mode

.done:
    mov byte [wm_dirty], 1
    mov eax, 1
    pop rbx
    ret

; ============================================================================
; WMCLK_UPDATE - Check if display needs refresh (called from main loop)
; ============================================================================
wmclk_update:
    ; Only update if window is open
    cmp dword [clock_win_idx], -1
    je .done

    ; Check if second changed
    call rtc_read_time
    mov al, [rtc_seconds]
    cmp al, [clock_last_sec]
    je .done

    ; Second changed - update display
    mov [clock_last_sec], al
    mov byte [wm_dirty], 1

.done:
    ret
