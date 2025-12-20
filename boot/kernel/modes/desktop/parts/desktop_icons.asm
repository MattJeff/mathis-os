; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_ICONS.ASM - Draw desktop icons
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_DRAW_ICONS - Draw Terminal and Files icons
; ════════════════════════════════════════════════════════════════════════════
desktop_draw_icons:
    push rax
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    ; ═══════════════════════════════════════════════════════════════════════
    ; Terminal icon at (30, 30)
    ; ═══════════════════════════════════════════════════════════════════════
    ; Icon background (dark rectangle)
    mov edi, 30
    mov esi, 30
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00202020             ; Dark gray
    call fill_rect

    ; Icon border
    mov edi, 30
    mov esi, 30
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00808080             ; Gray border
    call draw_rect

    ; Terminal symbol (white rectangle inside)
    mov edi, 38
    mov esi, 38
    mov edx, 32
    mov ecx, 24
    mov r8d, 0x00000000             ; Black
    call fill_rect
    mov edi, 40
    mov esi, 40
    mov edx, 28
    mov ecx, 20
    mov r8d, 0x00FFFFFF             ; White inside
    call fill_rect

    ; Label "Terminal"
    mov rdi, [screen_fb]
    mov eax, 30 + DESKTOP_ICON_SIZE + 4   ; y below icon
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 20 * 4                 ; x = 20
    lea rsi, [desktop_str_terminal]
    mov r8d, 0x00FFFFFF
    call draw_text

    ; ═══════════════════════════════════════════════════════════════════════
    ; Files icon at (30, 120)
    ; ═══════════════════════════════════════════════════════════════════════
    ; Icon background
    mov edi, 30
    mov esi, 120
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00806020             ; Brown/orange
    call fill_rect

    ; Icon border
    mov edi, 30
    mov esi, 120
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00C09030             ; Lighter border
    call draw_rect

    ; Folder tab (top part)
    mov edi, 32
    mov esi, 124
    mov edx, 20
    mov ecx, 8
    mov r8d, 0x00C09030
    call fill_rect

    ; Label "Files"
    mov rdi, [screen_fb]
    mov eax, 120 + DESKTOP_ICON_SIZE + 4
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 30 * 4
    lea rsi, [desktop_str_files]
    mov r8d, 0x00FFFFFF
    call draw_text

    ; ═══════════════════════════════════════════════════════════════════════
    ; Calculator icon at (30, 210)
    ; ═══════════════════════════════════════════════════════════════════════
    ; Icon background (gray)
    mov edi, 30
    mov esi, 210
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00404040
    call fill_rect

    ; Icon border
    mov edi, 30
    mov esi, 210
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00606060
    call draw_rect

    ; Display area (green)
    mov edi, 36
    mov esi, 216
    mov edx, 36
    mov ecx, 12
    mov r8d, 0x0030A030
    call fill_rect

    ; Button grid (orange buttons)
    mov edi, 36
    mov esi, 232
    mov edx, 8
    mov ecx, 8
    mov r8d, 0x00FF9500
    call fill_rect
    mov edi, 48
    mov esi, 232
    mov edx, 8
    mov ecx, 8
    mov r8d, 0x00505050
    call fill_rect
    mov edi, 60
    mov esi, 232
    mov edx, 8
    mov ecx, 8
    mov r8d, 0x00505050
    call fill_rect

    ; Label "Calc"
    mov rdi, [screen_fb]
    mov eax, 210 + DESKTOP_ICON_SIZE + 4
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 34 * 4
    lea rsi, [desktop_str_calc]
    mov r8d, 0x00FFFFFF
    call draw_text

    ; ═══════════════════════════════════════════════════════════════════════
    ; Clock icon at (30, 300)
    ; ═══════════════════════════════════════════════════════════════════════
    ; Icon background (dark blue)
    mov edi, 30
    mov esi, 300
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00203050
    call fill_rect

    ; Icon border
    mov edi, 30
    mov esi, 300
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00405080
    call draw_rect

    ; Clock face (circle approximation)
    mov edi, 38
    mov esi, 308
    mov edx, 32
    mov ecx, 32
    mov r8d, 0x00FFFFFF
    call fill_rect

    ; Clock hands (simple lines)
    mov edi, 52
    mov esi, 324
    mov edx, 2
    mov ecx, 12
    mov r8d, 0x00000000
    call fill_rect
    mov edi, 54
    mov esi, 318
    mov edx, 8
    mov ecx, 2
    mov r8d, 0x00000000
    call fill_rect

    ; Label "Clock"
    mov rdi, [screen_fb]
    mov eax, 300 + DESKTOP_ICON_SIZE + 4
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 30 * 4
    lea rsi, [desktop_icon_clock]
    mov r8d, 0x00FFFFFF
    call draw_text

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret

desktop_str_calc: db "Calc", 0
desktop_icon_clock: db "Clock", 0
