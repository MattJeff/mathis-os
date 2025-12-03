; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - FILESYSTEM MODULE
; RAM disk at 0x30000
; ════════════════════════════════════════════════════════════════════════════

FS_BASE     equ 0x30000
FS_DIR      equ 0x30200
FS_DATA     equ 0x30A00

fs_command:
    push eax
    push esi
    
    ; Check subcommand at cmd_buffer+3
    cmp dword [cmd_buffer+3], 'init'
    je .fs_init
    cmp dword [cmd_buffer+3], 'list'
    je .fs_list
    cmp dword [cmd_buffer+3], 'writ'
    je .fs_write
    cmp dword [cmd_buffer+3], 'read'
    je .fs_read
    jmp .fs_help

.fs_init:
    call fs_initialize
    call vga_newline
    mov esi, msg_fs_init
    mov ah, 0x0A
    call vga_print_line
    jmp .done

.fs_list:
    call vga_newline
    mov esi, msg_fs_list
    mov ah, 0x0E
    call vga_print_line
    jmp .done

.fs_write:
    call vga_newline
    mov esi, msg_fs_write
    mov ah, 0x0E
    call vga_print_line
    ; Enter edit mode
    mov byte [edit_mode], 1
    mov dword [file_content_len], 0
    ; Clear buffer completely (512 bytes)
    mov edi, file_content
    mov ecx, 512
    xor eax, eax
    rep stosb
    jmp .done

.fs_read:
    call vga_newline
    mov esi, file_content
    cmp byte [esi], 0
    je .fs_empty
    mov ah, 0x0F
    call vga_print_line
    jmp .done
.fs_empty:
    mov esi, msg_fs_empty
    mov ah, 0x07
    call vga_print_line
    jmp .done

.fs_help:
    call vga_newline
    mov esi, msg_fs_help
    mov ah, 0x0E
    call vga_print_line
    jmp .done

.done:
    pop esi
    pop eax
    ret

fs_initialize:
    push eax
    push ecx
    push edi
    
    mov edi, FS_BASE
    mov ecx, 16384
    xor eax, eax
    rep stosd
    
    ; Write magic
    mov edi, FS_BASE
    mov dword [edi], 'MTHS'
    mov word [edi+4], 'FS'
    mov word [edi+6], 1
    
    pop edi
    pop ecx
    pop eax
    ret
