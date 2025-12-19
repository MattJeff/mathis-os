; ════════════════════════════════════════════════════════════════════════════
; FILES_APP.ASM - Files Application using Widgets (SOLID Phase 6)
; ════════════════════════════════════════════════════════════════════════════
; Manages the file manager UI using widget system
; Widgets: header, pathbar, file_list, statusbar, text_editor, dialogs
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; APP STATE
; ════════════════════════════════════════════════════════════════════════════
FA_STATE_LIST       equ 0           ; File list view
FA_STATE_EDITOR     equ 1           ; Text editor view
FA_STATE_DIALOG_NEW equ 2           ; New file dialog
FA_STATE_DIALOG_DEL equ 3           ; Delete confirm dialog
FA_STATE_DIALOG_REN equ 4           ; Rename dialog

; ════════════════════════════════════════════════════════════════════════════
; WIDGET POINTERS (stored globally for this app)
; ════════════════════════════════════════════════════════════════════════════
fa_header:          dq 0            ; Header widget
fa_pathbar:         dq 0            ; Path bar widget
fa_file_list:       dq 0            ; File list widget
fa_statusbar:       dq 0            ; Status bar widget
fa_editor:          dq 0            ; Text editor widget (created on demand)
fa_dialog:          dq 0            ; Current dialog (created on demand)

fa_state:           dd FA_STATE_LIST
fa_initialized:     db 0

; ════════════════════════════════════════════════════════════════════════════
; FS_SVC CONSTANTS (must match services/fs_svc.asm)
; ════════════════════════════════════════════════════════════════════════════
FA_FS_DIRENT_SIZE   equ 64              ; Size of FS_DIRENT structure
FA_FS_DIRENT_NAME   equ 0               ; Name offset in FS_DIRENT
FA_FS_DIRENT_SIZE_OFF equ 32            ; Size offset in FS_DIRENT
FA_FS_DIRENT_FLAGS  equ 36              ; Flags offset in FS_DIRENT
FA_FS_ENTRY_DIR     equ 0x01            ; Directory flag

; ════════════════════════════════════════════════════════════════════════════
; DYNAMIC FILE ENTRIES (loaded from filesystem via fs_svc)
; ════════════════════════════════════════════════════════════════════════════
FA_MAX_ENTRIES      equ 32              ; Max entries to display

; Entry array - FILE_ENTRY_SIZE (32 bytes) * FA_MAX_ENTRIES
; Structure: dq name_ptr, dd size, dd flags, dq mod_date_ptr, dq reserved
fa_entries:         times (32 * FA_MAX_ENTRIES) db 0

fa_entry_count:     dd 0

; Name buffers for entries (32 bytes each, matches FS_DIRENT_NAME)
fa_name_bufs:       times (32 * FA_MAX_ENTRIES) db 0

; Date string buffers (16 bytes each)
fa_date_bufs:       times (16 * FA_MAX_ENTRIES) db 0

; Temporary buffer for fs_readdir results
fa_dirent_buf:      times (FA_FS_DIRENT_SIZE * FA_MAX_ENTRIES) db 0

; Fallback mock data (used when filesystem not mounted)
; Names prefixed with [MOCK] to indicate mock data visually
fa_mock_name_0:     db "[MOCK] PROJECTS/", 0
fa_mock_name_1:     db "[MOCK] DOCS/", 0
fa_mock_name_2:     db "[MOCK] README.TXT", 0
fa_mock_name_3:     db "[MOCK] HELLO.ASM", 0
fa_mock_mod:        db "--", 0

fa_current_path:    db "/ (root)", 0
fa_title_files:     db "FILES", 0
fa_title_edit:      db "EDIT: ", 0
fa_title_buf:       times 32 db 0           ; Buffer for "EDIT: filename"

; Sample file content for editor
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

; FAT32 integration data
fa_current_file:    dq 0                    ; Pointer to current open filename
fa_fat32_name:      times 12 db 0           ; 8.3 format name buffer

; File buffer for loading/saving
FA_FILE_BUF_SIZE    equ 8192                ; 8KB file buffer
fa_file_buffer:     times FA_FILE_BUF_SIZE db 0

