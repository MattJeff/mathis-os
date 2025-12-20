; ============================================================================
; CLOCK_DRAW.ASM - Clock drawing functions
; ============================================================================

[BITS 64]

; Content position (set by wmclk_draw_content)
clock_content_x:    dd 0
clock_content_y:    dd 0
clock_content_w:    dd 0
clock_content_h:    dd 0

; Time display buffer
clock_time_buf:     times 12 db 0

; ============================================================================
; WMCLK_DRAW_CONTENT - Draw clock content
; Input: EDI=x, ESI=y, EDX=w, ECX=h
; ============================================================================
wmclk_draw_content:
    push rbx
    push r12

    ; Store content position
    mov [clock_content_x], edi
    mov [clock_content_y], esi
    mov [clock_content_w], edx
    mov [clock_content_h], ecx

    ; Update time from RTC
    call rtc_read_time

    ; Draw background
    mov r8d, CLOCK_BG
    call fill_rect

    ; Draw mode button
    call wmclk_draw_mode_btn

    ; Draw based on mode
    cmp byte [clock_mode], CLOCK_MODE_ANALOG
    je .draw_analog
    call wmclk_draw_digital
    jmp .done

.draw_analog:
    call wmclk_draw_analog

.done:
    pop r12
    pop rbx
    ret

; ============================================================================
; WMCLK_DRAW_MODE_BTN - Draw mode toggle button
; ============================================================================
wmclk_draw_mode_btn:
    push rbx

    ; Button at bottom center
    mov edi, [clock_content_x]
    add edi, [clock_content_w]
    shr edi, 1
    sub edi, 30                     ; Center 60px button
    add edi, [clock_content_x]
    shr edi, 1

    mov esi, [clock_content_y]
    add esi, [clock_content_h]
    sub esi, 30

    mov edx, 60
    mov ecx, 20
    mov r8d, 0x00404040
    call fill_rect

    ; Button text
    add edi, 8
    add esi, 4
    cmp byte [clock_mode], CLOCK_MODE_ANALOG
    je .analog_text
    lea rdx, [clock_str_digital]
    jmp .draw_text
.analog_text:
    lea rdx, [clock_str_analog]
.draw_text:
    mov ecx, CLOCK_FG
    call video_text

    pop rbx
    ret

; ============================================================================
; WMCLK_DRAW_DIGITAL - Draw digital time display
; ============================================================================
wmclk_draw_digital:
    push rbx
    push r12
    push r13

    ; Format time string HH:MM:SS
    lea rdi, [clock_time_buf]

    ; Hours
    movzx eax, byte [rtc_hours]
    call wmclk_format_2digit

    mov byte [rdi], ':'
    inc rdi

    ; Minutes
    movzx eax, byte [rtc_minutes]
    call wmclk_format_2digit

    mov byte [rdi], ':'
    inc rdi

    ; Seconds
    movzx eax, byte [rtc_seconds]
    call wmclk_format_2digit

    mov byte [rdi], 0               ; Null terminate

    ; Draw centered time
    mov edi, [clock_content_x]
    mov eax, [clock_content_w]
    shr eax, 1
    add edi, eax
    sub edi, 32                     ; Approx center for 8 chars

    mov esi, [clock_content_y]
    mov eax, [clock_content_h]
    shr eax, 1
    add esi, eax
    sub esi, 8

    lea rdx, [clock_time_buf]
    mov ecx, CLOCK_FG
    call video_text

    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WMCLK_FORMAT_2DIGIT - Format 2-digit number
; Input: EAX = number, RDI = buffer pointer
; Output: RDI advanced by 2
; ============================================================================
wmclk_format_2digit:
    push rbx
    mov ebx, eax

    ; Tens digit
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    mov [rdi], al
    inc rdi

    ; Ones digit
    mov eax, ebx
    xor edx, edx
    mov ecx, 10
    div ecx
    add dl, '0'
    mov [rdi], dl
    inc rdi

    pop rbx
    ret

; ============================================================================
; WMCLK_DRAW_ANALOG - Draw analog clock face
; ============================================================================
wmclk_draw_analog:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Calculate center
    mov r12d, [clock_content_x]
    mov eax, [clock_content_w]
    shr eax, 1
    add r12d, eax                   ; r12 = center_x

    mov r13d, [clock_content_y]
    mov eax, [clock_content_h]
    shr eax, 1
    add r13d, eax
    sub r13d, 10                    ; r13 = center_y (offset for button)

    mov r14d, 70                    ; r14 = radius

    ; Draw clock circle (simple outline)
    call wmclk_draw_circle

    ; Draw hour markers
    call wmclk_draw_markers

    ; Draw hands
    call wmclk_draw_hands

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WMCLK_DRAW_CIRCLE - Draw clock circle outline
; Uses: r12=cx, r13=cy, r14=radius
; ============================================================================
wmclk_draw_circle:
    push rbx

    ; Draw border rectangle as simple circle approximation
    mov edi, r12d
    sub edi, r14d
    mov esi, r13d
    sub esi, r14d
    mov edx, r14d
    shl edx, 1
    mov ecx, edx
    mov r8d, 0x00505050
    call draw_rect

    pop rbx
    ret

