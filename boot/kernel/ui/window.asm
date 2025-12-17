; ============================================================================
; MathisOS - Window Manager
; ============================================================================
; Gestion des fenetres (creation, dessin, clicks)
; - open_window      : Ouvrir une nouvelle fenetre
; - check_window_clicks : Gerer les clics sur fenetres
; - draw_windows     : Dessiner toutes les fenetres
; - draw_terminal_window : Dessiner le contenu terminal
; ============================================================================

; Window structure (32 bytes per window):
; Offset 0:  db active (0=inactive, 1=active)
; Offset 1:  db type (1=terminal, 2=files, 3=3D)
; Offset 2:  dw x
; Offset 4:  dw y
; Offset 6:  dw width
; Offset 8:  dw height
; Offset 10-31: reserved

; ════════════════════════════════════════════════════════════════════════════
; OPEN WINDOW - edi=type, esi=x, edx=y
; ════════════════════════════════════════════════════════════════════════════
open_window:
    push rax
    push rbx
    push rcx

    ; Find empty slot
    xor ecx, ecx
.find_slot:
    cmp ecx, MAX_WINDOWS
    jge .no_slot

    mov eax, ecx
    shl eax, 5
    cmp byte [windows + rax], 0
    je .found_slot
    inc ecx
    jmp .find_slot

.found_slot:
    lea rbx, [windows + rax]

    ; Setup window
    mov byte [rbx], 1               ; flags = open
    mov byte [rbx + 1], dil         ; type
    mov word [rbx + 2], si          ; x
    mov word [rbx + 4], dx          ; y
    mov word [rbx + 6], 120         ; width
    mov word [rbx + 8], 80          ; height

    ; Set title based on type
    cmp dil, 1
    jne .not_term
    mov qword [rbx + 16], str_win_terminal
    jmp .title_done
.not_term:
    cmp dil, 2
    jne .not_files
    mov qword [rbx + 16], str_win_files
    jmp .title_done
.not_files:
    mov qword [rbx + 16], str_win_3d
.title_done:

    mov [active_window], cl

.no_slot:
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; CHECK WINDOW CLICKS
; ════════════════════════════════════════════════════════════════════════════
check_window_clicks:
    push rax
    push rbx
    push rcx
    push rdx
    push r12

    movzx eax, word [mouse_x]
    movzx ebx, word [mouse_y]

    ; Check each window (reverse order for z-order)
    mov r12d, MAX_WINDOWS - 1

.check_win_loop:
    cmp r12d, 0
    jl .no_window_hit

    mov ecx, r12d
    shl ecx, 5
    lea rdx, [windows + rcx]

    ; Skip if not open
    cmp byte [rdx], 0
    je .next_win

    ; Get window bounds
    movzx ecx, word [rdx + 2]       ; win_x
    cmp eax, ecx
    jl .next_win

    movzx esi, word [rdx + 6]       ; win_w
    add esi, ecx
    cmp eax, esi
    jg .next_win

    movzx esi, word [rdx + 4]       ; win_y
    cmp ebx, esi
    jl .next_win

    movzx edi, word [rdx + 8]       ; win_h
    add edi, esi
    cmp ebx, edi
    jg .next_win

    ; Hit! Set as active
    mov [active_window], r12b

    ; Check close button
    movzx ecx, word [rdx + 2]
    movzx esi, word [rdx + 6]
    add ecx, esi
    sub ecx, 12                     ; Close button x
    cmp eax, ecx
    jl .not_close
    movzx esi, word [rdx + 4]
    add esi, 2
    cmp ebx, esi
    jl .not_close
    add esi, 10
    cmp ebx, esi
    jg .not_close

    ; Close window
    mov byte [rdx], 0
    mov byte [active_window], 0xFF
    jmp .win_check_done

.not_close:
    ; Could add drag handling here
    jmp .win_check_done

.next_win:
    dec r12d
    jmp .check_win_loop

.no_window_hit:
    mov byte [active_window], 0xFF

.win_check_done:
    pop r12
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAW WINDOWS
; ════════════════════════════════════════════════════════════════════════════
draw_windows:
    push rbx
    push r12
    push r13
    push r14
    push r15

    xor r12, r12                    ; Window index

.window_loop:
    cmp r12, MAX_WINDOWS
    jge .windows_done

    ; Get window pointer
    mov rax, r12
    shl rax, 5                      ; * 32 bytes per window
    lea rbx, [windows + rax]

    ; Check if window is open
    cmp byte [rbx], 0               ; flags byte
    je .next_window

    ; Get window coords
    movzx r13, word [rbx + 2]       ; x
    movzx r14, word [rbx + 4]       ; y
    movzx r15, word [rbx + 6]       ; width
    movzx rax, word [rbx + 8]       ; height

    ; Draw shadow
    push rax
    mov edi, r13d
    add edi, 3
    mov esi, r14d
    add esi, 3
    mov edx, r15d
    mov ecx, eax
    mov r8d, COL_SHADOW
    call fill_rect
    pop rax

    ; Draw window background
    mov edi, r13d
    mov esi, r14d
    mov edx, r15d
    mov ecx, eax
    mov r8d, COL_WINDOW
    call fill_rect

    ; Draw border
    mov edi, r13d
    mov esi, r14d
    mov edx, r15d
    mov ecx, eax
    mov r8d, COL_BORDER
    call draw_rect

    ; Draw titlebar
    mov edi, r13d
    inc edi
    mov esi, r14d
    inc esi
    mov edx, r15d
    sub edx, 2
    mov ecx, TITLEBAR_H
    ; Check if active
    cmp r12b, [active_window]
    jne .inactive_title
    mov r8d, COL_TITLEBAR
    jmp .draw_title
.inactive_title:
    mov r8d, COL_TITLE_INACT
.draw_title:
    call fill_rect

    ; Draw window title: (x+4, y+3)
    mov rdi, [screen_fb]
    mov eax, r14d
    add eax, 3
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, r13
    add rdi, 4
    mov rsi, [rbx + 16]             ; title pointer
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; Draw close button (X)
    mov eax, r13d
    add eax, r15d
    sub eax, 12
    mov edi, eax
    mov esi, r14d
    add esi, 2
    mov edx, 10
    mov ecx, 10
    mov r8d, COL_CLOSE_BTN
    call fill_rect
    ; Draw X at (x + width - 9, y + 4)
    mov rdi, [screen_fb]
    mov eax, r14d
    add eax, 4
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, r13
    add rdi, r15
    sub rdi, 9
    mov rsi, str_x
    mov r8d, COL_TEXT_WHITE
    call draw_text

    ; Draw window content based on type
    movzx eax, byte [rbx + 1]       ; type
    cmp al, 1
    je .draw_terminal_content
    cmp al, 2
    je .draw_files_content
    cmp al, 3
    je .draw_3d_content
    jmp .next_window

.draw_terminal_content:
    call draw_terminal_window
    jmp .next_window

.draw_files_content:
    call draw_files_window
    jmp .next_window

.draw_3d_content:
    call draw_3d_window
    jmp .next_window

.next_window:
    inc r12
    jmp .window_loop

.windows_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