; ════════════════════════════════════════════════════════════════════════════
; FILES_APP_INIT - Initialize all widgets
; ════════════════════════════════════════════════════════════════════════════
files_app_init:
    cmp byte [fa_initialized], 1
    je .done                        ; Already initialized

    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Load directory from filesystem
    call fa_load_directory

    ; Get screen dimensions
    mov r12d, [screen_width]
    mov r13d, [screen_height]

    ; Create header (full width, 24px height, at top)
    xor esi, esi                    ; x = 0
    xor edx, edx                    ; y = 0
    mov ecx, r12d                   ; w = screen_width
    mov r8d, 24                     ; h = 24
    mov r9, fa_title_files          ; title
    call header_create
    mov [fa_header], rax

    ; Create pathbar (below header)
    xor esi, esi                    ; x = 0
    mov edx, 24                     ; y = 24
    mov ecx, r12d                   ; w = screen_width
    mov r8d, 20                     ; h = 20
    mov r9, fa_current_path         ; path
    call pathbar_create
    mov [fa_pathbar], rax

    ; Create file list (main area)
    mov esi, 20                     ; x = 20 (margin)
    mov edx, 54                     ; y = 24 + 20 + 10
    mov ecx, r12d
    sub ecx, 40                     ; w = screen_width - 40 (margins)
    mov r8d, r13d
    sub r8d, 110                    ; h = screen_height - header - pathbar - statusbar
    call file_list_create
    mov [fa_file_list], rax

    ; Set file entries (now from dynamic data)
    mov rdi, rax
    mov rsi, fa_entries
    mov edx, [fa_entry_count]
    call file_list_set_entries

    ; Set callback for file selection
    mov rdi, [fa_file_list]
    mov rsi, fa_on_file_select
    call file_list_set_callback

    ; Create statusbar (at bottom)
    xor esi, esi                    ; x = 0
    mov edx, r13d
    sub edx, 46                     ; y = screen_height - 46
    mov ecx, r12d                   ; w = screen_width
    mov r8d, 46                     ; h = 46
    call statusbar_create
    mov [fa_statusbar], rax

    mov byte [fa_initialized], 1
    mov dword [fa_state], FA_STATE_LIST

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx

.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_LOAD_DIRECTORY - Load directory entries from filesystem
; Uses fs_svc to get real file listing, falls back to mock data
; ════════════════════════════════════════════════════════════════════════════
fa_load_directory:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15

    ; Try to get filesystem service
    mov edi, SVC_FS
    call get_service
    test rax, rax
    jz .use_mock                    ; No FS service, use mock data

    mov r15, rax                    ; r15 = fs_vtable

    ; Call fs_readdir("/", buffer, max_entries)
    lea rdi, [fa_root_path]         ; path = "/"
    lea rsi, [fa_dirent_buf]        ; buffer for results
    mov edx, FA_MAX_ENTRIES         ; max entries
    call [r15 + FS_READDIR]

    cmp eax, -1
    je .use_mock                    ; Error, use mock data
    test eax, eax
    jz .use_mock                    ; No entries, use mock data

    ; eax = number of entries read
    mov r14d, eax                   ; r14 = entry count
    mov [fa_entry_count], eax

    ; Convert FS_DIRENT entries to FILE_ENTRY format
    xor r12d, r12d                  ; r12 = current index
    lea r13, [fa_dirent_buf]        ; r13 = source dirent

.convert_loop:
    cmp r12d, r14d
    jge .load_done

    ; Calculate destination pointers
    ; FILE_ENTRY: dq name_ptr, dd size, dd flags, dq mod_date_ptr, dq reserved
    mov eax, r12d
    imul eax, FILE_ENTRY_SIZE       ; 32 bytes per entry
    lea rbx, [fa_entries + rax]     ; rbx = dest FILE_ENTRY

    ; Calculate name buffer pointer
    mov eax, r12d
    shl eax, 5                      ; * 32 bytes per name
    lea rcx, [fa_name_bufs + rax]   ; rcx = name buffer

    ; Calculate date buffer pointer
    mov eax, r12d
    shl eax, 4                      ; * 16 bytes per date
    lea rdx, [fa_date_bufs + rax]   ; rdx = date buffer

    ; Copy name from dirent to name buffer
    push rcx
    push rdx
    mov rdi, rcx                    ; dest = name buffer
    lea rsi, [r13 + FA_FS_DIRENT_NAME] ; src = dirent name
    mov ecx, 31                     ; max 31 chars
