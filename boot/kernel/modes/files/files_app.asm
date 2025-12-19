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
; MOCK FILE ENTRIES (to be replaced with real FAT32 data)
; ════════════════════════════════════════════════════════════════════════════
fa_entries:
    ; Entry 0: PROJECTS/
    dq fa_name_0            ; FE_NAME
    dd 0                    ; FE_SIZE
    dd FEF_DIRECTORY        ; FE_FLAGS
    dq fa_mod_0             ; FE_MOD_DATE
    dq 0                    ; FE_RESERVED

    ; Entry 1: DOCS/
    dq fa_name_1
    dd 0
    dd FEF_DIRECTORY
    dq fa_mod_1
    dq 0

    ; Entry 2: README.TXT
    dq fa_name_2
    dd 45
    dd 0
    dq fa_mod_2
    dq 0

    ; Entry 3: HELLO.ASM
    dq fa_name_3
    dd 128
    dd 0
    dq fa_mod_3
    dq 0

fa_entry_count:     dd 4

fa_name_0:          db "PROJECTS/", 0
fa_name_1:          db "DOCS/", 0
fa_name_2:          db "README.TXT", 0
fa_name_3:          db "HELLO.ASM", 0
fa_mod_0:           db "Dec 17 14:30", 0
fa_mod_1:           db "Dec 15 10:00", 0
fa_mod_2:           db "Dec 17 12:00", 0
fa_mod_3:           db "Dec 16 23:42", 0

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

    ; Set file entries
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
    ; Get selected entry name
    mov rdi, [fa_file_list]
    call file_list_get_selected
    ; TODO: Get actual filename from entry
    mov rsi, fa_name_2              ; Placeholder
    xor edx, edx                    ; is_folder = 0
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
    mov rsi, fa_name_2              ; Placeholder filename
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
fa_on_file_select:
    push rbx
    mov rbx, rdi                    ; widget

    ; Get selected index
    call file_list_get_selected

    ; Check if it's a directory (index 0 or 1)
    cmp eax, 2
    jl .done                        ; Can't open directories yet

    ; Open file in editor
    call fa_open_file_editor

.done:
    pop rbx
    ret

; Open file in text editor
fa_open_file_editor:
    push rbx
    push r12
    push r13

    ; Get selected index
    mov rdi, [fa_file_list]
    call file_list_get_selected
    mov r12d, eax

    ; Get filename from entry (calculate entry address)
    ; Each entry is 32 bytes: dq name, dd size, dd flags, dq mod, dq reserved
    imul eax, 32
    lea rbx, [fa_entries + rax]
    mov r13, [rbx]                  ; r13 = pointer to filename string

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

    ; Convert filename to FAT32 8.3 format
    mov rsi, r13
    lea rdi, [fa_fat32_name]
    call fat32_convert_name

    ; Try to read file from FAT32
    lea rsi, [fa_fat32_name]
    lea rdi, [fa_file_buffer]
    mov edx, FA_FILE_BUF_SIZE
    call fat32_read_file
    test eax, eax
    jz .use_mock                    ; FAT32 read failed, use mock data

    ; Load FAT32 content into editor
    mov rdi, [fa_editor]
    lea rsi, [fa_file_buffer]
    mov edx, eax                    ; Size from fat32_read_file
    call text_editor_set_text
    jmp .set_state

.use_mock:
    ; Fallback to mock content if FAT32 not available
    mov rdi, [fa_editor]
    cmp r12d, 2                     ; README.TXT
    je .load_readme
    cmp r12d, 3                     ; HELLO.ASM
    je .load_asm
    ; Empty file
    lea rsi, [fa_empty_content]
    xor edx, edx
    call text_editor_set_text
    jmp .set_state

.load_readme:
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
    pop r13
    pop r12
    pop rbx
    ret

; Dialog callbacks
; NOTE: FAT32 CRUD operations disabled for safety until fully tested
fa_on_new_confirm:
    ; TODO: Re-enable FAT32 create when safe
    ; For now, just close dialog
    call fa_close_dialog
    ret

fa_on_delete_confirm:
    ; TODO: Re-enable FAT32 delete when safe
    ; For now, just close dialog
    call fa_close_dialog
    ret

fa_on_rename_confirm:
    ; TODO: Implement rename (requires FAT32 rename function)
    call fa_close_dialog
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_SAVE_FILE - Save current editor content to disk
; NOTE: FAT32 write disabled for safety - only clears modified flag
; ════════════════════════════════════════════════════════════════════════════
fa_save_file:
    push rbx

    ; Check if editor exists
    mov rdi, [fa_editor]
    test rdi, rdi
    jz .save_done

    ; TODO: Re-enable when FAT32 write is fully tested
    ; For now, just clear modified flag to show "Saved"

    ; Clear modified flag in editor (visual feedback)
    mov rdi, [fa_editor]
    mov dword [rdi + TE_MODIFIED], 0
    or dword [rdi + W_FLAGS], WF_DIRTY

    mov byte [files_dirty], 1

.save_done:
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
