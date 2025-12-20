; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR.ASM - Finder-style sidebar widget (main include)
; ════════════════════════════════════════════════════════════════════════════
; Provides location navigation like Mac Finder:
;   - Desktop, Root, Downloads, Documents
;   - Click or keyboard to navigate
;   - Integrates with FS events for sync
;
; Usage:
;   1. sidebar_init(x, y, h)
;   2. sidebar_set_callback(callback_fn)
;   3. sidebar_draw() in render loop
;   4. sidebar_on_click(x, y) / sidebar_on_key(scancode)
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

%include "widgets/sidebar/sidebar_data.asm"
%include "widgets/sidebar/sidebar_draw.asm"
%include "widgets/sidebar/sidebar_input.asm"

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_INIT - Initialize sidebar
; Input: EDI = x, ESI = y, EDX = height
; ════════════════════════════════════════════════════════════════════════════
sidebar_init:
    mov [sidebar_x], edi
    mov [sidebar_y], esi
    mov [sidebar_h], edx
    mov dword [sidebar_selected], 1 ; Default: Desktop
    mov dword [sidebar_hover], -1
    mov byte [sidebar_visible], 1
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_SET_CALLBACK - Set location change callback
; Input: RDI = callback function (rdi = index, rsi = path ptr)
; ════════════════════════════════════════════════════════════════════════════
sidebar_set_callback:
    mov [sidebar_on_select], rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_SHOW / SIDEBAR_HIDE - Toggle visibility
; ════════════════════════════════════════════════════════════════════════════
sidebar_show:
    mov byte [sidebar_visible], 1
    ret

sidebar_hide:
    mov byte [sidebar_visible], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_GET_CURRENT_PATH - Get path of selected location
; Output: RAX = pointer to path string
; ════════════════════════════════════════════════════════════════════════════
sidebar_get_current_path:
    push r12

    mov r12d, [sidebar_selected]
    call sidebar_get_loc_addr
    lea rax, [rax + SB_LOC_PATH_OFF]

    pop r12
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_SELECT_BY_PATH - Select location matching path
; Input: RDI = path string to match
; Output: EAX = 1 if found and selected, 0 if not found
; ════════════════════════════════════════════════════════════════════════════
sidebar_select_by_path:
    push rbx
    push rcx
    push rsi
    push r12
    push r13

    mov r13, rdi                    ; Save path to match
    xor r12d, r12d                  ; Index

.search_loop:
    cmp r12d, [sidebar_loc_count]
    jge .not_found

    call sidebar_get_loc_addr
    lea rsi, [rax + SB_LOC_PATH_OFF]

    ; Compare paths
    mov rdi, r13
.cmp_loop:
    mov al, [rdi]
    mov ah, [rsi]
    cmp al, ah
    jne .next
    test al, al
    jz .found
    inc rdi
    inc rsi
    jmp .cmp_loop

.next:
    inc r12d
    jmp .search_loop

.found:
    mov [sidebar_selected], r12d
    mov eax, 1
    jmp .done

.not_found:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rsi
    pop rcx
    pop rbx
    ret
