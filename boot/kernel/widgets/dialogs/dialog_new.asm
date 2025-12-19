; ════════════════════════════════════════════════════════════════════════════
; DIALOG_NEW.ASM - New File/Folder Dialog (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Dialog for creating new files or folders
; Has: Type selector (File/Folder), Name input field
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_NEW STRUCTURE (extends Dialog + 32 bytes)
; ════════════════════════════════════════════════════════════════════════════
DIALOG_NEW_SIZE     equ DIALOG_SIZE + 32

; Extra fields
DN_IS_FOLDER        equ DIALOG_SIZE + 0     ; 0 = file, 1 = folder (4 bytes)
DN_NAME_BUF         equ DIALOG_SIZE + 4     ; Name buffer pointer (8 bytes)
DN_NAME_LEN         equ DIALOG_SIZE + 12    ; Current name length (4 bytes)
DN_NAME_MAX         equ DIALOG_SIZE + 16    ; Max name length (4 bytes)
DN_CURSOR_POS       equ DIALOG_SIZE + 20    ; Cursor in name field (4 bytes)

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_NEW V-TABLE (override base dialog)
; ════════════════════════════════════════════════════════════════════════════
dialog_new_vtable:
    dq dialog_new_draw      ; VT_DRAW (override)
    dq dialog_new_on_key    ; VT_ON_KEY (override)
    dq dialog_new_on_click  ; VT_ON_CLICK (override)
    dq dialog_on_focus      ; VT_ON_FOCUS (inherited)
    dq dialog_new_destroy   ; VT_DESTROY (override)

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_NEW_CREATE - Create new file/folder dialog
; Output: RAX = dialog widget pointer (or 0)
; ════════════════════════════════════════════════════════════════════════════
dialog_new_create:
    push rbx
    push r12

    ; Allocate dialog
    mov rdi, DIALOG_NEW_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    mov rbx, rax

    ; Allocate name buffer (64 chars)
    mov rdi, 64
    call kmalloc
    test rax, rax
    jz .fail_free

    mov [rbx + DN_NAME_BUF], rax
    mov r12, rax

    ; Clear name buffer
    mov rdi, r12
    mov rcx, 64
    xor al, al
    rep stosb

    ; Calculate centered position (300x180)
    mov eax, [screen_width]
    sub eax, 300
    shr eax, 1

    mov ecx, [screen_height]
    sub ecx, 180
    shr ecx, 1

    ; Initialize base widget fields
    lea rdx, [dialog_new_vtable]
    mov qword [rbx + W_VTABLE], rdx
    mov dword [rbx + W_X], eax
    mov dword [rbx + W_Y], ecx
    mov dword [rbx + W_W], 300
    mov dword [rbx + W_H], 180
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_FOCUSED | WF_MODAL | WF_DIRTY
    mov ecx, [widget_next_id]
    mov [rbx + W_ID], ecx
    inc dword [widget_next_id]
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Initialize dialog fields
    mov qword [rbx + DLG_TITLE], dn_title
    mov qword [rbx + DLG_BTN1_TEXT], dlg_btn_cancel
    mov qword [rbx + DLG_BTN2_TEXT], dn_btn_create
    mov dword [rbx + DLG_SELECTED_BTN], 1
    mov dword [rbx + DLG_RESULT], DLG_RESULT_NONE
    mov qword [rbx + DLG_ON_CONFIRM], 0
    mov qword [rbx + DLG_ON_CANCEL], 0

    mov dword [rbx + DLG_BG_COLOR], 0x00353535
    mov dword [rbx + DLG_BORDER_COLOR], 0x00606060
    mov dword [rbx + DLG_TITLE_BG], 0x00404040
    mov dword [rbx + DLG_BTN_COLOR], 0x00505050

    ; Initialize dialog_new specific fields
    mov dword [rbx + DN_IS_FOLDER], 0
    mov dword [rbx + DN_NAME_LEN], 0
    mov dword [rbx + DN_NAME_MAX], 63
    mov dword [rbx + DN_CURSOR_POS], 0

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
; DIALOG_NEW_DRAW - Render the new dialog
; ════════════════════════════════════════════════════════════════════════════
dialog_new_draw:
    push rbx
    push r12
    push r13

    mov rbx, rdi

    ; Draw base dialog first
    call dialog_draw

    ; Draw type selector label
    mov r12d, [rbx + W_X]
    add r12d, 20
    mov r13d, [rbx + W_Y]
    add r13d, 45

    mov edi, r12d
    mov esi, r13d
    mov rdx, dn_label_type
    mov ecx, 0x00AAAAAA
    call video_text

    ; Draw File radio button
    add r12d, 60
    mov edi, r12d
    mov esi, r13d
    ; Draw circle
    mov edx, 12
    mov ecx, 12
    mov r8d, 0x00606060
    call fill_rect

    ; Fill if selected (file = 0)
    cmp dword [rbx + DN_IS_FOLDER], 0
    jne .not_file
    add edi, 3
    add esi, 3
    mov edx, 6
    mov ecx, 6
    mov r8d, 0x0000FF00             ; Green dot
    call fill_rect
    sub edi, 3
    sub esi, 3
.not_file:

    ; "File" text
    add r12d, 16
    mov edi, r12d
    mov esi, r13d
    mov rdx, dn_opt_file
    mov ecx, 0x00CCCCCC
    call video_text

    ; Draw Folder radio button
    add r12d, 60
    mov edi, r12d
    mov esi, r13d
    mov edx, 12
    mov ecx, 12
    mov r8d, 0x00606060
    call fill_rect

    cmp dword [rbx + DN_IS_FOLDER], 1
    jne .not_folder
    add edi, 3
    add esi, 3
    mov edx, 6
    mov ecx, 6
    mov r8d, 0x0000FF00
    call fill_rect
.not_folder:

    add r12d, 16
    mov edi, r12d
    mov esi, r13d
    mov rdx, dn_opt_folder
    mov ecx, 0x00CCCCCC
    call video_text

    ; Draw name label
    mov r12d, [rbx + W_X]
    add r12d, 20
    mov r13d, [rbx + W_Y]
    add r13d, 75

    mov edi, r12d
    mov esi, r13d
    mov rdx, dn_label_name
    mov ecx, 0x00AAAAAA
    call video_text

    ; Draw name input field background
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

    ; Draw name text
    add r12d, 6
    add r13d, 6
    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + DN_NAME_BUF]
    mov ecx, 0x00FFFFFF
    call video_text

    ; Draw cursor
    mov eax, [rbx + DN_CURSOR_POS]
    shl eax, 3                      ; * 8 pixels
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
; DIALOG_NEW_ON_KEY - Handle keyboard input
; ════════════════════════════════════════════════════════════════════════════
dialog_new_on_key:
    push rbx
    mov rbx, rdi

    ; Tab to switch type
    cmp esi, 0x0F
    je .switch_type

    ; Left/Right in button area
    cmp esi, 0x4B
    je .nav_left
    cmp esi, 0x4D
    je .nav_right

    ; Backspace
    cmp esi, 0x0E
    je .backspace

    ; Enter
    cmp esi, 0x1C
    je .confirm

    ; Escape
    cmp esi, 0x01
    je .cancel

    ; Printable character - convert scancode to ASCII
    call scancode_to_ascii
    test al, al
    jz .not_handled

    ; Insert character
    mov ecx, [rbx + DN_NAME_LEN]
    cmp ecx, [rbx + DN_NAME_MAX]
    jge .handled                    ; Buffer full

    mov rdi, [rbx + DN_NAME_BUF]
    add rdi, rcx
    mov [rdi], al
    inc dword [rbx + DN_NAME_LEN]
    inc dword [rbx + DN_CURSOR_POS]
    jmp .mark_dirty

