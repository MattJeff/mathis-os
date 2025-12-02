; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - DATA MODULE
; Strings, IDT, Variables
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; STRINGS - Right after code, no padding issues
; ════════════════════════════════════════════════════════════════════════════

banner_line1: db " __  __    _  _____ _   _ ___ ____     ___  ____  ", 0
banner_line2: db "|  \/  |  / \|_   _| | | |_ _/ ___|   / _ \/ ___| ", 0
banner_line3: db "| |\/| | / _ \ | | | |_| || |\___ \  | | | \___ \ ", 0
banner_line4: db "| |  | |/ ___ \| | |  _  || | ___) | | |_| |___) |", 0
banner_line5: db "|_|  |_/_/   \_\_| |_| |_|___|____/   \___/|____/ ", 0
banner_line6: db "                                            v3.0  ", 0

msg_info:       db "AI-First OS - Type 'help' for commands", 0
msg_prompt:     db "> ", 0
msg_help:       db "help, clear, fs, compile, runmbc, jarvis", 0
msg_unknown:    db "Unknown command", 0
msg_jarvis:     db "JARVIS> Ready. How can I help?", 0

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

; ════════════════════════════════════════════════════════════════════════════
; SCANCODE TABLE
; ════════════════════════════════════════════════════════════════════════════
scancode_table:
    db 0, 27, '1234567890-=', 8, 9
    db 'qwertyuiop[]', 13, 0
    db 'asdfghjkl', 0x3B, 0x27, '`', 0, '\'
    db 'zxcvbnm,./', 0, '*', 0, ' '
    times 70 db 0

; ════════════════════════════════════════════════════════════════════════════
; EMBEDDED BYTECODE
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
; VARIABLES
; ════════════════════════════════════════════════════════════════════════════
cursor_offset:      dd 0
cmd_length:         dd 0
cmd_buffer:         times 64 db 0
prompt_line:        dd 0
edit_mode:          db 0
file_content_len:   dd 0
file_content:       times 512 db 0

; ════════════════════════════════════════════════════════════════════════════
; IDT - Must be aligned, use explicit address
; ════════════════════════════════════════════════════════════════════════════
align 16
idt_ptr:
    dw 256*8 - 1
    dd idt                  ; Dynamic address

idt:
    times 0x21 dq 0
    ; Keyboard entry (0x21) - keyboard_isr at 0x10200
    dw 0x0200
    dw 0x08
    db 0
    db 0x8E
    dw 0x0001
    times (256-0x22) dq 0

; ════════════════════════════════════════════════════════════════════════════
; PAD TO 64KB - Room for AGI features!
; ════════════════════════════════════════════════════════════════════════════
    times 0x10000 - ($ - $$) db 0
