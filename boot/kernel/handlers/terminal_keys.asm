; ============================================================================
; MathisOS - Terminal Keys Handler
; ============================================================================
; Touches pour le terminal (fenetre type 1)
; - Typing    : Ajouter caractere au buffer
; - Backspace : Supprimer dernier caractere
; - Enter     : Executer commande
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; HANDLE TERMINAL KEYS
; ════════════════════════════════════════════════════════════════════════════
; Entree: al = scancode
; Sortie: al = 1 si handled, 0 sinon
; Note: Appele seulement si terminal window est active
; ════════════════════════════════════════════════════════════════════════════
handle_terminal_keys:
    push rbx
    push rcx

    ; ─────────────────────────────────────────────────────────────────────────
    ; Enter (0x1C) = Execute command
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x1C
    je .do_enter

    ; ─────────────────────────────────────────────────────────────────────────
    ; Backspace (0x0E) = Delete last char
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x0E
    je .do_backspace

    ; ─────────────────────────────────────────────────────────────────────────
    ; Up Arrow (0x48) = Previous command (history)
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x48
    je .do_history_up

    ; ─────────────────────────────────────────────────────────────────────────
    ; Down Arrow (0x50) = Next command (history)
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x50
    je .do_history_down

    ; ─────────────────────────────────────────────────────────────────────────
    ; Typing - Convert and add to buffer
    ; ─────────────────────────────────────────────────────────────────────────
    jmp .do_typing

; ════════════════════════════════════════════════════════════════════════════
; ENTER - Execute command
; ════════════════════════════════════════════════════════════════════════════
.do_enter:
    call execute_cmd
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; BACKSPACE - Delete last character
; ════════════════════════════════════════════════════════════════════════════
.do_backspace:
    cmp byte [cmd_pos], 0
    je .handled                         ; Buffer empty
    dec byte [cmd_pos]
    movzx rbx, byte [cmd_pos]
    mov byte [cmd_buf + rbx], 0
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; HISTORY UP - Previous command (TODO)
; ════════════════════════════════════════════════════════════════════════════
.do_history_up:
    ; TODO: Implement command history
    ; For now, just ignore
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; HISTORY DOWN - Next command (TODO)
; ════════════════════════════════════════════════════════════════════════════
.do_history_down:
    ; TODO: Implement command history
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; TYPING - Convert scancode to ASCII and add to buffer
; ════════════════════════════════════════════════════════════════════════════
.do_typing:
    ; Validate scancode range
    movzx rax, byte [key_pressed]
    cmp al, 58
    jae .not_handled                    ; Invalid scancode

    ; Check shift state for uppercase/symbols
    cmp byte [shift_state], 1
    je .use_shift_table
    mov al, [scancode_ascii + rax]
    jmp .got_char

.use_shift_table:
    mov al, [scancode_shift + rax]

.got_char:
    test al, al
    jz .not_handled                     ; No mapping for this scancode

    ; Check buffer not full
    movzx rbx, byte [cmd_pos]
    cmp bl, 30                          ; Max 30 chars
    jae .handled                        ; Buffer full

    ; Add character to buffer
    mov [cmd_buf + rbx], al
    inc byte [cmd_pos]
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
.handled:
    mov al, 1
    pop rcx
    pop rbx
    ret

.not_handled:
    xor al, al
    pop rcx
    pop rbx
    ret
