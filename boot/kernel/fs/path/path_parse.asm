; ============================================================================
; PATH_PARSE.ASM - Parse path string into segments
; ============================================================================

[BITS 64]

; ============================================================================
; PATH_PARSE - Parse path into segments (8.3 format)
; Input:  RDI = path string (e.g., "/desktop/folder")
; Output: EAX = segment count (0 = root only)
; ============================================================================
path_parse:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13

    mov r12, rdi                    ; r12 = path
    xor r13d, r13d                  ; r13 = segment count

    ; Clear segments buffer
    lea rdi, [path_segments]
    mov ecx, PATH_MAX_SEGMENTS * PATH_SEG_SIZE
    xor al, al
    rep stosb

    ; Skip leading slash
    mov rdi, r12
    cmp byte [rdi], '/'
    jne .parse_loop
    inc rdi

.parse_loop:
    ; Check end of string
    cmp byte [rdi], 0
    je .done

    ; Check max segments
    cmp r13d, PATH_MAX_SEGMENTS
    jge .done

    ; Find end of segment (next '/' or null)
    mov rsi, rdi                    ; rsi = segment start
    xor ecx, ecx                    ; ecx = length

.find_end:
    mov al, [rdi]
    cmp al, 0
    je .segment_end
    cmp al, '/'
    je .segment_end
    inc rdi
    inc ecx
    cmp ecx, 11                     ; Max 8.3 name length
    jl .find_end

.segment_end:
    ; Skip empty segments (e.g., "//")
    test ecx, ecx
    jz .skip_slash

    ; Copy segment to buffer and convert to 8.3 uppercase
    push rdi
    mov eax, r13d
    imul eax, PATH_SEG_SIZE
    lea rdi, [path_segments + rax]
    call path_copy_segment          ; rsi = src, ecx = len, rdi = dest
    pop rdi

    inc r13d

.skip_slash:
    ; Skip trailing slash
    cmp byte [rdi], '/'
    jne .parse_loop
    inc rdi
    jmp .parse_loop

.done:
    mov [path_segment_count], r13d
    mov eax, r13d

    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; PATH_COPY_SEGMENT - Copy and convert segment to 8.3 uppercase
; Input:  RSI = source, ECX = length, RDI = dest (12 bytes)
; ============================================================================
path_copy_segment:
    push rax
    push rbx
    push rcx
    push rdi

    ; Fill with spaces (8.3 format)
    push rdi
    push rcx
    mov al, ' '
    mov ecx, 11
    rep stosb
    mov byte [rdi], 0               ; Null terminate
    pop rcx
    pop rdi

    ; Copy name part (max 8 chars before dot)
    xor ebx, ebx                    ; Position counter

.copy_char:
    test ecx, ecx
    jz .copy_done

    lodsb                           ; Get char
    dec ecx

    ; Check for dot (extension separator)
    cmp al, '.'
    je .copy_ext

    ; Convert to uppercase
    cmp al, 'a'
    jl .not_lower
    cmp al, 'z'
    jg .not_lower
    sub al, 32                      ; To uppercase
.not_lower:

    ; Store if within first 8 chars
    cmp ebx, 8
    jge .copy_char
    mov [rdi + rbx], al
    inc ebx
    jmp .copy_char

.copy_ext:
    ; Copy extension (max 3 chars at offset 8)
    mov ebx, 8

.ext_loop:
    test ecx, ecx
    jz .copy_done
    cmp ebx, 11
    jge .copy_done

    lodsb
    dec ecx

    ; Convert to uppercase
    cmp al, 'a'
    jl .ext_not_lower
    cmp al, 'z'
    jg .ext_not_lower
    sub al, 32
.ext_not_lower:
    mov [rdi + rbx], al
    inc ebx
    jmp .ext_loop

.copy_done:
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret
