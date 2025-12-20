; ════════════════════════════════════════════════════════════════════════════
; FILES_STATE.ASM - Files App constants and state variables
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; APP STATE CONSTANTS
; ════════════════════════════════════════════════════════════════════════════
FA_STATE_LIST       equ 0           ; File list view
FA_STATE_EDITOR     equ 1           ; Text editor view
FA_STATE_DIALOG_NEW equ 2           ; New file dialog
FA_STATE_DIALOG_DEL equ 3           ; Delete confirm dialog
FA_STATE_DIALOG_REN equ 4           ; Rename dialog

; ════════════════════════════════════════════════════════════════════════════
; FS_SVC CONSTANTS (must match services/fs_svc.asm)
; ════════════════════════════════════════════════════════════════════════════
FA_FS_DIRENT_SIZE   equ 64              ; Size of FS_DIRENT structure
FA_FS_DIRENT_NAME   equ 0               ; Name offset in FS_DIRENT
FA_FS_DIRENT_SIZE_OFF equ 32            ; Size offset in FS_DIRENT
FA_FS_DIRENT_FLAGS  equ 36              ; Flags offset in FS_DIRENT
FA_FS_ENTRY_DIR     equ 0x01            ; Directory flag

; ════════════════════════════════════════════════════════════════════════════
; DYNAMIC FILE ENTRIES
; ════════════════════════════════════════════════════════════════════════════
FA_MAX_ENTRIES      equ 32              ; Max entries to display
FA_FILE_BUF_SIZE    equ 8192            ; 8KB file buffer

; ════════════════════════════════════════════════════════════════════════════
; WIDGET POINTERS
; ════════════════════════════════════════════════════════════════════════════
fa_header:          dq 0            ; Header widget
fa_pathbar:         dq 0            ; Path bar widget
fa_file_list:       dq 0            ; File list widget
fa_statusbar:       dq 0            ; Status bar widget
fa_editor:          dq 0            ; Text editor widget (created on demand)
fa_dialog:          dq 0            ; Current dialog (created on demand)

; ════════════════════════════════════════════════════════════════════════════
; APP STATE
; ════════════════════════════════════════════════════════════════════════════
fa_state:           dd FA_STATE_LIST
fa_initialized:     db 0

; ════════════════════════════════════════════════════════════════════════════
; ENTRY ARRAYS
; ════════════════════════════════════════════════════════════════════════════
; Entry array - FILE_ENTRY_SIZE (32 bytes) * FA_MAX_ENTRIES
fa_entries:         times (32 * FA_MAX_ENTRIES) db 0
fa_entry_count:     dd 0

; Name buffers for entries (32 bytes each)
fa_name_bufs:       times (32 * FA_MAX_ENTRIES) db 0

; Date string buffers (16 bytes each)
fa_date_bufs:       times (16 * FA_MAX_ENTRIES) db 0

; Temporary buffer for fs_readdir results
fa_dirent_buf:      times (FA_FS_DIRENT_SIZE * FA_MAX_ENTRIES) db 0

; ════════════════════════════════════════════════════════════════════════════
; MOCK DATA (fallback when filesystem not mounted)
; ════════════════════════════════════════════════════════════════════════════
fa_mock_name_0:     db "[MOCK] PROJECTS/", 0
fa_mock_name_1:     db "[MOCK] DOCS/", 0
fa_mock_name_2:     db "[MOCK] README.TXT", 0
fa_mock_name_3:     db "[MOCK] HELLO.ASM", 0
fa_mock_mod:        db "--", 0

; ════════════════════════════════════════════════════════════════════════════
; PATH AND TITLE STRINGS
; ════════════════════════════════════════════════════════════════════════════
fa_current_path:    db "/ (root)", 0
fa_root_path:       db "/", 0
fa_title_files:     db "FILES", 0
fa_title_edit:      db "EDIT: ", 0
fa_title_buf:       times 32 db 0           ; Buffer for "EDIT: filename"

; ════════════════════════════════════════════════════════════════════════════
; SAMPLE FILE CONTENT FOR EDITOR
; ════════════════════════════════════════════════════════════════════════════
fa_readme_content:  db "Welcome to MATHIS OS!", 10
                    db "", 10
                    db "This is a test file.", 10
                    db "You can edit it!", 0
fa_readme_len:      dd 58

fa_asm_content:     db "; Hello World in x86 Assembly", 10
                    db "section .text", 10
                    db "global _start", 10
                    db "_start:", 10
                    db "    mov rax, 1      ; write", 10
                    db "    mov rdi, 1      ; stdout", 0
fa_asm_len:         dd 120

fa_empty_content:   db 0

; ════════════════════════════════════════════════════════════════════════════
; FAT32 INTEGRATION DATA
; ════════════════════════════════════════════════════════════════════════════
fa_current_file:    dq 0                    ; Pointer to current open filename
fa_fat32_name:      times 12 db 0           ; 8.3 format name buffer
fa_file_buffer:     times FA_FILE_BUF_SIZE db 0