.copy_name:
    lodsb
    stosb
    test al, al
    jz .name_copied
    dec ecx
    jnz .copy_name
    mov byte [rdi], 0               ; Ensure null terminated
.name_copied:
    pop rdx
    pop rcx

    ; Set name pointer in FILE_ENTRY
    mov [rbx + FE_NAME], rcx

    ; Copy size
    mov eax, [r13 + FA_FS_DIRENT_SIZE_OFF]
    mov [rbx + FE_SIZE], eax

    ; Convert flags (FS_ENTRY_* to FEF_*)
    mov eax, [r13 + FA_FS_DIRENT_FLAGS]
    xor ecx, ecx
    test eax, FA_FS_ENTRY_DIR
    jz .not_dir_flag
    or ecx, FEF_DIRECTORY
.not_dir_flag:
    mov [rbx + FE_FLAGS], ecx

    ; Set date pointer (use placeholder for now)
    lea rax, [fa_mock_mod]          ; TODO: Convert timestamp to string
    mov [rbx + FE_MOD_DATE], rax

    ; Clear reserved
    mov qword [rbx + FE_RESERVED], 0

    ; Next entry
    add r13, FA_FS_DIRENT_SIZE
    inc r12d
    jmp .convert_loop

.use_mock:
    ; Fallback: create mock entries
    mov dword [fa_entry_count], 4

    ; Entry 0: PROJECTS/
    lea rax, [fa_mock_name_0]
    mov [fa_entries + 0*32 + FE_NAME], rax
    mov dword [fa_entries + 0*32 + FE_SIZE], 0
    mov dword [fa_entries + 0*32 + FE_FLAGS], FEF_DIRECTORY
    lea rax, [fa_mock_mod]
    mov [fa_entries + 0*32 + FE_MOD_DATE], rax

    ; Entry 1: DOCS/
    lea rax, [fa_mock_name_1]
    mov [fa_entries + 1*32 + FE_NAME], rax
    mov dword [fa_entries + 1*32 + FE_SIZE], 0
    mov dword [fa_entries + 1*32 + FE_FLAGS], FEF_DIRECTORY
    lea rax, [fa_mock_mod]
    mov [fa_entries + 1*32 + FE_MOD_DATE], rax

    ; Entry 2: README.TXT
    lea rax, [fa_mock_name_2]
    mov [fa_entries + 2*32 + FE_NAME], rax
    mov dword [fa_entries + 2*32 + FE_SIZE], 45
    mov dword [fa_entries + 2*32 + FE_FLAGS], 0
    lea rax, [fa_mock_mod]
    mov [fa_entries + 2*32 + FE_MOD_DATE], rax

    ; Entry 3: HELLO.ASM
    lea rax, [fa_mock_name_3]
    mov [fa_entries + 3*32 + FE_NAME], rax
    mov dword [fa_entries + 3*32 + FE_SIZE], 128
    mov dword [fa_entries + 3*32 + FE_FLAGS], 0
    lea rax, [fa_mock_mod]
    mov [fa_entries + 3*32 + FE_MOD_DATE], rax

.load_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Path for root directory
fa_root_path:       db "/", 0

; ════════════════════════════════════════════════════════════════════════════
; FILES_APP_DRAW - Draw all widgets
; ════════════════════════════════════════════════════════════════════════════
files_app_draw:
    push rbx

    ; Clear screen with dark background
    mov edi, 0x00202020
    call video_clear

    ; Check current state
    mov eax, [fa_state]

    cmp eax, FA_STATE_EDITOR
    je .draw_editor

    cmp eax, FA_STATE_DIALOG_NEW
    je .draw_with_dialog
    cmp eax, FA_STATE_DIALOG_DEL
    je .draw_with_dialog
    cmp eax, FA_STATE_DIALOG_REN
    je .draw_with_dialog

    ; Default: draw file list view
.draw_list:
    mov rdi, [fa_header]
    call widget_draw

    mov rdi, [fa_pathbar]
    call widget_draw

    mov rdi, [fa_file_list]
    call widget_draw

    mov rdi, [fa_statusbar]
    call widget_draw

    jmp .done

