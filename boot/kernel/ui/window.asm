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