; ============================================================================
; WMCLK_DRAW_MARKERS - Draw 12 hour markers
; Uses: r12=cx, r13=cy, r14=radius
; ============================================================================
wmclk_draw_markers:
    push rbx
    push r15

    ; Draw markers at 12, 3, 6, 9 positions
    ; 12 o'clock (top)
    mov edi, r12d
    sub edi, 2
    mov esi, r13d
    sub esi, r14d
    add esi, 5
    mov edx, 4
    mov ecx, 8
    mov r8d, CLOCK_FG
    call fill_rect

    ; 6 o'clock (bottom)
    mov edi, r12d
    sub edi, 2
    mov esi, r13d
    add esi, r14d
    sub esi, 13
    mov edx, 4
    mov ecx, 8
    mov r8d, CLOCK_FG
    call fill_rect

    ; 3 o'clock (right)
    mov edi, r12d
    add edi, r14d
    sub edi, 13
    mov esi, r13d
    sub esi, 2
    mov edx, 8
    mov ecx, 4
    mov r8d, CLOCK_FG
    call fill_rect

    ; 9 o'clock (left)
    mov edi, r12d
    sub edi, r14d
    add edi, 5
    mov esi, r13d
    sub esi, 2
    mov edx, 8
    mov ecx, 4
    mov r8d, CLOCK_FG
    call fill_rect

    pop r15
    pop rbx
    ret

; ============================================================================
; WMCLK_DRAW_HANDS - Draw clock hands
; Uses: r12=cx, r13=cy, r14=radius
; ============================================================================
wmclk_draw_hands:
    push rbx

    ; Draw center dot
    mov edi, r12d
    sub edi, 3
    mov esi, r13d
    sub esi, 3
    mov edx, 6
    mov ecx, 6
    mov r8d, CLOCK_FG
    call fill_rect

    ; Hour hand (short, thick) - simplified
    movzx eax, byte [rtc_hours]
    cmp eax, 12
    jl .hour_ok
    sub eax, 12
.hour_ok:
    mov edi, r12d
    mov esi, r13d
    mov edx, 35                     ; Length
    mov ecx, eax                    ; Hour (0-11)
    mov r8d, CLOCK_HAND_H
    call wmclk_draw_hand

    ; Minute hand (long, thin)
    movzx ecx, byte [rtc_minutes]
    mov edi, r12d
    mov esi, r13d
    mov edx, 55                     ; Length
    mov r8d, CLOCK_HAND_M
    call wmclk_draw_hand_60

    ; Second hand (longest, thinnest)
    movzx ecx, byte [rtc_seconds]
    mov edi, r12d
    mov esi, r13d
    mov edx, 60                     ; Length
    mov r8d, CLOCK_HAND_S
    call wmclk_draw_hand_60

    pop rbx
    ret

; ============================================================================
; WMCLK_DRAW_HAND - Draw hour hand (12 positions)
; Input: EDI=cx, ESI=cy, EDX=len, ECX=hour(0-11), R8D=color
; ============================================================================
wmclk_draw_hand:
    push r12
    push r13
    push r14

    mov r12d, edi                   ; cx
    mov r13d, esi                   ; cy
    mov r14d, edx                   ; length

    ; Calculate end point based on hour (simplified)
    ; Use lookup table for dx, dy per hour
    lea rax, [clock_hour_dx]
    movsx eax, byte [rax + rcx]
    imul eax, r14d
    sar eax, 4                      ; Scale
    add eax, r12d
    mov edi, eax

    lea rax, [clock_hour_dy]
    movsx eax, byte [rax + rcx]
    imul eax, r14d
    sar eax, 4
    add eax, r13d
    mov esi, eax

    ; Draw line as rectangle
    mov edx, 4
    mov ecx, 4
    call fill_rect

    pop r14
    pop r13
    pop r12
    ret

; ============================================================================
; WMCLK_DRAW_HAND_60 - Draw minute/second hand (60 positions)
; Input: EDI=cx, ESI=cy, EDX=len, ECX=minute(0-59), R8D=color
; ============================================================================
wmclk_draw_hand_60:
    push r9
    ; Convert to 12 positions (simplified)
    mov eax, ecx
    xor edx, edx
    mov r9d, 5
    div r9d                         ; 60/5 = 12 positions
    mov ecx, eax
    pop r9
    mov edx, r14d                   ; Restore length (was in edx before div)
    jmp wmclk_draw_hand

; Hour hand direction lookup (dx scaled by 16)
clock_hour_dx: db 0, 4, 8, 11, 8, 4, 0, -4, -8, -11, -8, -4
clock_hour_dy: db -11, -8, -4, 0, 4, 8, 11, 8, 4, 0, -4, -8

clock_str_digital: db "Digital", 0
clock_str_analog:  db "Analog", 0
