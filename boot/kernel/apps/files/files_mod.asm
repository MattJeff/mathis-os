; ============================================================================
; FILES_MOD.ASM - File Manager Application
; ============================================================================
; File browser window with toolbar and CRUD dialogs
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
FILES_WIDTH             equ 500
FILES_HEIGHT            equ 350
WIN_DRAW_CB             equ 32
WIN_INPUT_CB            equ 40
WIN_X                   equ 8
WIN_Y                   equ 12
WIN_W                   equ 16
WIN_H                   equ 20
WIN_TYPE_FILES          equ 4
TITLE_HEIGHT            equ 24
FILES_COLOR_BG          equ 0x00F0F0F0
FILES_COLOR_TOOLBAR     equ 0x00DDDDDD
FILES_COLOR_HEADER      equ 0x00E0E0E0
FILES_COLOR_TEXT        equ 0x00000000
FILES_COLOR_SELECT      equ 0x000078D7
FILES_COLOR_BTN         equ 0x00CCCCCC
FILES_MAX_ENTRIES       equ 32
TOOLBAR_HEIGHT          equ 30
TOOLBAR_BTN_W           equ 70
TOOLBAR_BTN_H           equ 22
TOOLBAR_BTN_GAP         equ 5
HEADER_HEIGHT           equ 25
ENTRY_HEIGHT            equ 20

; ============================================================================
; EXPORTS
; ============================================================================
global files_open
global files_draw
global files_selected
global files_count

; ============================================================================
; IMPORTS
; ============================================================================
extern wm_create_window
extern draw_fill_rect
extern text_draw_string_xy
extern files_on_input
extern files_dialog_state
extern files_dialog_draw

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; files_open - Open file manager window
; Output: RAX = window pointer
; ----------------------------------------------------------------------------
files_open:
    push rbx

    ; Reset state
    mov dword [files_selected], 0
    mov dword [files_count], 3

    ; Create window
    mov edi, WIN_TYPE_FILES
    mov esi, 150
    mov edx, 80
    mov ecx, FILES_WIDTH
    mov r8d, FILES_HEIGHT
    lea r9, [str_files_title]
    call wm_create_window

    test rax, rax
    jz .done

    mov rbx, rax
    lea rcx, [files_draw]
    mov [rbx + WIN_DRAW_CB], rcx
    lea rcx, [files_on_input]
    mov [rbx + WIN_INPUT_CB], rcx

.done:
    pop rbx
    ret

; ----------------------------------------------------------------------------
; files_draw - Draw file manager content
; Input: RDI = window pointer
; Uses: rbx=win, r12=x, r13=y, r14=width, r15=height
; ----------------------------------------------------------------------------
files_draw:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                          ; align stack
    mov rbx, rdi

    ; Get actual window dimensions
    mov r12d, [rbx + WIN_X]
    mov r13d, [rbx + WIN_Y]
    add r13d, TITLE_HEIGHT              ; client area starts below title
    mov r14d, [rbx + WIN_W]             ; actual width
    mov r15d, [rbx + WIN_H]
    sub r15d, TITLE_HEIGHT              ; client height

    ; Draw toolbar
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    mov ecx, TOOLBAR_HEIGHT
    mov r8d, FILES_COLOR_TOOLBAR
    call draw_fill_rect

    ; Draw toolbar buttons
    call .draw_toolbar

    ; Draw path bar
    mov edi, r12d
    mov esi, r13d
    add esi, TOOLBAR_HEIGHT
    mov edx, r14d
    mov ecx, HEADER_HEIGHT
    mov r8d, FILES_COLOR_HEADER
    call draw_fill_rect

    mov edi, r12d
    add edi, 10
    mov esi, r13d
    add esi, TOOLBAR_HEIGHT + 5
    lea rdx, [str_current_path]
    mov ecx, FILES_COLOR_TEXT
    call text_draw_string_xy

    ; Draw file list background
    mov edi, r12d
    mov esi, r13d
    add esi, TOOLBAR_HEIGHT + HEADER_HEIGHT
    mov edx, r14d
    mov ecx, r15d
    sub ecx, TOOLBAR_HEIGHT + HEADER_HEIGHT
    mov r8d, FILES_COLOR_BG
    call draw_fill_rect

    ; Draw file entries
    mov dword [files_draw_index], 0
    mov eax, r13d
    add eax, TOOLBAR_HEIGHT + HEADER_HEIGHT
    mov [files_draw_y], eax

