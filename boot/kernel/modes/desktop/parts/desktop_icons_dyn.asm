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
    mov byte [desktop_needs_redraw], 1
.check_dirty:
    cmp byte [dicon_dirty], 0
    je .done
    call dicon_refresh
    mov byte [desktop_needs_redraw], 1
.done:
    pop rax
    ret

; ============================================================================
; DICON_REFRESH - Refresh icons from /DESKTOP, preserve positions
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
    push r14

    ; Save old count
    mov r14d, [dicon_count]

    ; Read /DESKTOP directly
    lea rdi, [dicon_desktop_path]
    lea rsi, [dicon_dirent_buf]
    mov edx, DICON_MAX
    call fs_readdir

    cmp eax, -1
    je .no_entries
    test eax, eax
    jz .no_entries

    mov r12d, eax               ; New count
    lea rbx, [dicon_dirent_buf]
    jmp .process

.no_entries:
    mov dword [dicon_count], 0
    jmp .done

.process:
    xor r13d, r13d              ; New entry index

.loop:
    cmp r13d, r12d
    jge .finalize

    ; Source FS_DIRENT entry
    mov eax, r13d
    imul eax, 64
    lea rsi, [rbx + rax]

    ; Check if this name exists in old entries
    push r13
    mov rdi, rsi                ; Name pointer
    mov esi, r14d               ; Old count
    call dicon_find_by_name
    pop r13
    cmp eax, -1
    jne .keep_pos               ; Found, keep old position

    ; New icon - find free position
    push rbx
    push r12
    push r13
    call dicon_find_free_pos    ; Returns edi=x, esi=y
    mov eax, edi
    mov edx, esi
    pop r13
    pop r12
    pop rbx
    jmp .set_entry

.keep_pos:
    ; Get position from existing entry
    push rax
    imul eax, DICON_ENT_SIZE
    lea rcx, [dicon_entries + rax]
    mov eax, [rcx + DICON_ENT_X]
    mov edx, [rcx + DICON_ENT_Y]
    add rsp, 8                  ; Pop saved rax without restoring

.set_entry:
    ; Dest icon entry
    push rax
    push rdx
    mov eax, r13d
    imul eax, DICON_ENT_SIZE
    lea rdi, [dicon_entries + rax]
    pop rdx
    pop rax

    ; Set position
    mov [rdi + DICON_ENT_X], eax
    mov [rdi + DICON_ENT_Y], edx

    ; Source dirent
    mov eax, r13d
    imul eax, 64
    lea rsi, [rbx + rax]

    ; Type from FS_DIRENT_FLAGS
    mov eax, [rsi + 36]
    test eax, 1
    jz .is_file
    mov dword [rdi + DICON_ENT_TYPE], 1
    jmp .set_name
.is_file:
    mov dword [rdi + DICON_ENT_TYPE], 0

.set_name:
    lea rax, [rsi]
    mov [rdi + DICON_ENT_NAME], rax
    mov dword [rdi + DICON_ENT_FLAGS], 1

    inc r13d
    jmp .loop

.finalize:
    mov [dicon_count], r12d

.done:
    mov byte [dicon_dirty], 0

    pop r14
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
; DICON_FIND_BY_NAME - Find icon index by name
; Input: RDI = name, ESI = count to search
; Output: EAX = index or -1
; ============================================================================
dicon_find_by_name:
    push rbx
    push rcx
    push r12

    mov r12, rdi                ; Name to find
    xor ecx, ecx

.search:
    cmp ecx, esi
    jge .not_found

    mov eax, ecx
    imul eax, DICON_ENT_SIZE
    lea rbx, [dicon_entries + rax]
    mov rdi, [rbx + DICON_ENT_NAME]
    test rdi, rdi
    jz .next

    ; Compare names (simple byte compare up to 11 chars)
    push rcx
    push rsi
    mov rsi, r12
    call dicon_strcmp
    pop rsi
    pop rcx
    test eax, eax
    jz .found

.next:
    inc ecx
    jmp .search

.not_found:
    mov eax, -1
    jmp .done

.found:
    mov eax, ecx

.done:
    pop r12
    pop rcx
    pop rbx
    ret

; ============================================================================
; DICON_STRCMP - Compare two strings
; Input: RDI = str1, RSI = str2
; Output: EAX = 0 if equal
; ============================================================================
dicon_strcmp:
    push rcx
    mov ecx, 12                 ; Max FAT name length

.cmp_loop:
    mov al, [rdi]
    mov ah, [rsi]
    cmp al, ah
    jne .not_equal
    test al, al
    jz .equal
    inc rdi
    inc rsi
    dec ecx
    jnz .cmp_loop

.equal:
    xor eax, eax
    jmp .done

.not_equal:
    mov eax, 1

.done:
    pop rcx
    ret

; Data for dicon_refresh
dicon_desktop_path: db "/DESKTOP", 0
dicon_dirent_buf:   times (64 * DICON_MAX) db 0

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
; DICON_DRAW_ONE - Draw single icon with label
; Input: EDI = x, ESI = y, EDX = type, R8 = name pointer
; ============================================================================
dicon_draw_one:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi               ; r12 = x
    mov r13d, esi               ; r13 = y
    mov r14d, edx               ; r14 = type (0=file, 1=folder)
    mov rbx, r8                 ; rbx = name pointer

    ; Icon background
    mov edi, r12d
    mov esi, r13d
    mov edx, DESKTOP_ICON_SIZE
    mov ecx, DESKTOP_ICON_SIZE
    mov r8d, 0x00303030
    call fill_rect

    ; Draw icon based on type
    test r14d, r14d
    jz .draw_file_icon

    ; Draw folder icon
    mov edi, r12d
    add edi, 16
    mov esi, r13d
    add esi, 8
    mov edx, 0x00FFCC00         ; Yellow
    call draw_icon_folder
    jmp .draw_label

.draw_file_icon:
    ; Simple file rectangle
    mov edi, r12d
    add edi, 20
    mov esi, r13d
    add esi, 8
    mov edx, 24
    mov ecx, 32
    mov r8d, 0x00FFFFFF
    call fill_rect

.draw_label:
    ; Draw name below icon
    mov edi, r12d
    mov esi, r13d
    add esi, DESKTOP_ICON_SIZE
    add esi, 4
    mov rdx, rbx                ; Name pointer
    mov ecx, 0x00FFFFFF         ; White text
    call video_text

    pop r14
    pop r13
    pop r12
    pop rbx
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