.draw_editor:
    ; Draw editor (full screen except header)
    mov rdi, [fa_header]
    call widget_draw

    mov rdi, [fa_editor]
    test rdi, rdi
    jz .done
    call widget_draw
    jmp .done

.draw_with_dialog:
    ; Draw list view first (dimmed background)
    mov rdi, [fa_header]
    call widget_draw
    mov rdi, [fa_pathbar]
    call widget_draw
    mov rdi, [fa_file_list]
    call widget_draw
    mov rdi, [fa_statusbar]
    call widget_draw

    ; Draw dialog on top
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .done
    call widget_draw

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_APP_ON_KEY - Handle keyboard input
; Input:  AL = scancode
; Output: AL = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
files_app_on_key:
    push rbx
    push r12
    movzx r12d, al                  ; Save scancode

    mov eax, [fa_state]

    ; Dialog state - forward to dialog
    cmp eax, FA_STATE_DIALOG_NEW
    je .handle_dialog
    cmp eax, FA_STATE_DIALOG_DEL
    je .handle_dialog
    cmp eax, FA_STATE_DIALOG_REN
    je .handle_dialog

    ; Editor state
    cmp eax, FA_STATE_EDITOR
    je .handle_editor

    ; List state
.handle_list:
    ; ESC - do nothing in list (global handler will switch mode)
    cmp r12d, 0x01
    je .not_handled

    ; N - New file dialog (0x31)
    cmp r12d, 0x31
    je .show_new_dialog

    ; D - Delete dialog (0x20)
    cmp r12d, 0x20
    je .show_delete_dialog

    ; R - Rename dialog (0x13)
    cmp r12d, 0x13
    je .show_rename_dialog

    ; Forward to file list widget
    mov rdi, [fa_file_list]
    mov esi, r12d
    call widget_on_key
    test eax, eax
    jnz .handled_redraw

    jmp .not_handled

.handle_editor:
    ; ESC in editor - close and return to list
    cmp r12d, 0x01
    je .close_editor

    ; Ctrl+S (0x1F) - Save file
    cmp r12d, 0x1F
    jne .check_ctrl_s_done
    cmp byte [ctrl_state], 1
    jne .check_ctrl_s_done
    call fa_save_file
    jmp .handled_redraw
.check_ctrl_s_done:

    ; Forward to editor widget
    mov rdi, [fa_editor]
    test rdi, rdi
    jz .not_handled
    mov esi, r12d
    call widget_on_key
    test eax, eax
    jnz .handled_redraw
    jmp .not_handled

.handle_dialog:
    ; ESC in dialog - close dialog and return to list
    cmp r12d, 0x01
    je .close_dialog_esc

    ; Forward to dialog widget
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .not_handled
    mov esi, r12d
    call widget_on_key
    test eax, eax
    jnz .handled_redraw
    jmp .not_handled

.close_dialog_esc:
    call fa_close_dialog
    jmp .handled_redraw

.show_new_dialog:
    call dialog_new_create
    mov [fa_dialog], rax
    test rax, rax
    jz .not_handled
    ; Set callbacks
    mov rdi, rax
    mov rsi, fa_on_new_confirm
    mov rdx, fa_on_dialog_cancel
    call dialog_set_callbacks
    mov dword [fa_state], FA_STATE_DIALOG_NEW
    jmp .handled_redraw

.show_delete_dialog:
    ; Get selected entry name from fa_entries
    mov rdi, [fa_file_list]
    call file_list_get_selected
    ; Get filename pointer from entry
    imul eax, 32                    ; FILE_ENTRY_SIZE = 32
    lea rbx, [fa_entries + rax]
    mov rsi, [rbx + FE_NAME]        ; Get name pointer
    ; Check if directory
    mov edx, [rbx + FE_FLAGS]
    and edx, FEF_DIRECTORY          ; is_folder flag
    call dialog_delete_create
    mov [fa_dialog], rax
    test rax, rax
    jz .not_handled
    mov rdi, rax
    mov rsi, fa_on_delete_confirm
    mov rdx, fa_on_dialog_cancel
    call dialog_set_callbacks
    mov dword [fa_state], FA_STATE_DIALOG_DEL
    jmp .handled_redraw

