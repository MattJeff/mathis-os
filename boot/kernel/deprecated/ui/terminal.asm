; ============================================================================
; MathisOS - Terminal Command Handler
; ============================================================================
; Gestion des commandes terminal
; Ajouter une commande = ajouter un cmp + handler, c'est tout!
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; EXECUTE COMMAND - Parse et execute la commande dans cmd_buf
; ════════════════════════════════════════════════════════════════════════════
execute_cmd:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    ; ─────────────────────────────────────────────────────────────────────────
    ; SYSTEM COMMANDS
    ; ─────────────────────────────────────────────────────────────────────────
    cmp dword [cmd_buf], 'help'
    je .cmd_help
    cmp dword [cmd_buf], 'clea'         ; clear
    je .cmd_clear
    cmp dword [cmd_buf], 'rebo'         ; reboot
    je .cmd_reboot
    cmp dword [cmd_buf], 'halt'
    je .cmd_halt

    ; ─────────────────────────────────────────────────────────────────────────
    ; FILE COMMANDS
    ; ─────────────────────────────────────────────────────────────────────────
    cmp word [cmd_buf], 'ls'
    je .cmd_ls
    cmp word [cmd_buf], 'cd'
    je .cmd_cd
    cmp dword [cmd_buf], 'pwd'
    je .cmd_pwd
    cmp dword [cmd_buf], 'cat '
    je .cmd_cat
    cmp dword [cmd_buf], 'mkdi'         ; mkdir
    je .cmd_mkdir
    cmp dword [cmd_buf], 'touc'         ; touch
    je .cmd_touch

    ; ─────────────────────────────────────────────────────────────────────────
    ; PROCESS COMMANDS
    ; ─────────────────────────────────────────────────────────────────────────
    cmp word [cmd_buf], 'ps'
    je .cmd_ps
    cmp dword [cmd_buf], 'kill'
    je .cmd_kill
    cmp dword [cmd_buf], 'top'
    je .cmd_top

    ; ─────────────────────────────────────────────────────────────────────────
    ; INFO COMMANDS
    ; ─────────────────────────────────────────────────────────────────────────
    cmp dword [cmd_buf], 'vers'         ; version
    je .cmd_version
    cmp dword [cmd_buf], 'upti'         ; uptime
    je .cmd_uptime
    cmp dword [cmd_buf], 'mem'
    je .cmd_mem
    cmp dword [cmd_buf], 'cpu'
    je .cmd_cpu
    cmp dword [cmd_buf], 'date'
    je .cmd_date

    ; ─────────────────────────────────────────────────────────────────────────
    ; FUN COMMANDS
    ; ─────────────────────────────────────────────────────────────────────────
    cmp dword [cmd_buf], 'echo'
    je .cmd_echo
    cmp dword [cmd_buf], 'colo'         ; color
    je .cmd_color
    cmp dword [cmd_buf], 'beep'
    je .cmd_beep

    ; ─────────────────────────────────────────────────────────────────────────
    ; MODE COMMANDS
    ; ─────────────────────────────────────────────────────────────────────────
    cmp dword [cmd_buf], 'gui'
    je .cmd_gui
    cmp dword [cmd_buf], '3d'
    je .cmd_3d
    cmp dword [cmd_buf], 'file'         ; files
    je .cmd_files

    jmp .cmd_unknown

; ════════════════════════════════════════════════════════════════════════════
; SYSTEM COMMANDS
; ════════════════════════════════════════════════════════════════════════════

.cmd_help:
    mov rsi, str_cmd_help
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_clear:
    mov byte [show_result], 0
    jmp .clear_cmd

.cmd_reboot:
    lidt [idt64_null]
    int 0

.cmd_halt:
    cli
    hlt
    jmp .cmd_halt

; ════════════════════════════════════════════════════════════════════════════
; FILE COMMANDS
; ════════════════════════════════════════════════════════════════════════════

.cmd_ls:
    mov rsi, str_cmd_ls
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_cd:
    mov rsi, str_cmd_cd
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_pwd:
    mov rsi, str_cmd_pwd
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_cat:
    mov rsi, str_cmd_cat
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_mkdir:
    mov rsi, str_cmd_mkdir
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_touch:
    mov rsi, str_cmd_touch
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

; ════════════════════════════════════════════════════════════════════════════
; PROCESS COMMANDS
; ════════════════════════════════════════════════════════════════════════════

.cmd_ps:
    ; Show process count
    call get_process_count
    mov rdi, result_buf
    add al, '0'
    mov [rdi], al
    mov byte [rdi + 1], ' '
    mov byte [rdi + 2], 'p'
    mov byte [rdi + 3], 'r'
    mov byte [rdi + 4], 'o'
    mov byte [rdi + 5], 'c'
    mov byte [rdi + 6], 's'
    mov byte [rdi + 7], 0
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_kill:
    ; kill <pid>
    movzx edi, byte [cmd_buf + 5]
    sub edi, '0'
    cmp edi, 0
    jle .kill_failed
    cmp edi, 9
    jg .kill_failed
    call kill_process
    test eax, eax
    jnz .kill_failed
    mov rsi, str_cmd_ok
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd
.kill_failed:
    mov rsi, str_cmd_err
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_top:
    mov rsi, str_cmd_top
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

