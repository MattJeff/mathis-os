; ============================================================================
; WM_CREATE_MOD.ASM - Window Creation and Destruction
; ============================================================================
; Create and close windows
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
WM_MAX_WINDOWS          equ 8
WIN_STRUCT_SIZE         equ 56
WIN_FLAGS               equ 0
WIN_TYPE                equ 4
WIN_X                   equ 8
WIN_Y                   equ 12
WIN_W                   equ 16
WIN_H                   equ 20
WIN_TITLE               equ 24
WIN_DRAW_CB             equ 32
WIN_INPUT_CB            equ 40
WIN_FLAG_VISIBLE        equ 0x01
WIN_FLAG_ACTIVE         equ 0x02

; ============================================================================
; EXPORTS
; ============================================================================
global wm_create_window
global wm_close_window
global wm_find_free_slot

; ============================================================================
; IMPORTS
; ============================================================================
extern wm_windows
extern wm_window_count
extern wm_active_index

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; wm_create_window - Create new window
; Input: EDI=type, ESI=x, EDX=y, ECX=w, R8D=h, R9=title
; Output: RAX = window pointer (0 if failed)
; ----------------------------------------------------------------------------
wm_create_window:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Save ALL params (ECX, R8D are caller-saved!)
    mov r12d, edi           ; type
    mov r13d, esi           ; x
    mov r14d, edx           ; y
    mov r15, r9             ; title
    push rcx                ; save width
    push r8                 ; save height

    ; Find free slot
    call wm_find_free_slot

    pop r8                  ; restore height
    pop rcx                 ; restore width

    test rax, rax
    jz .fail

    mov rbx, rax

    ; Initialize window
    mov dword [rbx + WIN_FLAGS], WIN_FLAG_VISIBLE | WIN_FLAG_ACTIVE
    mov [rbx + WIN_TYPE], r12d
    mov [rbx + WIN_X], r13d
    mov [rbx + WIN_Y], r14d
    mov [rbx + WIN_W], ecx
    mov [rbx + WIN_H], r8d
    mov [rbx + WIN_TITLE], r15
    mov qword [rbx + WIN_DRAW_CB], 0
    mov qword [rbx + WIN_INPUT_CB], 0

    ; Update count
    inc dword [wm_window_count]

    mov rax, rbx
    jmp .done

.fail:
    xor eax, eax

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; wm_close_window - Close window by index
; Input: EDI = window index
; ----------------------------------------------------------------------------
wm_close_window:
    cmp edi, WM_MAX_WINDOWS
    jge .done

    ; Calculate window pointer
    mov eax, WIN_STRUCT_SIZE
    imul eax, edi
    lea rax, [wm_windows + rax]

    ; Clear flags
    mov dword [rax + WIN_FLAGS], 0

    ; Decrement count
    dec dword [wm_window_count]

.done:
    ret

; ----------------------------------------------------------------------------
; wm_find_free_slot - Find empty window slot
; Output: RAX = pointer to slot (0 if full)
; ----------------------------------------------------------------------------
wm_find_free_slot:
    xor ecx, ecx
    lea rax, [wm_windows]

.loop:
    cmp ecx, WM_MAX_WINDOWS
    jge .full

    cmp dword [rax + WIN_FLAGS], 0
    je .found

    add rax, WIN_STRUCT_SIZE
    inc ecx
    jmp .loop

.full:
    xor eax, eax
.found:
    ret