.show_rename_dialog:
    ; Get selected entry name from fa_entries
    mov rdi, [fa_file_list]
    call file_list_get_selected
    imul eax, 32
    lea rbx, [fa_entries + rax]
    mov rsi, [rbx + FE_NAME]        ; Get current filename
    call dialog_rename_create
    mov [fa_dialog], rax
    test rax, rax
    jz .not_handled
    mov rdi, rax
    mov rsi, fa_on_rename_confirm
    mov rdx, fa_on_dialog_cancel
    call dialog_set_callbacks
    mov dword [fa_state], FA_STATE_DIALOG_REN
    jmp .handled_redraw

.close_editor:
    ; Destroy editor widget
    mov rdi, [fa_editor]
    test rdi, rdi
    jz .back_to_list
    call widget_destroy
    mov qword [fa_editor], 0
.back_to_list:
    mov dword [fa_state], FA_STATE_LIST
    ; Update header title
    mov rdi, [fa_header]
    mov rsi, fa_title_files
    call header_set_title
    jmp .handled_redraw

.handled_redraw:
    mov byte [files_dirty], 1
    mov al, 1
    jmp .done

.not_handled:
    xor al, al

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CALLBACKS
; ════════════════════════════════════════════════════════════════════════════

; Called when file is selected (Enter or double-click)
; Input: RDI = widget, ESI = selected index
fa_on_file_select:
    push rbx
    push rax

    ; Get selected index (passed in ESI, but use RDI to call helper)
    call file_list_get_selected     ; RDI already has widget

    ; Check actual file flags (not hardcoded index!)
    imul eax, 32                    ; FILE_ENTRY_SIZE = 32
    lea rbx, [fa_entries + rax]
    mov eax, [rbx + FE_FLAGS]
    test eax, FEF_DIRECTORY
    jnz .done                       ; Can't open directories yet

    ; Open file in editor
    call fa_open_file_editor

.done:
    pop rax
    pop rbx
    ret

; Open file in text editor
fa_open_file_editor:
    push rbx
    push r12
    push r13
    push r14

    ; Get selected index
    mov rdi, [fa_file_list]
    call file_list_get_selected
    mov r12d, eax

    ; Get filename from entry (calculate entry address)
    ; Each entry is 32 bytes: dq name, dd size, dd flags, dq mod, dq reserved
    imul eax, 32
    lea rbx, [fa_entries + rax]
    mov r13, [rbx]                  ; r13 = pointer to filename string

    ; Check if it's a directory
    mov eax, [rbx + FE_FLAGS]
    test eax, FEF_DIRECTORY
    jnz .fail                       ; Can't open directories

    ; Save current filename for save operation
    mov [fa_current_file], r13

    ; Create editor widget
    xor esi, esi                    ; x = 0
    mov edx, 24                     ; y = 24 (below header)
    mov ecx, [screen_width]
    mov r8d, [screen_height]
    sub r8d, 24                     ; h = screen_height - header
    call text_editor_create
    mov [fa_editor], rax
    test rax, rax
    jz .fail

    ; Try to read file using fs_svc
    mov edi, SVC_FS
    call get_service
    test rax, rax
    jz .use_mock                    ; No FS service

    mov r14, rax                    ; r14 = fs_vtable

    ; Use fs_read_file helper: (path, buffer, max_size) -> bytes_read
    mov rdi, r13                    ; path = filename
    lea rsi, [fa_file_buffer]       ; buffer
    mov edx, FA_FILE_BUF_SIZE       ; max size
    call fs_read_file
    cmp eax, -1
    je .use_mock                    ; Read failed
    test eax, eax
    jz .load_empty                  ; Empty file

    ; Load content into editor
    mov rdi, [fa_editor]
    lea rsi, [fa_file_buffer]
    mov edx, eax                    ; Size from fs_read_file
    call text_editor_set_text
    jmp .set_state

.load_empty:
    mov rdi, [fa_editor]
    lea rsi, [fa_empty_content]
    xor edx, edx
    call text_editor_set_text
    jmp .set_state

.use_mock:
    ; Fallback to mock content if filesystem not available
    mov rdi, [fa_editor]
    ; Check filename to determine which mock content
    mov rsi, r13
    lea rdi, [fa_mock_name_2]       ; "README.TXT"
    call fa_str_compare
    test eax, eax
    jnz .load_readme

    mov rsi, r13
    lea rdi, [fa_mock_name_3]       ; "HELLO.ASM"
    call fa_str_compare
    test eax, eax
    jnz .load_asm

    ; Unknown file - load empty
    mov rdi, [fa_editor]
    lea rsi, [fa_empty_content]
    xor edx, edx
    call text_editor_set_text
    jmp .set_state

