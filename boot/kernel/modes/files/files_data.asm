; ============================================================================
; MathisOS - File Manager Data
; ============================================================================
; Strings, variables, file entries pour le file manager
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; STRINGS
; ════════════════════════════════════════════════════════════════════════════
str_files_icon:   db "FILES", 0
str_files_title:  db "FILES", 0
str_esc_back:     db "[ESC] Back", 0
str_path_icon:    db "/ (root)", 0
str_col_name:     db "Name", 0
str_col_size:     db "Size", 0
str_col_mod:      db "Modified", 0
str_sel_arrow:    db ">", 0

; File entries (mock data for now)
str_files_e0:     db "PROJECTS/", 0
str_files_e1:     db "README.TXT", 0
str_files_e2:     db "HELLO.ASM", 0
str_size_dir:     db "--", 0
str_size_readme:  db "45 B", 0
str_size_hello:   db "128 B", 0
str_mod_1:        db "Dec 17 14:30", 0
str_mod_2:        db "Dec 17 12:00", 0
str_mod_3:        db "Dec 16 23:42", 0

; Entry 3
str_files_e3:     db "DOCS/", 0
str_size_e3:      db "--", 0
str_mod_4:        db "Dec 15 10:00", 0

; Help text
str_files_help1:  db "[W/S] Navigate  [ENTER] Open  [N] New  [D] Del  [R] Rename", 0
str_files_help2:  db "[TAB] Switch mode  [ESC] Back", 0

; View mode strings
str_view_readme:  db "README.TXT", 0
str_view_hello:   db "HELLO.ASM", 0
str_view_help:    db "[ESC] Close file", 0

; README content
str_readme_l1:    db "Welcome to MATHIS OS!", 0
str_readme_l2:    db "", 0
str_readme_l3:    db "This is a test file.", 0

; ASM content (syntax highlighted)
str_asm_l1:       db "; Hello World in x86 Assembly", 0
str_asm_l2:       db "section .text", 0
str_asm_l3:       db "global _start", 0
str_asm_l4:       db "_start:", 0
str_asm_l5:       db "    mov rax, 1      ; write", 0
str_asm_l6:       db "    mov rdi, 1      ; stdout", 0

; Line numbers
str_ln_1:         db " 1", 0
str_ln_2:         db " 2", 0
str_ln_3:         db " 3", 0
str_ln_4:         db " 4", 0
str_ln_5:         db " 5", 0
str_ln_6:         db " 6", 0

; Status bar
str_edit_label:   db "EDIT:", 0
str_status_pos:   db "Line 1, Col 1", 0
str_status_txt:   db "TXT", 0
str_status_asm:   db "ASM", 0

; ════════════════════════════════════════════════════════════════════════════
; VARIABLES
; ════════════════════════════════════════════════════════════════════════════
files_selected:   dd 0               ; Currently selected file index
files_viewing:    db 0               ; 0=list, 1=viewing README, 2=viewing ASM
files_dirty:      db 1               ; Redraw flag (start dirty)
files_dialog:     db 0               ; 0=none, 1=new file dialog

; ════════════════════════════════════════════════════════════════════════════
; CONSTANTS
; ════════════════════════════════════════════════════════════════════════════
FILES_TABLE_X     equ 100            ; Table X position
FILES_TABLE_W     equ 824            ; Table width
FILES_ROW_H       equ 40             ; Row height
FILES_MAX_ENTRIES equ 3              ; Number of file entries (for now)
