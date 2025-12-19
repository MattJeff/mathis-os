; ════════════════════════════════════════════════════════════════════════════
; DIALOG_DELETE.ASM - Delete Confirmation Dialog (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Confirmation dialog before deleting a file/folder
; Shows warning icon and filename
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_DELETE STRUCTURE (extends Dialog + 16 bytes)
; ════════════════════════════════════════════════════════════════════════════
DIALOG_DELETE_SIZE  equ DIALOG_SIZE + 16

; Extra fields
DD_FILENAME         equ DIALOG_SIZE + 0     ; Filename to delete (8 bytes)
DD_IS_FOLDER        equ DIALOG_SIZE + 8     ; Is it a folder? (4 bytes)

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_DELETE V-TABLE
; ════════════════════════════════════════════════════════════════════════════
dialog_delete_vtable:
    dq dialog_delete_draw   ; VT_DRAW (override)
    dq dialog_on_key        ; VT_ON_KEY (inherited)
    dq dialog_on_click      ; VT_ON_CLICK (inherited)
    dq dialog_on_focus      ; VT_ON_FOCUS (inherited)
    dq dialog_destroy       ; VT_DESTROY (inherited)

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_DELETE_CREATE - Create delete confirmation dialog
; Input:  RSI = filename string, EDX = is_folder (0/1)
; Output: RAX = dialog widget pointer (or 0)
; ════════════════════════════════════════════════════════════════════════════
dialog_delete_create:
    push rbx
    push r12
    push r13

    mov r12, rsi                    ; filename
    mov r13d, edx                   ; is_folder

    ; Allocate dialog
    mov rdi, DIALOG_DELETE_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    mov rbx, rax

    ; Calculate centered position (280x150)
    mov eax, [screen_width]
    sub eax, 280
    shr eax, 1

    mov ecx, [screen_height]
    sub ecx, 150
    shr ecx, 1

    ; Initialize base widget fields
    lea rdx, [dialog_delete_vtable]
    mov qword [rbx + W_VTABLE], rdx
    mov dword [rbx + W_X], eax
    mov dword [rbx + W_Y], ecx
    mov dword [rbx + W_W], 280
    mov dword [rbx + W_H], 150
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_FOCUSED | WF_MODAL | WF_DIRTY
    mov ecx, [widget_next_id]
    mov [rbx + W_ID], ecx
    inc dword [widget_next_id]
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Initialize dialog fields
    mov qword [rbx + DLG_TITLE], dd_title
    mov qword [rbx + DLG_BTN1_TEXT], dlg_btn_cancel
    mov qword [rbx + DLG_BTN2_TEXT], dd_btn_delete
    mov dword [rbx + DLG_SELECTED_BTN], 0       ; Default to Cancel (safer!)
    mov dword [rbx + DLG_RESULT], DLG_RESULT_NONE
    mov qword [rbx + DLG_ON_CONFIRM], 0
    mov qword [rbx + DLG_ON_CANCEL], 0

    mov dword [rbx + DLG_BG_COLOR], 0x00353535
    mov dword [rbx + DLG_BORDER_COLOR], 0x00606060
    mov dword [rbx + DLG_TITLE_BG], 0x00804040      ; Red-ish title bar for warning
    mov dword [rbx + DLG_BTN_COLOR], 0x00505050

    ; Initialize delete specific fields
    mov qword [rbx + DD_FILENAME], r12
    mov dword [rbx + DD_IS_FOLDER], r13d

    mov rax, rbx
    jmp .done

.fail:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_DELETE_DRAW - Render the delete dialog
; ════════════════════════════════════════════════════════════════════════════
dialog_delete_draw:
    push rbx
    push r12
    push r13

    mov rbx, rdi

    ; Draw base dialog first
    call dialog_draw

    ; Draw warning message
    mov r12d, [rbx + W_X]
    add r12d, 20
    mov r13d, [rbx + W_Y]
    add r13d, 45

    mov edi, r12d
    mov esi, r13d
    mov rdx, dd_msg_confirm
    mov ecx, 0x00CCCCCC
    call video_text

    ; Draw filename with icon
    add r13d, 24

    ; Icon based on type
    mov edi, r12d
    mov esi, r13d
    cmp dword [rbx + DD_IS_FOLDER], 0
    je .file_icon
    mov rdx, dd_icon_folder
    jmp .draw_icon
.file_icon:
    mov rdx, dd_icon_file
.draw_icon:
    mov ecx, 0x00FFFF00             ; Yellow
    call video_text

    ; Filename
    add r12d, 24
    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + DD_FILENAME]
    test rdx, rdx
    jz .no_filename
    mov ecx, 0x00FFFFFF
    call video_text

.no_filename:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_DELETE_GET_FILENAME - Get filename being deleted
; Input:  RDI = dialog
; Output: RAX = filename string pointer
; ════════════════════════════════════════════════════════════════════════════
dialog_delete_get_filename:
    xor eax, eax
    test rdi, rdi
    jz .done
    mov rax, [rdi + DD_FILENAME]
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
dd_title:           db "DELETE", 0
dd_btn_delete:      db "DELETE", 0
dd_msg_confirm:     db "Are you sure you want to delete:", 0
dd_icon_file:       db "[F]", 0
dd_icon_folder:     db "[D]", 0