.load_readme:
    mov rdi, [fa_editor]
    mov rsi, fa_readme_content
    mov edx, [fa_readme_len]
    call text_editor_set_text
    jmp .set_state

.load_asm:
    mov rdi, [fa_editor]
    mov rsi, fa_asm_content
    mov edx, [fa_asm_len]
    call text_editor_set_text

.set_state:
    mov dword [fa_state], FA_STATE_EDITOR

    ; Build header title: "EDIT: " + filename
    lea rdi, [fa_title_buf]
    ; Copy "EDIT: "
    mov byte [rdi], 'E'
    mov byte [rdi+1], 'D'
    mov byte [rdi+2], 'I'
    mov byte [rdi+3], 'T'
    mov byte [rdi+4], ':'
    mov byte [rdi+5], ' '
    add rdi, 6
    ; Copy filename (from r13 saved earlier)
    mov rsi, r13
    test rsi, rsi
    jz .title_done
.copy_filename:
    lodsb
    test al, al
    jz .title_done
    stosb
    jmp .copy_filename
.title_done:
    mov byte [rdi], 0               ; Null terminate

    ; Update header title
    mov rdi, [fa_header]
    lea rsi, [fa_title_buf]
    call header_set_title
    mov byte [files_dirty], 1

.fail:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_STR_COMPARE - Compare two null-terminated strings
; Input:  RSI = string1, RDI = string2
; Output: EAX = 1 if equal, 0 if not
; ════════════════════════════════════════════════════════════════════════════
fa_str_compare:
    push rsi
    push rdi
.cmp_loop:
    mov al, [rsi]
    mov ah, [rdi]
    cmp al, ah
    jne .not_equal
    test al, al
    jz .equal                       ; Both reached null
    inc rsi
    inc rdi
    jmp .cmp_loop
.equal:
    mov eax, 1
    jmp .cmp_done
.not_equal:
    xor eax, eax
.cmp_done:
    pop rdi
    pop rsi
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG CALLBACKS - Now using real CRUD operations
; ════════════════════════════════════════════════════════════════════════════

; Called when "Create" button is clicked in New File dialog
fa_on_new_confirm:
    push rbx
    push r12
    push r13

    ; Get filename from dialog input
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .new_done

    ; Check if folder was selected
    call dialog_new_is_folder
    mov r13d, eax                   ; r13 = is_folder flag

    ; Get input text from dialog
    mov rdi, [fa_dialog]
    call dialog_new_get_name
    test rax, rax
    jz .new_done
    mov r12, rax                    ; r12 = new filename

    ; Check if creating folder or file
    test r13d, r13d
    jnz .create_folder

    ; Create FILE using CRUD
    mov rdi, r12
    mov esi, FS_O_CREATE            ; Create flag
    call crud_create_file
    cmp eax, -1
    je .new_done                    ; Creation failed

    ; Close the fd (we just created the file)
    mov edi, eax
    call fs_close
    jmp .new_refresh

.create_folder:
    ; Create FOLDER using fs_mkdir
    mov rdi, r12
    call fs_mkdir
    test eax, eax
    jz .new_done                    ; Creation failed

.new_refresh:

    ; Refresh file list
    call fa_load_directory

    ; Update file list widget
    mov rdi, [fa_file_list]
    mov rsi, fa_entries
    mov edx, [fa_entry_count]
    call file_list_set_entries

.new_done:
    call fa_close_dialog
    pop r13
    pop r12
    pop rbx
    ret

; Called when "Delete" button is clicked in Delete dialog
fa_on_delete_confirm:
    push rbx
    push r12

    ; Get selected entry name
    mov rdi, [fa_file_list]
    call file_list_get_selected
    imul eax, 32
    lea rbx, [fa_entries + rax]
    mov r12, [rbx + FE_NAME]        ; r12 = filename to delete

    ; Delete using fs_delete (handles "/" stripping automatically)
    mov rdi, r12
    call fs_delete
    test eax, eax
    jz .delete_done                 ; Deletion failed

    ; Refresh file list
    call fa_load_directory

    ; Update file list widget
    mov rdi, [fa_file_list]
    mov rsi, fa_entries
    mov edx, [fa_entry_count]
    call file_list_set_entries

