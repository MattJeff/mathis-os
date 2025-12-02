; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - SHELL MODULE
; Command handler
; ════════════════════════════════════════════════════════════════════════════

shell_prompt:
    push eax
    push ebx
    push esi
    push edi
    
    mov dword [cursor_offset], 4
    mov dword [cmd_length], 0
    inc dword [prompt_line]
    
    mov esi, msg_prompt
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    mov edi, ebx
    mov ah, 0x0A
    call print_string
    
    pop edi
    pop esi
    pop ebx
    pop eax
    ret

shell_command:
    push eax
    push ebx
    push ecx
    push esi
    push edi
    
    ; Check commands
    cmp dword [cmd_buffer], 'help'
    je .cmd_help
    cmp dword [cmd_buffer], 'clea'
    je .cmd_clear
    cmp word [cmd_buffer], 'fs'
    je .cmd_fs
    cmp dword [cmd_buffer], 'comp'
    je .cmd_compile
    cmp dword [cmd_buffer], 'runm'
    je .cmd_runmbc
    cmp dword [cmd_buffer], 'jarv'
    je .cmd_jarvis
    jmp .cmd_unknown

.cmd_help:
    call vga_newline
    mov esi, msg_help
    mov ah, 0x0E
    call vga_print_line
    jmp .done

.cmd_clear:
    call vga_clear
    mov dword [prompt_line], 0
    jmp .done

.cmd_fs:
    call fs_command
    jmp .done

.cmd_compile:
    call compile_command
    jmp .done

.cmd_runmbc:
    call vm_run
    jmp .done

.cmd_jarvis:
    call jarvis_command
    jmp .done

.cmd_unknown:
    call vga_newline
    mov esi, msg_unknown
    mov ah, 0x0C
    call vga_print_line
    jmp .done

.done:
    call shell_prompt
    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; JARVIS COMMAND (simplified for now)
; ════════════════════════════════════════════════════════════════════════════
jarvis_command:
    call vga_newline
    mov esi, msg_jarvis
    mov ah, 0x0B
    call vga_print_line
    ret
