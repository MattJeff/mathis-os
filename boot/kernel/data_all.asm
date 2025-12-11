; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - DATA MODULE (ALL DATA IN ONE PLACE)
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; SECTION 1: STRINGS (messages affichés)
; ════════════════════════════════════════════════════════════════════════════

banner_line1: db " __  __    _  _____ _   _ ___ ____     ___  ____  ", 0
banner_line2: db "|  \/  |  / \|_   _| | | |_ _/ ___|   / _ \/ ___| ", 0
banner_line3: db "| |\/| | / _ \ | | | |_| || |\___ \  | | | \___ \ ", 0
banner_line4: db "| |  | |/ ___ \| | |  _  || | ___) | | |_| |___) |", 0
banner_line5: db "|_|  |_/_/   \_\_| |_| |_|___|____/   \___/|____/ ", 0
banner_line6: db "                                            v3.2  ", 0

msg_info:       db "AI-First OS - Type 'help' for commands", 0
msg_prompt:     db "> ", 0
msg_help:       db "help, clear, fs, go64, reboot", 0
msg_unknown:    db "Unknown command", 0
msg_jarvis:     db "JARVIS> Ready. How can I help?", 0
msg_go64:       db "Entering 64-bit Long Mode...", 0
msg_reboot:     db "Rebooting...", 0

msg_fs_help:    db "fs: init, list, write, read", 0
msg_fs_init:    db "Filesystem initialized (64KB RAM disk)", 0
msg_fs_list:    db "Files: (use 'fs write' to create)", 0
msg_fs_write:   db "Edit mode - Type code, ESC to save:", 0
msg_fs_empty:   db "(no content - use 'fs write')", 0
msg_file_saved: db "Saved! Use 'compile' to build.", 0

msg_compiling:  db "Compiling...", 0
msg_compiled:   db "Success! Use 'runmbc' to run.", 0
msg_no_content: db "No code. Use 'fs write' first.", 0

msg_vm_running: db "Executing bytecode...", 0
msg_vm_done:    db "VM: Execution complete", 0
msg_vm_error:   db "VM: Error - invalid bytecode", 0
msg_result:     db "Result: ", 0

msg_mem_title:  db "=== MEMORY INFO ===", 0
msg_mem_e820:   db "E820 Map: Detected at boot", 0
msg_mem_paging: db "Paging: Ready for 64-bit", 0

; Graphics messages
msg_no_vesa:    db "VESA not available - Text mode only", 0
msg_vesa_ok:    db "VESA 3D Graphics initialized", 0
msg_3d_demo:    db "Running 3D demo...", 0

; ════════════════════════════════════════════════════════════════════════════
; SECTION 2: TABLES (scancode, etc.)
; ════════════════════════════════════════════════════════════════════════════

scancode_table:
    db 0, 27, '1234567890-=', 8, 9
    db 'qwertyuiop[]', 13, 0
    db 'asdfghjkl', 0x3B, 0x27, '`', 0, '\'
    db 'zxcvbnm,./', 0, '*', 0, ' '
    times 70 db 0

shift_table:
    db 0, 27, '!@#$%^&*()_+', 8, 9
    db 'QWERTYUIOP{}', 13, 0
    db 'ASDFGHJKL:"~', 0, '|'
    db 'ZXCVBNM<>?', 0, '*', 0, ' '
    times 70 db 0

; ════════════════════════════════════════════════════════════════════════════
; SECTION 3: EMBEDDED BYTECODE
; ════════════════════════════════════════════════════════════════════════════

embedded_program:
    db 'M', 'A', 'S', 'M'
    db 1, 0, 0, 0
    times 0x38 db 0
    db 0x17, 42
    db 0x17, 58
    db 0x30
    db 0x68
embedded_program_end:

; ════════════════════════════════════════════════════════════════════════════
; SECTION 4: IDT
; ════════════════════════════════════════════════════════════════════════════

align 16
idt_ptr:
    dw 256*8 - 1
    dd idt

idt:
    times 0x21 dq 0
    dw 0x0000
    dw 0x08
    db 0
    db 0x8E
    dw 0x0000
    times (256-0x22) dq 0

; Null IDT for triple fault reboot
null_idt:
    dw 0
    dd 0

; ════════════════════════════════════════════════════════════════════════════
; SECTION 5: VARIABLES À ADRESSES FIXES (0x1F000)
; Ces variables ne bougent JAMAIS
; ════════════════════════════════════════════════════════════════════════════

; Pad jusqu'à 0xF000 (offset dans le kernel)
times 0xF000 - ($ - $$) db 0

; Variables à adresse fixe 0x1F000
cursor_offset:      dd 4
cmd_length:         dd 0
cmd_buffer:         times 64 db 0
prompt_line:        dd 9
edit_mode:          db 0
file_content_len:   dd 0
file_content:       times 512 db 0
shift_state:        db 0
ctrl_state:         db 0
alt_state:          db 0

; Scancode to ASCII (uppercase/shifted)
scancode_shift:
    db 0, 0, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 0, 0
    db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 0, 0
    db 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0, '|'
    db 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '

KERNEL_END:
