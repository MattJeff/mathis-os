; ============================================================================
; FILES_DIALOG_MOD.ASM - File Manager Dialogs
; ============================================================================
; New file/folder, rename, delete confirmation dialogs
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
DIALOG_W                equ 280
DIALOG_H                equ 120
DIALOG_INPUT_H          equ 24
DIALOG_BTN_W            equ 80
DIALOG_BTN_H            equ 28
DIALOG_COLOR_BG         equ 0x00F5F5F5
DIALOG_COLOR_BORDER     equ 0x00AAAAAA
DIALOG_COLOR_INPUT      equ 0x00FFFFFF
DIALOG_COLOR_BTN        equ 0x00E0E0E0
DIALOG_COLOR_BTN_OK     equ 0x000078D7
DIALOG_COLOR_TEXT       equ 0x00000000
DIALOG_COLOR_TEXT_W     equ 0x00FFFFFF

DIALOG_NONE             equ 0
DIALOG_NEW_FILE         equ 1
DIALOG_NEW_FOLDER       equ 2
DIALOG_RENAME           equ 3
DIALOG_DELETE           equ 4
INPUT_MAX_LEN           equ 32

; ============================================================================
; EXPORTS
; ============================================================================
global files_dialog_state
global files_dialog_input
global files_dialog_input_len
global files_dialog_open
global files_dialog_close
global files_dialog_draw
global files_dialog_on_key
global files_dialog_on_click

; ============================================================================
; IMPORTS
; ============================================================================
extern draw_fill_rect
extern text_draw_string_xy

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; files_dialog_open - Open a dialog
; Input: EDI = dialog type (1-4)
; ----------------------------------------------------------------------------
files_dialog_open:
    mov [files_dialog_state], edi
    mov byte [files_dialog_input], 0
    mov dword [files_dialog_input_len], 0
    ret

; ----------------------------------------------------------------------------
; files_dialog_close - Close dialog
; ----------------------------------------------------------------------------
files_dialog_close:
    mov dword [files_dialog_state], DIALOG_NONE
    ret

; ----------------------------------------------------------------------------
; files_dialog_draw - Draw dialog if active
; Input: EDI = center x, ESI = center y
; Output: AL = 1 if dialog is open
; ----------------------------------------------------------------------------
files_dialog_draw:
    push rbx
    push r12
    push r13
    push r14

    cmp dword [files_dialog_state], DIALOG_NONE
    je .not_open

    ; Calculate dialog position (centered)
    mov r12d, edi
    sub r12d, DIALOG_W / 2
    mov r13d, esi
    sub r13d, DIALOG_H / 2

    ; Draw border/shadow
    mov edi, r12d
    sub edi, 2
    mov esi, r13d
    sub esi, 2
    mov edx, DIALOG_W + 4
    mov ecx, DIALOG_H + 4
    mov r8d, DIALOG_COLOR_BORDER
    call draw_fill_rect

    ; Draw background
    mov edi, r12d
    mov esi, r13d
    mov edx, DIALOG_W
    mov ecx, DIALOG_H
    mov r8d, DIALOG_COLOR_BG
    call draw_fill_rect

    ; Draw title based on type
    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 12
    mov eax, [files_dialog_state]
    lea rdx, [str_dlg_new_file]
    cmp eax, DIALOG_NEW_FILE
    je .draw_title
    lea rdx, [str_dlg_new_folder]
    cmp eax, DIALOG_NEW_FOLDER
    je .draw_title
    lea rdx, [str_dlg_rename]
    cmp eax, DIALOG_RENAME
    je .draw_title
    lea rdx, [str_dlg_delete]
.draw_title:
    mov ecx, DIALOG_COLOR_TEXT
    call text_draw_string_xy

    ; Draw input field (skip for delete)
    cmp dword [files_dialog_state], DIALOG_DELETE
    je .skip_input

    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, 35
    mov edx, DIALOG_W - 20
    mov ecx, DIALOG_INPUT_H
    mov r8d, DIALOG_COLOR_INPUT
    call draw_fill_rect

    ; Draw input text
    mov edi, r12d
    add edi, 14
    mov esi, r13d
    add esi, 40
    lea rdx, [files_dialog_input]
    mov ecx, DIALOG_COLOR_TEXT
    call text_draw_string_xy

.skip_input:
    ; Draw buttons
    mov r14d, r13d
    add r14d, DIALOG_H - 40

    ; Cancel button
    mov edi, r12d
    add edi, 50
    mov esi, r14d
    mov edx, DIALOG_BTN_W
    mov ecx, DIALOG_BTN_H
    mov r8d, DIALOG_COLOR_BTN
    call draw_fill_rect

    mov edi, r12d
    add edi, 70
    mov esi, r14d
    add esi, 8
    lea rdx, [str_cancel]
    mov ecx, DIALOG_COLOR_TEXT
    call text_draw_string_xy

    ; OK button
    mov edi, r12d
    add edi, DIALOG_W - 130
    mov esi, r14d
    mov edx, DIALOG_BTN_W
    mov ecx, DIALOG_BTN_H
    mov r8d, DIALOG_COLOR_BTN_OK
    call draw_fill_rect

    mov edi, r12d
    add edi, DIALOG_W - 100
    mov esi, r14d
    add esi, 8
    lea rdx, [str_ok]
    cmp dword [files_dialog_state], DIALOG_DELETE
    jne .ok_text
    lea rdx, [str_delete]
