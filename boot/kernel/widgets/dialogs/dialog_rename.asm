; ════════════════════════════════════════════════════════════════════════════
; DIALOG_RENAME.ASM - Rename Dialog (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Dialog for renaming files/folders
; Shows current name and input for new name
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_RENAME STRUCTURE (extends Dialog + 40 bytes)
; ════════════════════════════════════════════════════════════════════════════
DIALOG_RENAME_SIZE  equ DIALOG_SIZE + 40

; Extra fields
DR_OLD_NAME         equ DIALOG_SIZE + 0     ; Current filename (8 bytes)
DR_NEW_NAME_BUF     equ DIALOG_SIZE + 8     ; New name buffer (8 bytes)
DR_NEW_NAME_LEN     equ DIALOG_SIZE + 16    ; New name length (4 bytes)
DR_NEW_NAME_MAX     equ DIALOG_SIZE + 20    ; Max length (4 bytes)
DR_CURSOR_POS       equ DIALOG_SIZE + 24    ; Cursor position (4 bytes)

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_RENAME V-TABLE
; ════════════════════════════════════════════════════════════════════════════
dialog_rename_vtable:
    dq dialog_rename_draw   ; VT_DRAW (override)
    dq dialog_rename_on_key ; VT_ON_KEY (override)
    dq dialog_on_click      ; VT_ON_CLICK (inherited)
    dq dialog_on_focus      ; VT_ON_FOCUS (inherited)
    dq dialog_rename_destroy ; VT_DESTROY (override)

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_RENAME_CREATE - Create rename dialog
; Input:  RSI = current filename string
; Output: RAX = dialog widget pointer (or 0)
; ════════════════════════════════════════════════════════════════════════════
dialog_rename_create:
    push rbx
    push r12

    mov r12, rsi                    ; old filename

    ; Allocate dialog
    mov rdi, DIALOG_RENAME_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    mov rbx, rax

    ; Allocate new name buffer (64 chars)
    mov rdi, 64
    call kmalloc
    test rax, rax
    jz .fail_free

    mov [rbx + DR_NEW_NAME_BUF], rax

    ; Copy old name to new name buffer as starting point
    push rbx
    mov rdi, rax
    mov rsi, r12
    xor ecx, ecx
.copy_name:
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    test al, al
    jz .copy_done
    inc ecx
    cmp ecx, 63
    jl .copy_name
    mov byte [rdi + rcx], 0
.copy_done:
    mov [rbx + DR_NEW_NAME_LEN], ecx
    mov [rbx + DR_CURSOR_POS], ecx  ; Cursor at end
    pop rbx

    ; Calculate centered position (300x160)
    mov eax, [screen_width]
    sub eax, 300
    shr eax, 1

    mov ecx, [screen_height]
    sub ecx, 160
    shr ecx, 1

    ; Initialize base widget fields
    lea rdx, [dialog_rename_vtable]
    mov qword [rbx + W_VTABLE], rdx
    mov dword [rbx + W_X], eax
    mov dword [rbx + W_Y], ecx
    mov dword [rbx + W_W], 300
    mov dword [rbx + W_H], 160
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_FOCUSED | WF_MODAL | WF_DIRTY
    mov ecx, [widget_next_id]
    mov [rbx + W_ID], ecx
    inc dword [widget_next_id]
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Initialize dialog fields
    mov qword [rbx + DLG_TITLE], dr_title
    mov qword [rbx + DLG_BTN1_TEXT], dlg_btn_cancel
    mov qword [rbx + DLG_BTN2_TEXT], dr_btn_rename
    mov dword [rbx + DLG_SELECTED_BTN], 1
    mov dword [rbx + DLG_RESULT], DLG_RESULT_NONE
    mov qword [rbx + DLG_ON_CONFIRM], 0
    mov qword [rbx + DLG_ON_CANCEL], 0

    mov dword [rbx + DLG_BG_COLOR], 0x00353535
    mov dword [rbx + DLG_BORDER_COLOR], 0x00606060
    mov dword [rbx + DLG_TITLE_BG], 0x00404040
    mov dword [rbx + DLG_BTN_COLOR], 0x00505050

    ; Initialize rename specific fields
    mov qword [rbx + DR_OLD_NAME], r12
    mov dword [rbx + DR_NEW_NAME_MAX], 63

    mov rax, rbx
    jmp .done

.fail_free:
    mov rdi, rbx
    call kfree
.fail:
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_RENAME_DRAW - Render the rename dialog
; ════════════════════════════════════════════════════════════════════════════
dialog_rename_draw:
    push rbx
    push r12
    push r13

    mov rbx, rdi

    ; Draw base dialog first
    call dialog_draw

    ; Draw "Current:" label
    mov r12d, [rbx + W_X]
    add r12d, 20
    mov r13d, [rbx + W_Y]
    add r13d, 40

    mov edi, r12d
    mov esi, r13d
    mov rdx, dr_label_current
    mov ecx, 0x00AAAAAA
    call video_text

    ; Draw current name
    add r12d, 80
    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + DR_OLD_NAME]
    test rdx, rdx
    jz .no_old
    mov ecx, 0x00CCCCCC
    call video_text
