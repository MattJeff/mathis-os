; ============================================================================
; FILES_INPUT_MOD.ASM - File Manager Input Handling
; ============================================================================
; Mouse and keyboard input for file browser
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
WIN_X                   equ 8
WIN_Y                   equ 12
WIN_W                   equ 16
WIN_H                   equ 20
TITLE_HEIGHT            equ 24
HEADER_HEIGHT           equ 25
ENTRY_HEIGHT            equ 20
TOOLBAR_HEIGHT          equ 30
TOOLBAR_BTN_W           equ 70
TOOLBAR_BTN_GAP         equ 5

DIALOG_NEW_FILE         equ 1
DIALOG_NEW_FOLDER       equ 2
DIALOG_RENAME           equ 3
DIALOG_DELETE           equ 4

; ============================================================================
; EXPORTS
; ============================================================================
global files_on_input
global files_on_key

; ============================================================================
; IMPORTS
; ============================================================================
extern files_selected
extern files_count
extern files_dialog_state
extern files_dialog_open
extern files_dialog_close
extern files_dialog_on_key
extern files_dialog_on_click

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; files_on_input - Handle mouse click
; Input: RDI = window, ESI = x, EDX = y
; ----------------------------------------------------------------------------
files_on_input:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi

    ; Convert to client-relative coords
    mov r12d, esi
    sub r12d, [rbx + WIN_X]
    mov r13d, edx
    sub r13d, [rbx + WIN_Y]
    sub r13d, TITLE_HEIGHT

    ; If dialog is open, handle dialog click
    cmp dword [files_dialog_state], 0
    jne .dialog_click

    ; Check toolbar click
    cmp r13d, TOOLBAR_HEIGHT
    jl .check_toolbar

    ; Check file entry click
    mov eax, r13d
    sub eax, TOOLBAR_HEIGHT + HEADER_HEIGHT
    cmp eax, 0
    jl .done

    xor edx, edx
    mov ecx, ENTRY_HEIGHT
    div ecx

    cmp eax, [files_count]
    jge .done

    mov [files_selected], eax
    jmp .done

.check_toolbar:
    ; Check which toolbar button
    cmp r12d, 10
    jl .done
    sub r12d, 10

    mov eax, r12d
    xor edx, edx
    mov ecx, TOOLBAR_BTN_W + TOOLBAR_BTN_GAP
    div ecx

    cmp eax, 0
    je .new_file
    cmp eax, 1
    je .new_folder
    cmp eax, 2
    je .rename
    cmp eax, 3
    je .delete
    jmp .done

.new_file:
    mov edi, DIALOG_NEW_FILE
    call files_dialog_open
    jmp .done

.new_folder:
    mov edi, DIALOG_NEW_FOLDER
    call files_dialog_open
    jmp .done

.rename:
    mov edi, DIALOG_RENAME
    call files_dialog_open
    jmp .done

.delete:
    mov edi, DIALOG_DELETE
    call files_dialog_open
    jmp .done

.dialog_click:
    ; Pass to dialog handler with actual window center
    ; Save original click coords
    push rsi                            ; original esi (x)
    push rdx                            ; original edx (y)

    ; Calculate dialog center from window dims
    mov eax, [rbx + WIN_X]
    mov ecx, [rbx + WIN_W]
    shr ecx, 1
    add eax, ecx                        ; center_x = win_x + win_w/2
    mov edx, eax                        ; edx = center_x

    mov eax, [rbx + WIN_Y]
    add eax, TITLE_HEIGHT
    mov ecx, [rbx + WIN_H]
    sub ecx, TITLE_HEIGHT
    shr ecx, 1
    add eax, ecx                        ; center_y = win_y + title + (h-title)/2
    mov ecx, eax                        ; ecx = center_y

    pop rax                             ; original y
    mov esi, eax
    pop rax                             ; original x
    mov edi, eax

    call files_dialog_on_click

    cmp al, 1
    je .dialog_confirm
    cmp al, 2
    je .dialog_cancel
    jmp .done

.dialog_confirm:
    ; TODO: Execute action based on dialog type
    call files_dialog_close
    jmp .done

.dialog_cancel:
    call files_dialog_close

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; files_on_key - Handle key press
; Input: EDI = scancode
; ----------------------------------------------------------------------------
files_on_key:
    push rbx

    ; If dialog is open, pass to dialog
    cmp dword [files_dialog_state], 0
    jne .dialog_key

    ; Up arrow
    cmp edi, 0x48
    je .key_up
    ; Down arrow
    cmp edi, 0x50
    je .key_down
    ; N key (new file)
    cmp edi, 0x31
    je .key_new
    ; Delete key
    cmp edi, 0x53
    je .key_delete
    ; F2 (rename)
    cmp edi, 0x3C
    je .key_rename
    jmp .done

.key_up:
    cmp dword [files_selected], 0
    je .done
    dec dword [files_selected]
    jmp .done

.key_down:
    mov eax, [files_selected]
    inc eax
    cmp eax, [files_count]
    jge .done
    mov [files_selected], eax
    jmp .done

.key_new:
    mov edi, DIALOG_NEW_FILE
    call files_dialog_open
    jmp .done

.key_delete:
    mov edi, DIALOG_DELETE
    call files_dialog_open
    jmp .done

.key_rename:
    mov edi, DIALOG_RENAME
    call files_dialog_open
    jmp .done

.dialog_key:
    call files_dialog_on_key
    cmp al, 1
    je .dialog_confirm
    cmp al, 2
    je .dialog_cancel
    jmp .done

.dialog_confirm:
    call files_dialog_close
    jmp .done

.dialog_cancel:
    call files_dialog_close

.done:
    pop rbx
    ret