.switch_type:
    xor dword [rbx + DN_IS_FOLDER], 1
    jmp .mark_dirty

.nav_left:
    ; Move cursor or switch button
    cmp dword [rbx + DN_CURSOR_POS], 0
    jne .cursor_left
    xor dword [rbx + DLG_SELECTED_BTN], 1
    jmp .mark_dirty
.cursor_left:
    dec dword [rbx + DN_CURSOR_POS]
    jmp .mark_dirty

.nav_right:
    mov eax, [rbx + DN_CURSOR_POS]
    cmp eax, [rbx + DN_NAME_LEN]
    jge .btn_right
    inc dword [rbx + DN_CURSOR_POS]
    jmp .mark_dirty
.btn_right:
    xor dword [rbx + DLG_SELECTED_BTN], 1
    jmp .mark_dirty

.backspace:
    cmp dword [rbx + DN_NAME_LEN], 0
    je .handled
    dec dword [rbx + DN_NAME_LEN]
    dec dword [rbx + DN_CURSOR_POS]
    mov rdi, [rbx + DN_NAME_BUF]
    mov ecx, [rbx + DN_NAME_LEN]
    mov byte [rdi + rcx], 0
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
; DIALOG_NEW_ON_CLICK - Handle mouse click
; ════════════════════════════════════════════════════════════════════════════
dialog_new_on_click:
    push rbx
    mov rbx, rdi

    ; Check type selector clicks (Y around 45)
    mov eax, [rbx + W_Y]
    add eax, 40
    cmp edx, eax
    jl .check_buttons
    add eax, 20
    cmp edx, eax
    jg .check_input

    ; Check File radio X
    mov eax, [rbx + W_X]
    add eax, 80
    cmp esi, eax
    jl .check_buttons
    add eax, 50
    cmp esi, eax
    jg .check_folder
    mov dword [rbx + DN_IS_FOLDER], 0
    jmp .mark_dirty

