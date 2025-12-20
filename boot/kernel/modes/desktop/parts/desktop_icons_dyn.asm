; ============================================================================
; DESKTOP_ICONS_DYN.ASM - Dynamic icons from VFS
; ============================================================================

[BITS 64]

; Icon grid constants
DICON_START_X       equ 30
DICON_START_Y       equ 220         ; After Terminal + Files
DICON_SPACING_X     equ 80
DICON_SPACING_Y     equ 80
DICON_PER_ROW       equ 6
DICON_MAX           equ 24

; Icon entry: 32 bytes
; 0: flags (4)
; 4: type (4) - 0=file, 1=folder
; 8: x (4)
; 12: y (4)
; 16: name_ptr (8)
; 24: reserved (8)
DICON_ENT_SIZE      equ 32
DICON_ENT_FLAGS     equ 0
DICON_ENT_TYPE      equ 4
DICON_ENT_X         equ 8
DICON_ENT_Y         equ 12
DICON_ENT_NAME      equ 16

; State
dicon_entries:      times (DICON_ENT_SIZE * DICON_MAX) db 0
dicon_count:        dd 0
dicon_dirty:        db 1
dicon_last_mode:    db 0xFF     ; Track mode changes

; ============================================================================
; DICON_CHECK_REFRESH - Auto-refresh when entering desktop or when dirty
; ============================================================================
dicon_check_refresh:
    push rax
    ; Check mode change
    mov al, [mode_flag]
    cmp al, [dicon_last_mode]
    je .check_dirty
    mov [dicon_last_mode], al
    cmp al, 2                   ; MODE_DESKTOP
    jne .done
    mov byte [dicon_dirty], 1   ; Force refresh on mode entry
.check_dirty:
    cmp byte [dicon_dirty], 0
    je .done
    call dicon_refresh
.done:
    pop rax
    ret

; ============================================================================
; DICON_REFRESH - Refresh icons from VFS (desktop location)
; ============================================================================
dicon_refresh:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13

    ; Navigate VFS to desktop
    mov edi, VFS_LOC_DESKTOP
    call vfs_goto_loc

    ; Get entries
    call vfs_get_entries        ; RAX = entries, EDX = count

    mov rbx, rax                ; Source entries
    mov r12d, edx               ; Count
    cmp r12d, DICON_MAX
    jle .count_ok
    mov r12d, DICON_MAX
.count_ok:
    mov [dicon_count], r12d

    ; Convert VFS entries to desktop icons
    xor r13d, r13d              ; Index

.loop:
    cmp r13d, r12d
    jge .done

    ; Dest icon
    mov eax, r13d
    imul eax, DICON_ENT_SIZE
    lea rdi, [dicon_entries + rax]

    ; Source VFS entry
    mov eax, r13d
    imul eax, VFS_ENTRY_SIZE
    lea rsi, [rbx + rax]

    ; Calculate grid position
    mov eax, r13d
    xor edx, edx
    mov ecx, DICON_PER_ROW
    div ecx                     ; EAX = row, EDX = col

    ; X = DICON_START_X + col * DICON_SPACING_X
    imul edx, DICON_SPACING_X
    add edx, DICON_START_X
    mov [rdi + DICON_ENT_X], edx

    ; Y = DICON_START_Y + row * DICON_SPACING_Y
    imul eax, DICON_SPACING_Y
    add eax, DICON_START_Y
    mov [rdi + DICON_ENT_Y], eax

    ; Copy type (folder or file)
    mov eax, [rsi + VFS_E_FLAGS]
    test eax, VFS_FLAG_DIR
    jz .is_file
    mov dword [rdi + DICON_ENT_TYPE], 1     ; Folder
    jmp .set_name
.is_file:
    mov dword [rdi + DICON_ENT_TYPE], 0     ; File

.set_name:
    ; Name pointer (point to VFS entry name)
    lea rax, [rsi + VFS_E_NAME]
    mov [rdi + DICON_ENT_NAME], rax
    mov dword [rdi + DICON_ENT_FLAGS], 1    ; Visible

    inc r13d
    jmp .loop

