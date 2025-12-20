; ============================================================================
; CALC_DRAW.ASM - Calculator drawing functions
; ============================================================================

[BITS 64]

; Content area position (set by wmc_draw_content)
calc_content_x:     dd 0
calc_content_y:     dd 0
calc_content_w:     dd 0
calc_btn_char:      db 0, 0

; ============================================================================
; WMC_DRAW_CONTENT - Draw calculator content
; Input: EDI=x, ESI=y, EDX=w, ECX=h
; ============================================================================
wmc_draw_content:
    push rbx
    push r12

    ; Store content area position in globals
    mov [calc_content_x], edi
    mov [calc_content_y], esi
    mov [calc_content_w], edx

    ; Draw background
    mov r8d, CALC_BG
    call fill_rect

    ; Draw display
    call wmc_draw_display

    ; Draw buttons
    call wmc_draw_buttons

    pop r12
    pop rbx
    ret

; ============================================================================
; WMC_DRAW_DISPLAY - Draw calculator display
; ============================================================================
wmc_draw_display:
    push rbx

    ; Display background
    mov edi, [calc_content_x]
    add edi, CALC_MARGIN
    mov esi, [calc_content_y]
    add esi, CALC_MARGIN
    mov edx, [calc_content_w]
    sub edx, CALC_MARGIN * 2
    mov ecx, CALC_DISPLAY_H
    mov r8d, CALC_DISPLAY_BG
    call fill_rect

    ; Display text (left-aligned with padding)
    mov edi, [calc_content_x]
    add edi, CALC_MARGIN
    add edi, 10                     ; Left padding
    mov esi, [calc_content_y]
    add esi, CALC_MARGIN
    add esi, 18                     ; Center vertically
    lea rdx, [calc_display]
    mov ecx, CALC_DISPLAY_FG
    call video_text

    pop rbx
    ret

; ============================================================================
; WMC_DRAW_BUTTONS - Draw all calculator buttons
; ============================================================================
wmc_draw_buttons:
    push rbx

    ; Button layout (4x5 grid):
    ; C  +/-  %   /
    ; 7   8   9   *
    ; 4   5   6   -
    ; 1   2   3   +
    ; 0       .   =

    ; Row 0: C, +/-, %, /
    mov edi, 0
    mov esi, 0
    mov edx, 'C'
    mov ecx, CALC_BTN_FUNC
    call wmc_draw_btn
    mov edi, 1
    mov esi, 0
    mov edx, '~'
    mov ecx, CALC_BTN_FUNC
    call wmc_draw_btn
    mov edi, 2
    mov esi, 0
    mov edx, '%'
    mov ecx, CALC_BTN_FUNC
    call wmc_draw_btn
    mov edi, 3
    mov esi, 0
    mov edx, '/'
    mov ecx, CALC_BTN_OP
    call wmc_draw_btn

    ; Row 1: 7, 8, 9, *
    mov edi, 0
    mov esi, 1
    mov edx, '7'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 1
    mov esi, 1
    mov edx, '8'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 2
    mov esi, 1
    mov edx, '9'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 3
    mov esi, 1
    mov edx, '*'
    mov ecx, CALC_BTN_OP
    call wmc_draw_btn

    ; Row 2: 4, 5, 6, -
    mov edi, 0
    mov esi, 2
    mov edx, '4'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 1
    mov esi, 2
    mov edx, '5'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 2
    mov esi, 2
    mov edx, '6'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 3
    mov esi, 2
    mov edx, '-'
    mov ecx, CALC_BTN_OP
    call wmc_draw_btn

    ; Row 3: 1, 2, 3, +
    mov edi, 0
    mov esi, 3
    mov edx, '1'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 1
    mov esi, 3
    mov edx, '2'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 2
    mov esi, 3
    mov edx, '3'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 3
    mov esi, 3
    mov edx, '+'
    mov ecx, CALC_BTN_OP
    call wmc_draw_btn

    ; Row 4: 0 (wide), ., =
    mov edi, 0
    mov esi, 4
    mov edx, '0'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn_wide
    mov edi, 2
    mov esi, 4
    mov edx, '.'
    mov ecx, CALC_BTN_NUM
    call wmc_draw_btn
    mov edi, 3
    mov esi, 4
    mov edx, '='
    mov ecx, CALC_BTN_OP
    call wmc_draw_btn

    pop rbx
    ret

; ============================================================================
; WMC_DRAW_BTN - Draw single button
; Input: EDI=col, ESI=row, EDX=char, ECX=color
; ============================================================================
wmc_draw_btn:
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13

    mov r10d, edx                   ; char
    mov r11d, ecx                   ; color

    ; Calculate X = base_x + margin + col * (btn_size + gap)
    mov eax, edi
    imul eax, CALC_BTN_SIZE + CALC_BTN_GAP
    add eax, [calc_content_x]
    add eax, CALC_MARGIN
    mov r12d, eax                   ; save X in r12

    ; Calculate Y = base_y + margin*2 + display_h + row * (btn_size + gap)
    mov eax, esi
    imul eax, CALC_BTN_SIZE + CALC_BTN_GAP
    add eax, [calc_content_y]
    add eax, CALC_DISPLAY_H + CALC_MARGIN * 2
    mov r13d, eax                   ; save Y in r13

    ; Draw button background
    mov edi, r12d
    mov esi, r13d
    mov edx, CALC_BTN_SIZE
    mov ecx, CALC_BTN_SIZE
    mov r8d, r11d
    call fill_rect

    ; Draw character centered
    mov edi, r12d
    add edi, 18
    mov esi, r13d
    add esi, 16
    mov [calc_btn_char], r10b
    mov byte [calc_btn_char+1], 0
    lea rdx, [calc_btn_char]
    mov ecx, CALC_BTN_TEXT
    call video_text

    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    ret

; ============================================================================
; WMC_DRAW_BTN_WIDE - Draw wide button (2 columns)
; Input: EDI=col, ESI=row, EDX=char, ECX=color
; ============================================================================
wmc_draw_btn_wide:
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13

    mov r10d, edx                   ; char
    mov r11d, ecx                   ; color

    ; Calculate X
    mov eax, edi
    imul eax, CALC_BTN_SIZE + CALC_BTN_GAP
    add eax, [calc_content_x]
    add eax, CALC_MARGIN
    mov r12d, eax                   ; save X in r12

    ; Calculate Y
    mov eax, esi
    imul eax, CALC_BTN_SIZE + CALC_BTN_GAP
    add eax, [calc_content_y]
    add eax, CALC_DISPLAY_H + CALC_MARGIN * 2
    mov r13d, eax                   ; save Y in r13

    ; Draw wide button (2 * size + gap)
    mov edi, r12d
    mov esi, r13d
    mov edx, CALC_BTN_SIZE * 2 + CALC_BTN_GAP
    mov ecx, CALC_BTN_SIZE
    mov r8d, r11d
    call fill_rect

    ; Draw character centered in wide button
    mov edi, r12d
    add edi, 42
    mov esi, r13d
    add esi, 16
    mov [calc_btn_char], r10b
    mov byte [calc_btn_char+1], 0
    lea rdx, [calc_btn_char]
    mov ecx, CALC_BTN_TEXT
    call video_text

    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    ret
