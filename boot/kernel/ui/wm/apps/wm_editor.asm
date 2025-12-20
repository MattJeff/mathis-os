; ============================================================================
; WM_EDITOR.ASM - Text editor window for WM
; ============================================================================
; Single Responsibility: Create and manage editor windows
; Uses: text_editor widget from widgets/text_editor.asm
; ============================================================================

[BITS 64]

; Editor window state
wme_editor_ptr:     dq 0            ; Current editor widget pointer
wme_filepath:       times 128 db 0  ; Path of opened file
wme_win_idx:        dd -1           ; Window index

; ============================================================================
; WME_OPEN_FILE - Open file in editor window
; Input: RDI = file path (null-terminated)
; Output: EAX = window index or -1 on error
; ============================================================================
wme_open_file:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi                    ; Save path

    ; Copy path to buffer
    lea rdi, [wme_filepath]
    mov rsi, r12
.copy_path:
    lodsb
    stosb
    test al, al
    jnz .copy_path

    ; Create editor window
    mov edi, WM_TYPE_EDITOR
    mov esi, 80                     ; x
    mov edx, 40                     ; y
    mov ecx, 600                    ; width
    mov r8d, 450                    ; height
    lea r9, [wme_filepath]          ; title = filepath
    call wm_create_window
    cmp eax, -1
    je .error
    mov r13d, eax                   ; r13 = window index
    mov [wme_win_idx], r13d

    ; Get window entry
    mov edi, r13d
    call wm_get_window
    test rax, rax
    jz .error
    mov r14, rax                    ; r14 = window entry

    ; Create text editor widget
    mov edi, [r14 + WM_ENT_X]
    add edi, 2
    mov esi, [r14 + WM_ENT_Y]
    add esi, WM_TITLE_H
    mov edx, [r14 + WM_ENT_W]
    sub edx, 4
    mov ecx, [r14 + WM_ENT_H]
    sub ecx, WM_TITLE_H
    sub ecx, 2
    call text_editor_create
    test rax, rax
    jz .error
    mov [wme_editor_ptr], rax
    mov rbx, rax

    ; Set widget on window
    mov edi, r13d
    mov rsi, rbx
    call wm_set_widget

    ; Try to load file content
    mov rdi, r12
    xor esi, esi                    ; O_RDONLY
    call fs_open
    cmp eax, -1
    je .no_content
    mov r12d, eax                   ; r12 = fd

    ; Get file size via seek to end
    mov edi, r12d
    xor esi, esi
    mov edx, 2                      ; SEEK_END
    call fs_seek
    mov r14d, eax                   ; r14 = size

    ; Seek back to start
    mov edi, r12d
    xor esi, esi
    xor edx, edx                    ; SEEK_SET
    call fs_seek

    ; Read content into temp buffer (max 4KB)
    cmp r14d, 4096
    jle .size_ok
    mov r14d, 4096
.size_ok:
    lea rsi, [wme_temp_buf]
    mov edi, r12d
    mov edx, r14d
    call fs_read

    ; Close file
    mov edi, r12d
    call fs_close

    ; Set text in editor
    mov rdi, [wme_editor_ptr]
    lea rsi, [wme_temp_buf]
    mov edx, r14d
    call text_editor_set_text

.no_content:
    mov eax, r13d
    jmp .done

.error:
    mov eax, -1

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Temp buffer for file loading
wme_temp_buf: times 4096 db 0

; ============================================================================
; WME_DRAW_CONTENT - Draw editor content
; Input: EDI=x, ESI=y, EDX=w, ECX=h (content area)
; ============================================================================
wme_draw_content:
    push rbx

    mov rbx, [wme_editor_ptr]
    test rbx, rbx
    jz .done

    ; Update editor position/size
    mov [rbx + W_X], edi
    mov [rbx + W_Y], esi
    mov [rbx + W_W], edx
    mov [rbx + W_H], ecx

    ; Draw editor
    mov rdi, rbx
    call text_editor_draw

.done:
    pop rbx
    ret

; ============================================================================
; WME_ON_KEY - Handle key in editor
; Input: EDI = scancode
; Output: EAX = 1 if handled
; ============================================================================
wme_on_key:
    push rbx
    push r12

    mov r12d, edi

    mov rbx, [wme_editor_ptr]
    test rbx, rbx
    jz .not_handled

    ; Check Ctrl+S for save
    cmp r12d, 0x1F                  ; S key
    jne .forward
    cmp byte [ctrl_state], 1
    jne .forward
    call wme_save_file
    mov eax, 1
    jmp .done

.forward:
    mov rdi, rbx
    mov esi, r12d
    call text_editor_on_key
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

; ============================================================================
; WME_ON_CLICK - Handle click in editor
; Input: EDI = x (relative), ESI = y (relative)
; Output: EAX = 1
; ============================================================================
wme_on_click:
    push rbx

    mov rbx, [wme_editor_ptr]
    test rbx, rbx
    jz .done

    mov edx, esi
    mov esi, edi
    mov rdi, rbx
    call text_editor_on_click

.done:
    mov eax, 1
    pop rbx
    ret

; ============================================================================
; WME_SAVE_FILE - Save editor content to file
; ============================================================================
; Output: EAX = 1 on success, 0 on failure
; ============================================================================
WME_SAVE_FLAGS  equ 0x0D            ; WRONLY | CREATE | TRUNC

wme_save_file:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, [wme_editor_ptr]
    test rbx, rbx
    jz .save_fail

    ; Get text from editor
    mov rdi, rbx
    call text_editor_get_text
    test rax, rax
    jz .save_fail
    mov r12, rax                    ; text pointer
    mov r13d, edx                   ; length

    ; Open file for writing
    lea rdi, [wme_filepath]
    mov esi, WME_SAVE_FLAGS
    call crud_create_file
    cmp eax, -1
    je .save_fail
    mov r14d, eax                   ; r14 = fd

    ; Write content
    mov edi, r14d
    mov rsi, r12
    mov edx, r13d
    call fs_write
    cmp eax, -1
    je .close_fail

    ; Close file
    mov edi, r14d
    call fs_close

    ; Clear modified flag
    mov dword [rbx + TE_MODIFIED], 0

    ; Show save indicator
    call wme_show_save_indicator

    mov eax, 1
    jmp .save_done

.close_fail:
    mov edi, r14d
    call fs_close

.save_fail:
    xor eax, eax

.save_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WME_SHOW_SAVE_INDICATOR - Flash "Saved!" message
; ============================================================================
wme_show_save_indicator:
    push rdi
    push rsi
    push rdx
    push rcx

    ; Draw "Saved!" at top-left of editor window
    mov edi, [wme_win_idx]
    call wm_get_window
    test rax, rax
    jz .ind_done

    mov edi, [rax + WM_ENT_X]
    add edi, 200
    mov esi, [rax + WM_ENT_Y]
    add esi, 6
    lea rdx, [wme_saved_str]
    mov ecx, 0x0027C93F             ; Green color
    call video_text

    mov byte [wm_dirty], 1

.ind_done:
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    ret

wme_saved_str: db "Saved!", 0