.no_old:

    ; Draw "New name:" label
    mov r12d, [rbx + W_X]
    add r12d, 20
    add r13d, 24

    mov edi, r12d
    mov esi, r13d
    mov rdx, dr_label_newname
    mov ecx, 0x00AAAAAA
    call video_text

    ; Draw input field background
    add r13d, 16
    mov edi, r12d
    mov esi, r13d
    mov edx, [rbx + W_W]
    sub edx, 40
    mov ecx, 24
    mov r8d, 0x00252525
    call fill_rect

    ; Draw input field border
    mov edi, r12d
    mov esi, r13d
    mov edx, [rbx + W_W]
    sub edx, 40
    mov ecx, 24
    mov r8d, 0x00707070
    call draw_rect

    ; Draw new name text
    add r12d, 6
    add r13d, 6
    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + DR_NEW_NAME_BUF]
    mov ecx, 0x00FFFFFF
    call video_text

    ; Draw cursor
    mov eax, [rbx + DR_CURSOR_POS]
    shl eax, 3
    add eax, r12d
    mov edi, eax
    mov esi, r13d
    sub esi, 2
    mov edx, 2
    mov ecx, 12
    mov r8d, 0x00FFFFFF
    call fill_rect

    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_RENAME_ON_KEY - Handle keyboard input
; ════════════════════════════════════════════════════════════════════════════
dialog_rename_on_key:
    push rbx
    mov rbx, rdi

    ; Left arrow
    cmp esi, 0x4B
    je .cursor_left

    ; Right arrow
    cmp esi, 0x4D
    je .cursor_right

    ; Backspace
    cmp esi, 0x0E
    je .backspace

    ; Enter
    cmp esi, 0x1C
    je .confirm

    ; Escape
    cmp esi, 0x01
    je .cancel

    ; Tab (switch buttons)
    cmp esi, 0x0F
    je .switch_btn

    ; Printable character
    call scancode_to_ascii
    test al, al
    jz .not_handled

    ; Insert character
    mov ecx, [rbx + DR_NEW_NAME_LEN]
    cmp ecx, [rbx + DR_NEW_NAME_MAX]
    jge .handled

    mov rdi, [rbx + DR_NEW_NAME_BUF]
    add rdi, rcx
    mov [rdi], al
    mov byte [rdi + 1], 0
    inc dword [rbx + DR_NEW_NAME_LEN]
    inc dword [rbx + DR_CURSOR_POS]
    jmp .mark_dirty

.cursor_left:
    cmp dword [rbx + DR_CURSOR_POS], 0
    je .handled
    dec dword [rbx + DR_CURSOR_POS]
    jmp .mark_dirty

.cursor_right:
    mov eax, [rbx + DR_CURSOR_POS]
    cmp eax, [rbx + DR_NEW_NAME_LEN]
    jge .handled
    inc dword [rbx + DR_CURSOR_POS]
    jmp .mark_dirty

.backspace:
    cmp dword [rbx + DR_NEW_NAME_LEN], 0
    je .handled
    dec dword [rbx + DR_NEW_NAME_LEN]
    dec dword [rbx + DR_CURSOR_POS]
    mov rdi, [rbx + DR_NEW_NAME_BUF]
    mov ecx, [rbx + DR_NEW_NAME_LEN]
    mov byte [rdi + rcx], 0
    jmp .mark_dirty

.switch_btn:
    xor dword [rbx + DLG_SELECTED_BTN], 1
    jmp .mark_dirty

.confirm:
    cmp dword [rbx + DLG_SELECTED_BTN], 0
    je .cancel
    mov dword [rbx + DLG_RESULT], DLG_RESULT_OK
    mov rax, [rbx + DLG_ON_CONFIRM]
    test rax, rax
    jz .handled
    mov rdi, rbx
    call rax
    jmp .handled

.cancel:
    mov dword [rbx + DLG_RESULT], DLG_RESULT_CANCEL
    mov rax, [rbx + DLG_ON_CANCEL]
    test rax, rax
    jz .handled
    mov rdi, rbx
    call rax
    jmp .handled

.mark_dirty:
    or dword [rbx + W_FLAGS], WF_DIRTY

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_RENAME_DESTROY - Free resources
; ════════════════════════════════════════════════════════════════════════════
dialog_rename_destroy:
    push rbx
    mov rbx, rdi

    mov rdi, [rbx + DR_NEW_NAME_BUF]
    test rdi, rdi
    jz .done
    call kfree

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_RENAME_GET_NEW_NAME - Get new filename
; Input:  RDI = dialog
; Output: RAX = new name buffer pointer
; ════════════════════════════════════════════════════════════════════════════
dialog_rename_get_new_name:
    xor eax, eax
    test rdi, rdi
    jz .done
    mov rax, [rdi + DR_NEW_NAME_BUF]
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
dr_title:           db "RENAME", 0
dr_btn_rename:      db "RENAME", 0
dr_label_current:   db "Current:", 0
dr_label_newname:   db "New name:", 0