.draw_loop:
    mov eax, [files_draw_index]
    cmp eax, [files_count]
    jge .draw_dialog

    call .draw_entry
    add dword [files_draw_y], ENTRY_HEIGHT
    inc dword [files_draw_index]
    jmp .draw_loop

.draw_dialog:
    ; Draw dialog centered in window
    mov edi, r12d
    mov eax, r14d
    shr eax, 1
    add edi, eax
    mov esi, r13d
    mov eax, r15d
    shr eax, 1
    add esi, eax
    call files_dialog_draw

.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Draw toolbar buttons
.draw_toolbar:
    push r12
    push r13

    mov r12d, [rbx + WIN_X]
    add r12d, 10
    mov r13d, [rbx + WIN_Y]
    add r13d, 24 + 4

    ; New File button
    mov edi, r12d
    mov esi, r13d
    mov edx, TOOLBAR_BTN_W
    mov ecx, TOOLBAR_BTN_H
    mov r8d, FILES_COLOR_BTN
    call draw_fill_rect
    mov edi, r12d
    add edi, 8
    mov esi, r13d
    add esi, 5
    lea rdx, [str_new_file]
    mov ecx, FILES_COLOR_TEXT
    call text_draw_string_xy

    ; New Folder button
    add r12d, TOOLBAR_BTN_W + TOOLBAR_BTN_GAP
    mov edi, r12d
    mov esi, r13d
    mov edx, TOOLBAR_BTN_W
    mov ecx, TOOLBAR_BTN_H
    mov r8d, FILES_COLOR_BTN
    call draw_fill_rect
    mov edi, r12d
    add edi, 8
    mov esi, r13d
    add esi, 5
    lea rdx, [str_new_folder]
    mov ecx, FILES_COLOR_TEXT
    call text_draw_string_xy

    ; Rename button
    add r12d, TOOLBAR_BTN_W + TOOLBAR_BTN_GAP
    mov edi, r12d
    mov esi, r13d
    mov edx, TOOLBAR_BTN_W
    mov ecx, TOOLBAR_BTN_H
    mov r8d, FILES_COLOR_BTN
    call draw_fill_rect
    mov edi, r12d
    add edi, 15
    mov esi, r13d
    add esi, 5
    lea rdx, [str_rename]
    mov ecx, FILES_COLOR_TEXT
    call text_draw_string_xy

    ; Delete button
    add r12d, TOOLBAR_BTN_W + TOOLBAR_BTN_GAP
    mov edi, r12d
    mov esi, r13d
    mov edx, TOOLBAR_BTN_W
    mov ecx, TOOLBAR_BTN_H
    mov r8d, FILES_COLOR_BTN
    call draw_fill_rect
    mov edi, r12d
    add edi, 15
    mov esi, r13d
    add esi, 5
    lea rdx, [str_delete]
    mov ecx, FILES_COLOR_TEXT
    call text_draw_string_xy

    pop r13
    pop r12
    ret

; Draw single entry (r12=x, r14=width, uses files_draw_y and files_draw_index)
.draw_entry:
    push rax

    ; Get current index
    mov eax, [files_draw_index]

    ; Highlight if selected
    cmp eax, [files_selected]
    jne .no_highlight

    mov edi, r12d
    mov esi, [files_draw_y]
    mov edx, r14d
    mov ecx, ENTRY_HEIGHT
    mov r8d, FILES_COLOR_SELECT
    push rax
    call draw_fill_rect
    pop rax
    mov ecx, 0x00FFFFFF
    jmp .draw_name

.no_highlight:
    mov ecx, FILES_COLOR_TEXT

.draw_name:
    push rax
    push rcx
    mov edi, r12d
    add edi, 10
    mov esi, [files_draw_y]
    add esi, 4
    pop rcx
    pop rax
    shl eax, 3
    lea rdx, [file_entries + rax]
    mov rdx, [rdx]
    call text_draw_string_xy

    pop rax
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_files_title:        db "Files", 0
str_current_path:       db "C:/", 0
str_new_file:           db "New File", 0
str_new_folder:         db "Folder", 0
str_rename:             db "Rename", 0
str_delete:             db "Delete", 0
str_file1:              db "Documents/", 0
str_file2:              db "README.txt", 0
str_file3:              db "kernel.bin", 0

file_entries:
    dq str_file1
    dq str_file2
    dq str_file3

section .data

files_selected:         dd 0
files_count:            dd 3
files_draw_index:       dd 0
files_draw_y:           dd 0
