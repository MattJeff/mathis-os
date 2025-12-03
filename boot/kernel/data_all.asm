; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - DATA MODULE (ALL DATA IN ONE PLACE)
; ════════════════════════════════════════════════════════════════════════════
; RÈGLE: Tout le code est AVANT ce fichier, toutes les données sont ICI
; On peut ajouter des strings/variables ici sans casser le code
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; SECTION 1: STRINGS (messages affichés)
; ════════════════════════════════════════════════════════════════════════════

; Banner
banner_line1: db " __  __    _  _____ _   _ ___ ____     ___  ____  ", 0
banner_line2: db "|  \/  |  / \|_   _| | | |_ _/ ___|   / _ \/ ___| ", 0
banner_line3: db "| |\/| | / _ \ | | | |_| || |\___ \  | | | \___ \ ", 0
banner_line4: db "| |  | |/ ___ \| | |  _  || | ___) | | |_| |___) |", 0
banner_line5: db "|_|  |_/_/   \_\_| |_| |_|___|____/   \___/|____/ ", 0
banner_line6: db "                                            v3.2  ", 0

; Shell messages
msg_info:       db "AI-First OS - Type 'help' for commands", 0
msg_prompt:     db "> ", 0
msg_help:       db "help, clear, fs, compile, runmbc, jarvis, go64", 0
msg_unknown:    db "Unknown command", 0
msg_jarvis:     db "JARVIS> Ready. How can I help?", 0
msg_go64:       db "Entering 64-bit Long Mode...", 0

; FS messages
msg_fs_help:    db "fs: init, list, write, read", 0
msg_fs_init:    db "Filesystem initialized (64KB RAM disk)", 0
msg_fs_list:    db "Files: (use 'fs write' to create)", 0
msg_fs_write:   db "Edit mode - Type code, ESC to save:", 0
msg_fs_empty:   db "(no content - use 'fs write')", 0
msg_file_saved: db "Saved! Use 'compile' to build.", 0

; Compiler messages
msg_compiling:  db "Compiling...", 0
msg_compiled:   db "Success! Use 'runmbc' to run.", 0
msg_no_content: db "No code. Use 'fs write' first.", 0

; VM messages
msg_vm_running: db "Executing bytecode...", 0
msg_vm_done:    db "VM: Execution complete", 0
msg_vm_error:   db "VM: Error - invalid bytecode", 0
msg_result:     db "Result: ", 0

; Memory messages (for future use)
msg_mem_title:  db "=== MEMORY INFO ===", 0
msg_mem_e820:   db "E820 Map: Detected at boot", 0
msg_mem_paging: db "Paging: Ready for 64-bit", 0

; ════════════════════════════════════════════════════════════════════════════
; SECTION 2: VARIABLES (état du système)
; ════════════════════════════════════════════════════════════════════════════

cursor_offset:      dd 4        ; Position curseur après "> "
cmd_length:         dd 0        ; Longueur commande courante
cmd_buffer:         times 64 db 0   ; Buffer commande (64 bytes max)
prompt_line:        dd 9        ; Ligne du prompt
edit_mode:          db 0        ; 0=normal, 1=edit mode
file_content_len:   dd 0        ; Longueur du fichier
file_content:       times 512 db 0  ; Contenu fichier (512 bytes max)
shift_state:        db 0        ; État touche Shift

; ════════════════════════════════════════════════════════════════════════════
; SECTION 3: TABLES (scancode, etc.)
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
; SECTION 4: EMBEDDED BYTECODE (exemple)
; ════════════════════════════════════════════════════════════════════════════

embedded_program:
    db 'M', 'A', 'S', 'M'       ; Magic
    db 1, 0, 0, 0               ; Version
    times 0x38 db 0             ; Header padding
    db 0x17, 42                 ; PUSH 42
    db 0x17, 58                 ; PUSH 58
    db 0x30                     ; ADD
    db 0x68                     ; PRINT
embedded_program_end:

; ════════════════════════════════════════════════════════════════════════════
; SECTION 5: IDT (Interrupt Descriptor Table)
; ════════════════════════════════════════════════════════════════════════════

align 16
idt_ptr:
    dw 256*8 - 1                ; Limit
    dd idt                      ; Base (adresse dynamique)

idt:
    times 0x21 dq 0             ; Entrées 0x00-0x20 vides
    ; Keyboard entry (0x21) - sera patché dynamiquement par core.asm
    dw 0x0000                   ; Offset low (patché)
    dw 0x08                     ; Selector
    db 0                        ; Zero
    db 0x8E                     ; Type: 32-bit interrupt gate
    dw 0x0000                   ; Offset high (patché)
    times (256-0x22) dq 0       ; Reste des entrées

; ════════════════════════════════════════════════════════════════════════════
; PADDING TO 64KB
; NOTE: On utilise une adresse absolue pour éviter les problèmes de $$
; ════════════════════════════════════════════════════════════════════════════

; Le kernel commence à 0x10000 et doit faire 64KB
; Cette directive pad jusqu'à ce que le fichier fasse 64KB depuis 0x10000
KERNEL_END:
