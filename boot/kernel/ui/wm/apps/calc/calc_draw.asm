; ============================================================================
; CALC_DRAW.ASM - Calculator drawing functions
; ============================================================================

[BITS 64]

; ============================================================================
; WMC_DRAW_CONTENT - Draw calculator content
; Input: EDI=x, ESI=y, EDX=w, ECX=h
; ============================================================================
wmc_draw_content:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, edi                   ; x
    mov r13d, esi                   ; y
    mov r14d, edx                   ; w
    mov r15d, ecx                   ; h

    ; Draw background
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, r15d
    mov r8d, CALC_BG
    call fill_rect

    ; Draw display
    call wmc_draw_display

    ; Draw buttons
    call wmc_draw_buttons

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WMC_DRAW_DISPLAY - Draw calculator display
; ============================================================================
wmc_draw_display:
    push r12
    push r13

    ; Display background
    mov edi, r12d
    add edi, CALC_MARGIN
    mov esi, r13d
    add esi, CALC_MARGIN
    mov edx, r14d
    sub edx, CALC_MARGIN
    sub edx, CALC_MARGIN
    mov ecx, CALC_DISPLAY_H
    mov r8d, CALC_DISPLAY_BG
    call fill_rect

    ; Display text (right-aligned)
    mov edi, r12d
    add edi, r14d
    sub edi, CALC_MARGIN
    sub edi, 10                     ; Right padding
    mov esi, r13d
    add esi, CALC_MARGIN
    add esi, 18                     ; Center vertically
    lea rdx, [calc_display]
    mov ecx, CALC_DISPLAY_FG
    call video_text

    pop r13
    pop r12
    ret

; ============================================================================
; WMC_DRAW_BUTTONS - Draw all calculator buttons
; ============================================================================
wmc_draw_buttons:
    push rbx
    push r12
    push r13

    ; Button layout (4x5 grid):
    ; C  +/-  %   /
    ; 7   8   9   *
    ; 4   5   6   -
    ; 1   2   3   +
    ; 0       .   =

    mov r12d, r13d
    add r12d, CALC_DISPLAY_H
    add r12d, CALC_MARGIN
    add r12d, CALC_MARGIN           ; r12 = button start Y

    ; Row 0: C, +/-, %, /
    mov edi, 0
    mov esi, 0
    mov edx, 'C'
    mov ecx, CALC_BTN_FUNC
    call wmc_draw_btn
    mov edi, 1
    mov esi, 0
    mov edx, '~'                    ; +/-
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

    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WMC_DRAW_BTN - Draw single button
; Input: EDI=col, ESI=row, EDX=char, ECX=color
; Uses: r12d=base_x from parent, r12d(modified)=button_y
; ============================================================================
wmc_draw_btn:
    push r8
    push r9
    push r10
    push r11

    mov r8d, edi                    ; col
    mov r9d, esi                    ; row
    mov r10d, edx                   ; char
    mov r11d, ecx                   ; color

    ; Calculate X
    mov eax, r8d
    imul eax, CALC_BTN_SIZE
    mov ecx, r8d
    imul ecx, CALC_BTN_GAP
    add eax, ecx
    add eax, [rsp+40]               ; r12d from stack (base x)
    add eax, CALC_MARGIN
    mov edi, eax

    ; Calculate Y
    mov eax, r9d
    imul eax, CALC_BTN_SIZE
    mov ecx, r9d
    imul ecx, CALC_BTN_GAP
    add eax, ecx
    add eax, r12d                   ; button start Y
    mov esi, eax

    ; Draw button background
    mov edx, CALC_BTN_SIZE
    mov ecx, CALC_BTN_SIZE
    mov r8d, r11d
    call fill_rect

    ; Draw character
    push rdi
    push rsi
    add edi, 18                     ; Center X
    add esi, 16                     ; Center Y
    mov [calc_btn_char], r10b
    mov byte [calc_btn_char+1], 0
    lea rdx, [calc_btn_char]
    mov ecx, CALC_BTN_TEXT
    call video_text
    pop rsi
    pop rdi

    pop r11
    pop r10
    pop r9
    pop r8
    ret

; ============================================================================
; WMC_DRAW_BTN_WIDE - Draw wide button (2 columns)
; ============================================================================
wmc_draw_btn_wide:
    push r8
    push r9
    push r10
    push r11

    mov r8d, edi
    mov r9d, esi
    mov r10d, edx
    mov r11d, ecx

    ; Calculate X
    mov eax, r8d
    imul eax, CALC_BTN_SIZE
    mov ecx, r8d
    imul ecx, CALC_BTN_GAP
    add eax, ecx
    add eax, [rsp+40]
    add eax, CALC_MARGIN
    mov edi, eax

    ; Calculate Y
    mov eax, r9d
    imul eax, CALC_BTN_SIZE
    mov ecx, r9d
    imul ecx, CALC_BTN_GAP
    add eax, ecx
    add eax, r12d
    mov esi, eax

    ; Draw wide button (2 * size + gap)
    mov edx, CALC_BTN_SIZE
    add edx, CALC_BTN_SIZE
    add edx, CALC_BTN_GAP
    mov ecx, CALC_BTN_SIZE
    mov r8d, r11d
    call fill_rect

    ; Draw character
    push rdi
    push rsi
    add edi, 42                     ; Center in wide button
    add esi, 16
    mov [calc_btn_char], r10b
    mov byte [calc_btn_char+1], 0
    lea rdx, [calc_btn_char]
    mov ecx, CALC_BTN_TEXT
    call video_text
    pop rsi
    pop rdi

    pop r11
    pop r10
    pop r9
    pop r8
    ret

calc_btn_char: db 0, 0
