; ═══════════════════════════════════════════════════════════════════════════════
; FILES UI - File Manager for MATHIS OS
; Both 2D (classic list) and 3D (floating nodes) views
; ═══════════════════════════════════════════════════════════════════════════════

; File manager states
FILES_STATE_BROWSE  equ 0       ; Browsing files
FILES_STATE_EDIT    equ 1       ; Editing a file
FILES_STATE_DIALOG  equ 2       ; Dialog open (new/delete/rename)

; Dialog types
DIALOG_NONE         equ 0
DIALOG_NEW          equ 1
DIALOG_DELETE       equ 2
DIALOG_RENAME       equ 3

; View modes
VIEW_2D             equ 0       ; Classic list view
VIEW_3D             equ 1       ; 3D floating nodes

; Colors (32-bit BGRA)
FILES_BG            equ 0x00201810      ; Dark background
FILES_HEADER_BG     equ 0x00302820      ; Header background
FILES_SELECTED_BG   equ 0x00404040      ; Selected item background
FILES_TEXT          equ 0x00FFFFFF      ; White text
FILES_TEXT_DIM      equ 0x00808080      ; Dim text
FILES_FOLDER_COL    equ 0x0000AAFF      ; Yellow-orange for folders
FILES_FILE_COL      equ 0x00FFFFFF      ; White for files
FILES_BORDER        equ 0x00606060      ; Border color

; Layout constants
FILES_HEADER_H      equ 24              ; Header height
FILES_FOOTER_H      equ 20              ; Footer height
FILES_LIST_X        equ 20              ; List X offset
FILES_LIST_Y        equ 50              ; List Y start
FILES_ITEM_H        equ 16              ; Item height
FILES_MAX_VISIBLE   equ 30              ; Max visible items

; Directory entry (32 bytes each in FAT32)
ENTRY_NAME          equ 0               ; 11 bytes (8.3 format)
ENTRY_ATTR          equ 11              ; 1 byte
ENTRY_SIZE          equ 28              ; 4 bytes (file size)

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_INIT - Initialize file manager
; ═══════════════════════════════════════════════════════════════════════════════
files_init:
    push rax
    push rbx

    ; Reset state
    mov byte [files_state], FILES_STATE_BROWSE
    mov byte [files_view_mode], VIEW_2D
    mov byte [files_dialog_type], DIALOG_NONE
    mov dword [files_selected], 0
    mov dword [files_scroll_offset], 0
    mov dword [files_entry_count], 0

    ; Set current path to root
    mov byte [files_current_path], '/'
    mov byte [files_current_path + 1], 0

    ; Load root directory
    call files_load_directory

    pop rbx
    pop rax
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_LOAD_DIRECTORY - Load current directory entries
; ═══════════════════════════════════════════════════════════════════════════════
files_load_directory:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Check if FAT32 is mounted
    call fat32_is_mounted
    test al, al
    jz .no_fs

    ; Get root cluster (for now, always start at root)
    ; In a full implementation, we'd parse files_current_path
    mov eax, [fat32_root_cluster]
    mov [files_current_cluster], eax

    ; Read directory entries
    mov rdi, files_entries_buffer
    mov esi, eax                    ; cluster number
    call fat32_list_dir

    ; Count entries
    mov rdi, files_entries_buffer
    xor ecx, ecx                    ; entry count
.count_loop:
    cmp byte [rdi], 0               ; End of entries?
    je .count_done
    cmp byte [rdi], 0xE5            ; Deleted entry?
    je .count_next
    ; Skip volume label and system entries
    mov al, [rdi + ENTRY_ATTR]
    test al, 0x08                   ; Volume label?
    jnz .count_next
    test al, 0x02                   ; Hidden?
    jnz .count_next
    inc ecx
.count_next:
    add rdi, 32                     ; Next entry
    cmp ecx, FILES_MAX_VISIBLE * 2  ; Limit entries
    jl .count_loop