.delete_done:
    call fa_close_dialog
    pop r12
    pop rbx
    ret

; Called when "Rename" button is clicked in Rename dialog
fa_on_rename_confirm:
    push rbx
    push r12
    push r13

    ; Get old filename (selected entry)
    mov rdi, [fa_file_list]
    call file_list_get_selected
    imul eax, 32
    lea rbx, [fa_entries + rax]
    mov r12, [rbx + FE_NAME]        ; r12 = old filename

    ; Get new filename from dialog input
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .rename_done

    call dialog_get_input
    test rax, rax
    jz .rename_done
    mov r13, rax                    ; r13 = new filename

    ; Rename using CRUD
    mov rdi, r12                    ; old path
    mov rsi, r13                    ; new path
    call crud_rename
    test eax, eax
    jz .rename_done                 ; Rename failed

    ; Refresh file list
    call fa_load_directory

    ; Update file list widget
    mov rdi, [fa_file_list]
    mov rsi, fa_entries
    mov edx, [fa_entry_count]
    call file_list_set_entries

.rename_done:
    call fa_close_dialog
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_SAVE_FILE - Save current editor content to disk using CRUD
; ════════════════════════════════════════════════════════════════════════════
fa_save_file:
    push rbx
    push r12
    push r13

    ; Check if editor exists
    mov rdi, [fa_editor]
    test rdi, rdi
    jz .save_done

    ; Check if we have a filename
    mov r12, [fa_current_file]
    test r12, r12
    jz .save_done

    ; Get text from editor
    mov rdi, [fa_editor]
    call text_editor_get_text       ; RAX = text ptr, EDX = length
    test rax, rax
    jz .save_done

    mov r13, rax                    ; r13 = text content
    mov ebx, edx                    ; ebx = length

    ; Write file using CRUD
    mov rdi, r12                    ; path = filename
    mov rsi, r13                    ; data = text content
    mov edx, ebx                    ; size = length
    call crud_write_file
    cmp eax, -1
    je .save_failed

    ; Success - clear modified flag
    mov rdi, [fa_editor]
    mov dword [rdi + TE_MODIFIED], 0
    or dword [rdi + W_FLAGS], WF_DIRTY
    jmp .save_refresh

.save_failed:
    ; Write failed - keep modified flag set
    ; TODO: Show error message

.save_refresh:
    mov byte [files_dirty], 1

.save_done:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_REFRESH_LIST - Reload file list from FAT32
; ════════════════════════════════════════════════════════════════════════════
fa_refresh_list:
    ; For now, just mark as dirty to redraw
    ; TODO: Implement real FAT32 directory listing
    mov byte [files_dirty], 1
    ret

fa_on_dialog_cancel:
    call fa_close_dialog
    ret

fa_close_dialog:
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .done
    call widget_destroy
    mov qword [fa_dialog], 0
    mov dword [fa_state], FA_STATE_LIST
    mov byte [files_dirty], 1
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_APP_CLEANUP - Destroy all widgets
; ════════════════════════════════════════════════════════════════════════════
files_app_cleanup:
    mov rdi, [fa_header]
    test rdi, rdi
    jz .no_header
    call widget_destroy
    mov qword [fa_header], 0
.no_header:

    mov rdi, [fa_pathbar]
    test rdi, rdi
    jz .no_pathbar
    call widget_destroy
    mov qword [fa_pathbar], 0
.no_pathbar:

    mov rdi, [fa_file_list]
    test rdi, rdi
    jz .no_filelist
    call widget_destroy
    mov qword [fa_file_list], 0
.no_filelist:

    mov rdi, [fa_statusbar]
    test rdi, rdi
    jz .no_statusbar
    call widget_destroy
    mov qword [fa_statusbar], 0
.no_statusbar:

    mov rdi, [fa_editor]
    test rdi, rdi
    jz .no_editor
    call widget_destroy
    mov qword [fa_editor], 0
.no_editor:

    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .no_dialog
    call widget_destroy
    mov qword [fa_dialog], 0
.no_dialog:

    mov byte [fa_initialized], 0
    ret