; ════════════════════════════════════════════════════════════════════════════
; INFO COMMANDS
; ════════════════════════════════════════════════════════════════════════════

.cmd_version:
    mov rsi, str_cmd_version
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_uptime:
    ; Show tick count as uptime
    mov rax, [tick_count]
    mov rbx, 100                    ; ~100 ticks per second
    xor rdx, rdx
    div rbx                         ; rax = seconds
    mov rdi, result_buf
    call int_to_str
    ; Add 's' suffix
    mov byte [rdi], 's'
    mov byte [rdi + 1], 0
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_mem:
    mov rsi, str_cmd_mem
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_cpu:
    mov rsi, str_cmd_cpu
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_date:
    mov rsi, str_cmd_date
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

; ════════════════════════════════════════════════════════════════════════════
; FUN COMMANDS
; ════════════════════════════════════════════════════════════════════════════

.cmd_echo:
    ; Echo text after "echo "
    lea rsi, [cmd_buf + 5]
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_color:
    mov rsi, str_cmd_color
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

.cmd_beep:
    ; PC speaker beep (simple)
    mov al, 0xB6
    out 0x43, al
    mov ax, 1000                    ; Frequency divisor
    out 0x42, al
    mov al, ah
    out 0x42, al
    in al, 0x61
    or al, 3
    out 0x61, al
    ; Beep for a short time
    mov ecx, 100000
.beep_wait:
    nop
    dec ecx
    jnz .beep_wait
    ; Stop beep
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    mov rsi, str_cmd_beep
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1
    jmp .clear_cmd

; ════════════════════════════════════════════════════════════════════════════
; MODE COMMANDS
; ════════════════════════════════════════════════════════════════════════════

.cmd_gui:
    mov byte [mode_flag], 2
    jmp .clear_cmd

.cmd_3d:
    mov byte [mode_flag], 3
    jmp .clear_cmd

.cmd_files:
    mov byte [mode_flag], 4
    jmp .clear_cmd

; ════════════════════════════════════════════════════════════════════════════
; UNKNOWN COMMAND
; ════════════════════════════════════════════════════════════════════════════

.cmd_unknown:
    mov rsi, str_cmd_unknown
    mov rdi, result_buf
    call copy_string
    mov byte [show_result], 1

; ════════════════════════════════════════════════════════════════════════════
; CLEAR COMMAND BUFFER
; ════════════════════════════════════════════════════════════════════════════

.clear_cmd:
    mov rdi, cmd_buf
    mov rcx, 32
    xor al, al
    rep stosb
    mov byte [cmd_pos], 0

    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; HELPER: Copy string (rsi -> rdi)
; ════════════════════════════════════════════════════════════════════════════
copy_string:
    push rax
.copy_loop:
    lodsb
    stosb
    test al, al
    jnz .copy_loop
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; HELPER: Integer to string (rax -> rdi, returns rdi pointing to end)
; ════════════════════════════════════════════════════════════════════════════
int_to_str:
    push rbx
    push rcx
    push rdx

    mov rbx, 10
    xor rcx, rcx                    ; Digit count

.div_loop:
    xor rdx, rdx
    div rbx
    push rdx                        ; Save digit
    inc rcx
    test rax, rax
    jnz .div_loop

.str_loop:
    pop rdx
    add dl, '0'
    mov [rdi], dl
    inc rdi
    dec rcx
    jnz .str_loop

    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; COMMAND STRINGS
; ════════════════════════════════════════════════════════════════════════════
str_cmd_help:    db "help clear ls ps kill ver mem", 0
str_cmd_ls:      db "boot/ readme.txt hello.asm", 0
str_cmd_cd:      db "Changed directory", 0
str_cmd_pwd:     db "/", 0
str_cmd_cat:     db "File content here", 0
str_cmd_mkdir:   db "Directory created", 0
str_cmd_touch:   db "File created", 0
str_cmd_top:     db "CPU: 2% MEM: 45%", 0
str_cmd_version: db "MathisOS v1.0 64-bit", 0
str_cmd_mem:     db "RAM: 128MB free", 0
str_cmd_cpu:     db "x86_64 @ 3.2GHz", 0
str_cmd_date:    db "2024-01-15 12:30", 0
str_cmd_color:   db "Color changed", 0
str_cmd_beep:    db "BEEP!", 0
str_cmd_ok:      db "OK", 0
str_cmd_err:     db "Error", 0
str_cmd_unknown: db "Unknown command", 0