.count_done:
    mov [files_entry_count], ecx
    jmp .done

.no_fs:
    ; No filesystem - show empty
    mov dword [files_entry_count], 0

.done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_MAIN - Main file manager loop (called from main_loop)
; ═══════════════════════════════════════════════════════════════════════════════
files_main:
    ; MINIMAL - just return immediately to test Tab
    ret

str_files_sel:      db "Selected: ", 0
str_entry_projects: db "[DIR] PROJECTS", 0
str_entry_readme:   db "      README.TXT", 0
str_entry_hello:    db "      HELLO.ASM", 0

; OLD complex code below - disabled
%if 0
    call files_draw_dialog

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_2D - Draw 2D list view
; ═══════════════════════════════════════════════════════════════════════════════
files_draw_2d:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11

    ; Clear screen
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    mov ebx, [screen_height]
    imul eax, ebx
    mov ecx, eax
    mov eax, FILES_BG
.clear_loop:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .clear_loop

    ; Draw header bar
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    imul eax, FILES_HEADER_H
    mov ecx, eax
    mov eax, FILES_HEADER_BG
.header_loop:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .header_loop

    ; Draw header text "FILES"
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 6
    add rdi, rax
    add rdi, 40                     ; x offset (in bytes = pixels * 4)
    mov rsi, str_files_header
    mov r8d, FILES_TEXT
    call draw_text

    ; Draw current path
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 32
    add rdi, rax
    add rdi, 40
    mov rsi, str_path_prefix
    mov r8d, FILES_TEXT_DIM
    call draw_text

    ; Draw path value
    add rdi, 48                     ; After "Path: "
    mov rsi, files_current_path
    mov r8d, FILES_TEXT
    call draw_text

    ; Draw column headers
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, FILES_LIST_Y - 16
    add rdi, rax
    add rdi, FILES_LIST_X * 4
    mov rsi, str_col_name
    mov r8d, FILES_TEXT_DIM
    call draw_text

    ; "Size" column
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, FILES_LIST_Y - 16
    add rdi, rax
    add rdi, 300 * 4                ; Size column X
    mov rsi, str_col_size
    mov r8d, FILES_TEXT_DIM
    call draw_text

    ; Draw file list
    mov r10d, [files_scroll_offset]
    mov r11d, [files_entry_count]
    test r11d, r11d
    jz .no_files

    mov rsi, files_entries_buffer
    xor r9d, r9d                    ; visible index
    xor ecx, ecx                    ; entry index in buffer

.draw_entries:
    cmp byte [rsi], 0               ; End of entries?
    je .entries_done
    cmp byte [rsi], 0xE5            ; Deleted?
    je .next_entry_raw

    ; Skip hidden/volume entries
    mov al, [rsi + ENTRY_ATTR]
    test al, 0x08
    jnz .next_entry_raw
    test al, 0x02
    jnz .next_entry_raw

    ; Check if in visible range
    cmp ecx, r10d
    jl .next_entry
    mov eax, r10d
    add eax, FILES_MAX_VISIBLE
    cmp ecx, eax
    jge .entries_done

    ; Calculate Y position
    mov eax, r9d
    imul eax, FILES_ITEM_H
    add eax, FILES_LIST_Y
    mov r8d, eax                    ; r8d = Y position

    ; Check if selected
    mov eax, ecx
    cmp eax, [files_selected]
    jne .not_selected

    ; Draw selection highlight
    push rcx
    push rsi
    mov edi, FILES_LIST_X - 4
    mov esi, r8d
    sub esi, 2
    mov edx, [screen_width]
    sub edx, FILES_LIST_X * 2
    mov ecx, FILES_ITEM_H
    push r8
    mov r8d, FILES_SELECTED_BG
    call fill_rect
    pop r8
    pop rsi
    pop rcx