.ok_text:
    mov ecx, DIALOG_COLOR_TEXT_W
    call text_draw_string_xy

    mov al, 1
    jmp .done

.not_open:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; files_dialog_on_key - Handle key press in dialog
; Input: EDI = scancode
; Output: AL = action (0=none, 1=confirm, 2=cancel)
; ----------------------------------------------------------------------------
files_dialog_on_key:
    cmp dword [files_dialog_state], DIALOG_NONE
    je .no_action

    ; ESC = cancel
    cmp edi, 0x01
    je .cancel

    ; Enter = confirm
    cmp edi, 0x1C
    je .confirm

    ; Backspace
    cmp edi, 0x0E
    je .backspace

    ; Character input (simplified - only handles some keys)
    cmp dword [files_dialog_state], DIALOG_DELETE
    je .no_action

    cmp dword [files_dialog_input_len], INPUT_MAX_LEN - 1
    jge .no_action

    call .scancode_to_char
    test al, al
    jz .no_action

    ; Append character
    mov ecx, [files_dialog_input_len]
    mov [files_dialog_input + rcx], al
    inc ecx
    mov [files_dialog_input_len], ecx
    mov byte [files_dialog_input + rcx], 0
    jmp .no_action

.backspace:
    cmp dword [files_dialog_input_len], 0
    je .no_action
    dec dword [files_dialog_input_len]
    mov ecx, [files_dialog_input_len]
    mov byte [files_dialog_input + rcx], 0
    jmp .no_action

.confirm:
    mov al, 1
    ret

.cancel:
    mov al, 2
    ret

.no_action:
    xor eax, eax
    ret

; Convert scancode to ASCII (full map)
.scancode_to_char:
    cmp edi, 0x39               ; Space is last
    ja .no_char
    lea rax, [scancode_map]
    movzx eax, byte [rax + rdi]
    ret
.no_char:
    xor eax, eax
    ret

; ----------------------------------------------------------------------------
; files_dialog_on_click - Handle click in dialog
; Input: EDI = x, ESI = y, EDX = center_x, ECX = center_y
; Output: AL = action (0=none, 1=confirm, 2=cancel)
; ----------------------------------------------------------------------------
files_dialog_on_click:
    push rbx

    cmp dword [files_dialog_state], DIALOG_NONE
    je .no_action

    ; Calculate dialog bounds
    mov eax, edx
    sub eax, DIALOG_W / 2
    mov ebx, ecx
    sub ebx, DIALOG_H / 2

    ; Check Cancel button (relative to dialog)
    mov r8d, edi
    sub r8d, eax
    mov r9d, esi
    sub r9d, ebx
    sub r9d, DIALOG_H - 40

    cmp r8d, 50
    jl .no_action
    cmp r8d, 50 + DIALOG_BTN_W
    jge .check_ok
    cmp r9d, 0
    jl .no_action
    cmp r9d, DIALOG_BTN_H
    jge .no_action
    mov al, 2
    jmp .done

.check_ok:
    cmp r8d, DIALOG_W - 130
    jl .no_action
    cmp r8d, DIALOG_W - 130 + DIALOG_BTN_W
    jge .no_action
    cmp r9d, 0
    jl .no_action
    cmp r9d, DIALOG_BTN_H
    jge .no_action
    mov al, 1
    jmp .done

.no_action:
    xor eax, eax

.done:
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_dlg_new_file:       db "New File", 0
str_dlg_new_folder:     db "New Folder", 0
str_dlg_rename:         db "Rename", 0
str_dlg_delete:         db "Delete this item?", 0
str_cancel:             db "Cancel", 0
str_ok:                 db "OK", 0
str_delete:             db "Delete", 0

; Full scancode to ASCII map (0x00 - 0x39)
; Lowercase only, no shift support yet
scancode_map:
    db 0, 0                      ; 0x00-0x01: none, ESC
    db '1234567890-='            ; 0x02-0x0D: number row
    db 0, 0                      ; 0x0E-0x0F: backspace, tab
    db 'qwertyuiop[]'            ; 0x10-0x1B: QWERTY row
    db 0, 0                      ; 0x1C-0x1D: enter, ctrl
    db 'asdfghjkl'               ; 0x1E-0x26: ASDF row
    db 0, 0, 0, 0, 0             ; 0x27-0x2B: ; ' ` shift \
    db 'zxcvbnm'                 ; 0x2C-0x32: ZXCV row
    db '.', '-', '_', 0, 0, 0    ; 0x33-0x38: . - _ shift * alt
    db ' '                       ; 0x39: space

section .data

files_dialog_state:     dd DIALOG_NONE
files_dialog_input_len: dd 0

section .bss

files_dialog_input:     resb INPUT_MAX_LEN + 1
