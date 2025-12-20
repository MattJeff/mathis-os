; ============================================================================
; MathisOS - GUI Keys Handler
; ============================================================================
; Touches pour le mode GUI (mode 2)
; - Arrows : Deplacer curseur souris
; - Space  : Simuler clic souris
; - Enter  : Executer commande terminal ou clic
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; HANDLE GUI KEYS
; ════════════════════════════════════════════════════════════════════════════
; Entree: al = scancode
; Sortie: al = 1 si handled, 0 sinon
; ════════════════════════════════════════════════════════════════════════════
handle_gui_keys:
    push rbx
    push rcx

    ; ─────────────────────────────────────────────────────────────────────────
    ; TAB (0x0F) - Switch to files mode
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x0F
    je .switch_to_files

    ; ─────────────────────────────────────────────────────────────────────────
    ; Arrow keys - Move mouse cursor
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x48                        ; Up arrow
    je .arrow_up
    cmp al, 0x50                        ; Down arrow
    je .arrow_down
    cmp al, 0x4B                        ; Left arrow
    je .arrow_left
    cmp al, 0x4D                        ; Right arrow
    je .arrow_right

    ; ─────────────────────────────────────────────────────────────────────────
    ; Space (0x39) = Simulate mouse click (if no terminal active)
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x39
    je .check_space

    ; ─────────────────────────────────────────────────────────────────────────
    ; Enter (0x1C) = Execute command or click
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x1C
    je .check_enter

    ; ─────────────────────────────────────────────────────────────────────────
    ; Backspace (0x0E) = Delete char in terminal
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x0E
    je .backspace

    ; ─────────────────────────────────────────────────────────────────────────
    ; Typing - Convert scancode to ASCII for terminal
    ; ─────────────────────────────────────────────────────────────────────────
    jmp .try_typing

; ════════════════════════════════════════════════════════════════════════════
; TAB - Switch to files mode
; ════════════════════════════════════════════════════════════════════════════
.switch_to_files:
    mov byte [mode_flag], 4             ; MODE_FILES
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; ARROW HANDLERS
; ════════════════════════════════════════════════════════════════════════════
.arrow_up:
    cmp word [mouse_y], 5
    jl .handled
    sub word [mouse_y], 5
    jmp .handled

.arrow_down:
    mov ax, word [screen_height]
    sub ax, 15
    cmp word [mouse_y], ax
    jg .handled
    add word [mouse_y], 5
    jmp .handled

.arrow_left:
    cmp word [mouse_x], 5
    jl .handled
    sub word [mouse_x], 5
    jmp .handled

.arrow_right:
    mov ax, word [screen_width]
    sub ax, 13
    cmp word [mouse_x], ax
    jg .handled
    add word [mouse_x], 5
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; SPACE - Click if no terminal
; ════════════════════════════════════════════════════════════════════════════
.check_space:
    ; Check if terminal is active
    movzx rax, byte [active_window]
    cmp al, 0xFF
    je .do_click                        ; No window = click
    shl rax, 5
    cmp byte [windows + rax + 1], 1     ; Type 1 = terminal
    je .not_handled                     ; Terminal active = don't click
.do_click:
    call handle_mouse_click
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; ENTER - Execute or click
; ════════════════════════════════════════════════════════════════════════════
.check_enter:
    movzx rax, byte [active_window]
    cmp al, 0xFF
    je .enter_click                     ; No window = click
    shl rax, 5
    cmp byte [windows + rax + 1], 1     ; Type 1 = terminal
    jne .enter_click                    ; Not terminal = click
    ; Terminal is active, execute command
    call execute_cmd
    jmp .handled
.enter_click:
    call handle_mouse_click
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; BACKSPACE - Delete char in terminal buffer
; ════════════════════════════════════════════════════════════════════════════
.backspace:
    ; Only if terminal active
    movzx rax, byte [active_window]
    cmp al, 0xFF
    je .not_handled
    shl rax, 5
    cmp byte [windows + rax + 1], 1
    jne .not_handled
    ; Delete char
    cmp byte [cmd_pos], 0
    je .handled
    dec byte [cmd_pos]
    movzx rbx, byte [cmd_pos]
    mov byte [cmd_buf + rbx], 0
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; TYPING - Convert scancode to ASCII
; ════════════════════════════════════════════════════════════════════════════
.try_typing:
    ; Only if terminal active
    movzx rcx, byte [active_window]
    cmp cl, 0xFF
    je .not_handled
    shl rcx, 5
    cmp byte [windows + rcx + 1], 1
    jne .not_handled

    ; Convert scancode
    movzx rax, byte [key_pressed]
    cmp al, 58
    jae .not_handled

    ; Check shift state
    cmp byte [shift_state], 1
    je .use_shift
    mov al, [scancode_ascii + rax]
    jmp .got_char
.use_shift:
    mov al, [scancode_shift + rax]

.got_char:
    test al, al
    jz .not_handled

    ; Add to buffer
    movzx rbx, byte [cmd_pos]
    cmp bl, 30
    jae .handled
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