.not_selected:
    ; Draw folder/file icon indicator
    mov al, [rsi + ENTRY_ATTR]
    test al, 0x10                   ; Directory?
    jz .is_file

    ; It's a folder - draw folder indicator
    push rcx
    push rsi
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r8d
    add rdi, rax
    add rdi, FILES_LIST_X * 4
    mov rsi, str_folder_icon
    push r8
    mov r8d, FILES_FOLDER_COL
    call draw_text
    pop r8
    pop rsi
    pop rcx
    jmp .draw_name

.is_file:
    ; Draw file indicator
    push rcx
    push rsi
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r8d
    add rdi, rax
    add rdi, FILES_LIST_X * 4
    mov rsi, str_file_icon
    push r8
    mov r8d, FILES_FILE_COL
    call draw_text
    pop r8
    pop rsi
    pop rcx

.draw_name:
    ; Convert and draw filename
    push rcx
    push rsi
    push r8

    ; Copy 8.3 name to buffer and convert
    mov rdi, files_name_buffer
    push rsi
    ; Copy first 8 chars (name)
    mov ecx, 8
.copy_name:
    mov al, [rsi]
    cmp al, ' '
    je .name_done
    mov [rdi], al
    inc rsi
    inc rdi
    dec ecx
    jnz .copy_name
.name_done:
    pop rsi

    ; Check for extension
    mov al, [rsi + 8]
    cmp al, ' '
    je .no_ext
    mov byte [rdi], '.'
    inc rdi
    mov al, [rsi + 8]
    cmp al, ' '
    je .no_ext
    mov [rdi], al
    inc rdi
    mov al, [rsi + 9]
    cmp al, ' '
    je .no_ext
    mov [rdi], al
    inc rdi
    mov al, [rsi + 10]
    cmp al, ' '
    je .no_ext
    mov [rdi], al
    inc rdi
.no_ext:
    mov byte [rdi], 0               ; Null terminate

    pop r8

    ; Draw the name
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r8d
    add rdi, rax
    add rdi, (FILES_LIST_X + 24) * 4  ; After icon
    mov rsi, files_name_buffer
    mov r8d, FILES_TEXT
    call draw_text

    pop rsi
    pop rcx

    ; Draw size (for files only)
    mov al, [rsi + ENTRY_ATTR]
    test al, 0x10
    jnz .skip_size

    push rcx
    push rsi

    mov eax, [rsi + ENTRY_SIZE]
    mov rdi, files_size_buffer
    call files_format_size

    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r8d
    add rdi, rax
    add rdi, 300 * 4
    mov rsi, files_size_buffer
    mov r8d, FILES_TEXT_DIM
    call draw_text

    pop rsi
    pop rcx

.skip_size:
    inc r9d                         ; Next visible item

.next_entry:
    inc ecx                         ; Next entry index
.next_entry_raw:
    add rsi, 32                     ; Next FAT32 entry
    jmp .draw_entries

.no_files:
    ; Draw "No files" message
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, FILES_LIST_Y + 20
    add rdi, rax
    add rdi, FILES_LIST_X * 4
    mov rsi, str_no_files
    mov r8d, FILES_TEXT_DIM
    call draw_text

.entries_done:
    ; Draw footer
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, FILES_FOOTER_H
    imul eax, [screen_pitch]
    add rdi, rax
    mov eax, [screen_width]
    imul eax, FILES_FOOTER_H
    mov ecx, eax
    mov eax, FILES_HEADER_BG
.footer_loop:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .footer_loop

    ; Draw footer text
    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, FILES_FOOTER_H - 4
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 40
    mov rsi, str_footer_help
    mov r8d, FILES_TEXT_DIM
    call draw_text

    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_3D - Draw 3D floating nodes view
; ═══════════════════════════════════════════════════════════════════════════════
files_draw_3d:
    ; TODO: Implement 3D view with floating file nodes
    ; For now, just clear to dark and show message
    push rax
    push rbx
    push rcx
    push rdi

    mov rdi, [screen_fb]
    mov eax, [screen_width]
    mov ebx, [screen_height]
    imul eax, ebx
    mov ecx, eax
    mov eax, 0x00100810             ; Dark blue-ish