.check_folder:
    add eax, 60
    cmp esi, eax
    jg .check_input
    mov dword [rbx + DN_IS_FOLDER], 1
    jmp .mark_dirty

.check_input:
    ; TODO: Set cursor position in input field
    jmp .handled

.check_buttons:
    ; Use base dialog click handler for buttons
    mov rdi, rbx
    call dialog_on_click
    jmp .done

.mark_dirty:
    or dword [rbx + W_FLAGS], WF_DIRTY

.handled:
    mov eax, 1

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_NEW_DESTROY - Free resources
; ════════════════════════════════════════════════════════════════════════════
dialog_new_destroy:
    push rbx
    mov rbx, rdi

    mov rdi, [rbx + DN_NAME_BUF]
    test rdi, rdi
    jz .done
    call kfree

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_NEW_GET_NAME - Get entered name
; Input:  RDI = dialog
; Output: RAX = name buffer pointer
; ════════════════════════════════════════════════════════════════════════════
dialog_new_get_name:
    xor eax, eax
    test rdi, rdi
    jz .done
    mov rax, [rdi + DN_NAME_BUF]
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_NEW_IS_FOLDER - Check if folder was selected
; Input:  RDI = dialog
; Output: EAX = 1 if folder, 0 if file
; ════════════════════════════════════════════════════════════════════════════
dialog_new_is_folder:
    xor eax, eax
    test rdi, rdi
    jz .done
    mov eax, [rdi + DN_IS_FOLDER]
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; SCANCODE_TO_ASCII - Convert scancode to ASCII (simplified)
; Input:  ESI = scancode
; Output: AL = ASCII char (0 if not printable)
; ════════════════════════════════════════════════════════════════════════════
scancode_to_ascii:
    xor eax, eax
    cmp esi, 58
    jg .done
    lea rcx, [scancode_table]
    mov al, [rcx + rsi]
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
dn_title:           db "CREATE NEW", 0
dn_btn_create:      db "CREATE", 0
dn_label_type:      db "Type:", 0
dn_label_name:      db "Name:", 0
dn_opt_file:        db "File", 0
dn_opt_folder:      db "Folder", 0