.done:
    mov byte [dicon_dirty], 0

    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DICON_DRAW_ALL - Draw all dynamic icons
; ============================================================================
dicon_draw_all:
    push rax
    push rbx
    push rcx
    push r12

    mov ecx, [dicon_count]
    test ecx, ecx
    jz .done

    xor r12d, r12d

.loop:
    cmp r12d, ecx
    jge .done

    mov eax, r12d
    imul eax, DICON_ENT_SIZE
    lea rbx, [dicon_entries + rax]

    ; Skip if not visible
    cmp dword [rbx + DICON_ENT_FLAGS], 0
    je .next

    ; Draw icon
    mov edi, [rbx + DICON_ENT_X]
    mov esi, [rbx + DICON_ENT_Y]
    mov edx, [rbx + DICON_ENT_TYPE]
    mov r8, [rbx + DICON_ENT_NAME]
    call dicon_draw_one

.next:
    inc r12d
    mov ecx, [dicon_count]
    jmp .loop

.done:
    pop r12
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DICON_DRAW_ONE - Draw single icon
; Input: EDI = x, ESI = y, EDX = type, R8 = name
; ============================================================================
dicon_draw_one:
    push rdi
    push rsi
    push rdx
    push r8

    ; Icon background
    push rdx
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00303030
    call fill_rect
    pop rdx

    ; Icon color based on type
    mov r8d, 0x00FFFFFF         ; File = white
    test edx, edx
    jz .draw_icon
    mov r8d, 0x00FFCC00         ; Folder = yellow

.draw_icon:
    pop rdx                     ; Restore type
    push rdx
    test edx, edx
    jz .draw_file_icon
    ; Draw folder
    mov edx, r8d
    call draw_icon_folder
    jmp .draw_label

.draw_file_icon:
    ; Simple file rectangle
    add edi, 12
    add esi, 8
    mov edx, 24
    mov ecx, 28
    mov r8d, 0x00FFFFFF
    call fill_rect

.draw_label:
    pop rdx
    pop r8                      ; Name pointer
    pop rsi
    pop rdi

    ; Draw label below icon
    push r8
    add esi, DESKTOP_ICON_SIZE
    add esi, 4
    mov rdx, r8
    mov ecx, 0x00FFFFFF
    call video_text
    pop r8
    ret

; ============================================================================
; DICON_HIT_TEST - Check if click hit an icon
; Input: EDI = x, ESI = y
; Output: EAX = icon index (-1 if none)
; ============================================================================
dicon_hit_test:
    push rbx
    push rcx
    push r12
    push r13

    mov r12d, edi               ; Click x
    mov r13d, esi               ; Click y

    mov ecx, [dicon_count]
    test ecx, ecx
    jz .not_found

    xor eax, eax

.loop:
    cmp eax, ecx
    jge .not_found

    push rax
    imul eax, DICON_ENT_SIZE
    lea rbx, [dicon_entries + rax]
    pop rax

    ; Check bounds
    mov edx, [rbx + DICON_ENT_X]
    cmp r12d, edx
    jl .next
    add edx, DESKTOP_ICON_SIZE
    cmp r12d, edx
    jge .next

    mov edx, [rbx + DICON_ENT_Y]
    cmp r13d, edx
    jl .next
    add edx, DESKTOP_ICON_SIZE
    cmp r13d, edx
    jge .next

    ; Hit!
    jmp .done

.next:
    inc eax
    jmp .loop

.not_found:
    mov eax, -1

.done:
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; ============================================================================
; DICON_GET_ENTRY - Get icon entry by index
; Input: EDI = index
; Output: RAX = entry pointer (or 0)
; ============================================================================
dicon_get_entry:
    cmp edi, [dicon_count]
    jge .fail
    mov eax, edi
    imul eax, DICON_ENT_SIZE
    lea rax, [dicon_entries + rax]
    ret
.fail:
    xor eax, eax
    ret