.clear:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .clear

    ; Draw "3D View - Coming Soon"
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 100
    add rdi, rax
    add rdi, 200
    mov rsi, str_3d_coming
    mov r8d, FILES_TEXT
    call draw_text

    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_EDITOR - Draw text editor
; ═══════════════════════════════════════════════════════════════════════════════
files_draw_editor:
    ; TODO: Implement text editor
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_DIALOG - Draw dialog overlay
; ═══════════════════════════════════════════════════════════════════════════════
files_draw_dialog:
    ; TODO: Implement dialogs
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_HANDLE_KEY - Handle keyboard input for file manager
; Input: bl = scancode
; ═══════════════════════════════════════════════════════════════════════════════
files_handle_key:
    push rax
    push rbx
    push rcx

    ; Check state
    cmp byte [files_state], FILES_STATE_DIALOG
    je .handle_dialog_key
    cmp byte [files_state], FILES_STATE_EDIT
    je .handle_edit_key

    ; Browse mode keys
    cmp bl, 0x48                    ; Up arrow
    je .key_up
    cmp bl, 0x50                    ; Down arrow
    je .key_down
    cmp bl, 0x11                    ; W
    je .key_up
    cmp bl, 0x1F                    ; S
    je .key_down
    cmp bl, 0x1C                    ; Enter
    je .key_enter
    cmp bl, 0x0E                    ; Backspace
    je .key_back
    cmp bl, 0x31                    ; N
    je .key_new
    cmp bl, 0x20                    ; D
    je .key_delete
    cmp bl, 0x13                    ; R
    je .key_rename
    ; Tab is handled in main keyboard handler for mode switching
    ; Use F1 to toggle 2D/3D view instead
    cmp bl, 0x3B                    ; F1 = toggle view
    je .key_toggle_view
    jmp .done

.key_up:
    cmp dword [files_selected], 0
    je .done
    dec dword [files_selected]
    ; Scroll up if needed
    mov eax, [files_selected]
    cmp eax, [files_scroll_offset]
    jge .done
    dec dword [files_scroll_offset]
    jmp .done

.key_down:
    mov eax, [files_selected]
    inc eax
    cmp eax, [files_entry_count]
    jge .done
    mov [files_selected], eax
    ; Scroll down if needed
    mov ecx, [files_scroll_offset]
    add ecx, FILES_MAX_VISIBLE
    cmp eax, ecx
    jl .done
    inc dword [files_scroll_offset]
    jmp .done

.key_enter:
    call files_open_selected
    jmp .done

.key_back:
    ; Go to parent directory
    ; TODO: implement
    jmp .done

.key_new:
    mov byte [files_state], FILES_STATE_DIALOG
    mov byte [files_dialog_type], DIALOG_NEW
    jmp .done

.key_delete:
    mov byte [files_state], FILES_STATE_DIALOG
    mov byte [files_dialog_type], DIALOG_DELETE
    jmp .done

.key_rename:
    mov byte [files_state], FILES_STATE_DIALOG
    mov byte [files_dialog_type], DIALOG_RENAME
    jmp .done

.key_toggle_view:
    xor byte [files_view_mode], 1   ; Toggle between 0 and 1
    jmp .done

.handle_dialog_key:
    cmp bl, 0x01                    ; ESC
    jne .done
    mov byte [files_state], FILES_STATE_BROWSE
    mov byte [files_dialog_type], DIALOG_NONE
    jmp .done

.handle_edit_key:
    cmp bl, 0x01                    ; ESC
    jne .done
    mov byte [files_state], FILES_STATE_BROWSE

.done:
    pop rcx
    pop rbx
    pop rax
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_OPEN_SELECTED - Open selected file or directory
; ═══════════════════════════════════════════════════════════════════════════════
files_open_selected:
    push rax
    push rbx
    push rcx
    push rsi

    ; Find selected entry
    mov rsi, files_entries_buffer
    mov ecx, [files_selected]
    xor ebx, ebx                    ; Current valid index

