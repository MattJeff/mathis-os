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
