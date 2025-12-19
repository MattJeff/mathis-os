; ============================================================================
; MathisOS - Taskbar UI
; ============================================================================
; Elements de la taskbar : clock, process indicator
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; DRAW PROCESS INDICATOR - Shows "Pn" where n = process count
; ════════════════════════════════════════════════════════════════════════════
draw_proc_indicator:
    push rax
    push rbx
    push rdi
    push rsi
    push r8

    ; Save screen position
    mov rbx, rdi

    ; Build string "Pn" in buffer
    mov byte [proc_ind_buf], 'P'

    ; Get process count
    call get_process_count
    add al, '0'
    mov [proc_ind_buf + 1], al
    mov byte [proc_ind_buf + 2], 0

    ; Draw using bitmap font
    mov rdi, rbx
    mov rsi, proc_ind_buf
    mov r8d, COL_TEXT
    call draw_text

    pop r8
    pop rsi
    pop rdi
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW CLOCK - Displays HH:MM using bitmap font
; ════════════════════════════════════════════════════════════════════════════
draw_clock:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8

    ; Save screen position
    mov r8, rdi

    ; Calculate time from ticks (100 ticks/sec)
    mov rax, [tick_count]
    xor rdx, rdx
    mov rbx, 100
    div rbx                         ; rax = seconds total

    xor rdx, rdx
    mov rbx, 60
    div rbx                         ; rax = minutes, rdx = seconds
    push rdx                        ; save seconds

    xor rdx, rdx
    mov rbx, 60
    div rbx                         ; rax = hours, rdx = minutes
    push rdx                        ; save minutes

    ; Hours (mod 24)
    xor rdx, rdx
    mov rbx, 24
    div rbx
    mov rax, rdx                    ; hours = hours % 24

    ; Build time string in clock_buf: "HH:MM"
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov [clock_buf], al             ; H tens
    add dl, '0'
    mov [clock_buf + 1], dl         ; H units

    mov byte [clock_buf + 2], ':'   ; :

    ; Minutes
    pop rax
    xor rdx, rdx
    mov rbx, 10
    div rbx
    add al, '0'
    mov [clock_buf + 3], al         ; M tens
    add dl, '0'
    mov [clock_buf + 4], dl         ; M units

    mov byte [clock_buf + 5], 0     ; Null terminator

    pop rdx                         ; discard seconds

    ; Draw using bitmap font
    mov rdi, r8
    mov rsi, clock_buf
    mov r8d, COL_TEXT
    call draw_text

    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