.find_entry:
    cmp byte [rsi], 0
    je .not_found
    cmp byte [rsi], 0xE5
    je .skip_entry
    mov al, [rsi + ENTRY_ATTR]
    test al, 0x08
    jnz .skip_entry
    test al, 0x02
    jnz .skip_entry

    cmp ebx, ecx
    je .found_entry
    inc ebx
.skip_entry:
    add rsi, 32
    jmp .find_entry

.found_entry:
    ; Check if directory
    mov al, [rsi + ENTRY_ATTR]
    test al, 0x10
    jnz .open_dir

    ; Open file for editing
    mov byte [files_state], FILES_STATE_EDIT
    ; TODO: Load file content
    jmp .done

.open_dir:
    ; Navigate into directory
    ; TODO: Update current_cluster and reload
    jmp .done

.not_found:
.done:
    pop rsi
    pop rcx
    pop rbx
    pop rax
    ret

; ═══════════════════════════════════════════════════════════════════════════════
; FILES_FORMAT_SIZE - Format file size to human readable
; Input: eax = size in bytes, rdi = output buffer
; ═══════════════════════════════════════════════════════════════════════════════
files_format_size:
    push rax
    push rbx
    push rcx
    push rdx

    ; Simple format: just show bytes for now
    ; TODO: Add KB/MB formatting
    mov ebx, 10
    mov ecx, 0
    push rdi

    ; Handle zero
    test eax, eax
    jnz .convert
    mov byte [rdi], '0'
    mov byte [rdi + 1], ' '
    mov byte [rdi + 2], 'B'
    mov byte [rdi + 3], 0
    jmp .format_done

.convert:
    ; Convert to decimal string (reversed)
    add rdi, 12                     ; Start from end
    mov byte [rdi], 0               ; Null terminate
    dec rdi
    mov byte [rdi], 'B'
    dec rdi
    mov byte [rdi], ' '
    dec rdi

.digit_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    mov [rdi], dl
    dec rdi
    inc ecx
    test eax, eax
    jnz .digit_loop

    ; Move to start of buffer
    inc rdi
    pop rax                         ; Original rdi
    push rsi
    mov rsi, rdi
.copy_loop:
    mov cl, [rsi]
    mov [rax], cl
    inc rax
    inc rsi
    test cl, cl
    jnz .copy_loop
    pop rsi
    jmp .done

.format_done:
    pop rdi

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

%endif
; End of disabled complex code

; ═══════════════════════════════════════════════════════════════════════════════
; DATA
; ═══════════════════════════════════════════════════════════════════════════════

; Strings (prefixed to avoid conflicts with go64.asm)
fui_files_header:   db "FILES", 0
fui_path_prefix:    db "Path: /", 0
fui_col_name:       db "Name", 0
fui_col_size:       db "Size", 0
fui_folder_icon:    db "[D]", 0
fui_file_icon:      db " - ", 0
fui_no_files:       db "No files found (filesystem not mounted?)", 0
fui_footer_help:    db "[W/S] Navigate  [ENTER] Open  [N] New  [D] Delete  [R] Rename  [F1] 3D View", 0
fui_3d_coming:      db "3D View - Press TAB to switch back to 2D", 0

; State variables
files_state:            db FILES_STATE_BROWSE
files_view_mode:        db VIEW_2D
files_dialog_type:      db DIALOG_NONE
; files_selected is defined in go64.asm
files_scroll_offset:    dd 0
files_entry_count:      dd 0
files_current_cluster:  dd 0

; Buffers
files_current_path:     times 256 db 0
files_name_buffer:      times 16 db 0
files_size_buffer:      times 16 db 0
files_input_buffer:     times 64 db 0

; Directory entries buffer (max 64 entries * 32 bytes = 2KB)
files_entries_buffer:   times 2048 db 0
