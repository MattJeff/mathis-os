; ════════════════════════════════════════════════════════════════════════════
; FILES_EDITOR.ASM - Editor functions for Files App
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FA_ON_FILE_SELECT - Called when file is selected (Enter or double-click)
; Input: RDI = widget, ESI = selected index
; ════════════════════════════════════════════════════════════════════════════
fa_on_file_select:
    push rbx
    push rax

    ; Get selected index
    call file_list_get_selected     ; RDI already has widget

    ; Check actual file flags
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

; ════════════════════════════════════════════════════════════════════════════
; FA_OPEN_FILE_EDITOR - Open file in text editor
; ════════════════════════════════════════════════════════════════════════════
fa_open_file_editor:
    push rbx
    push r12
    push r13
    push r14

    ; Get selected index
    mov rdi, [fa_file_list]
    call file_list_get_selected
    mov r12d, eax

    ; Get filename from entry
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

    ; Use fs_read_file helper
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
    ; Fallback to mock content
    mov rdi, [fa_editor]
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
    mov byte [rdi], 'E'
    mov byte [rdi+1], 'D'
    mov byte [rdi+2], 'I'
    mov byte [rdi+3], 'T'
    mov byte [rdi+4], ':'
    mov byte [rdi+5], ' '
    add rdi, 6
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
