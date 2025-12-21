; ════════════════════════════════════════════════════════════════════════════
; VIDEO_SVC.ASM - Video Service Implementation (SOLID)
; ════════════════════════════════════════════════════════════════════════════
; Wraps ui/draw.asm as a service for the registry
; All drawing goes through this service - no direct calls to draw functions
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; VIDEO SERVICE V-TABLE
; ════════════════════════════════════════════════════════════════════════════
video_svc_vtable:
    dq video_clear          ; Offset 0:  clear(color)
    dq video_pixel          ; Offset 8:  pixel(x, y, color)
    dq draw_rect            ; Offset 16: rect(x, y, w, h, color)
    dq fill_rect            ; Offset 24: fill_rect(x, y, w, h, color)
    dq video_text           ; Offset 32: text(x, y, str, color)
    dq draw_line            ; Offset 40: line(x1, y1, x2, y2, color)

; ════════════════════════════════════════════════════════════════════════════
; VIDEO_SVC_INIT - Register video service
; Call this after registry_init
; ════════════════════════════════════════════════════════════════════════════
video_svc_init:
    push rdi
    push rsi

    mov edi, SVC_VIDEO
    lea rsi, [video_svc_vtable]
    call register_service

    pop rsi
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIDEO_CLEAR - Clear screen with color
; Input: edi = color (32-bit BGRA)
; ════════════════════════════════════════════════════════════════════════════
video_clear:
    push rdi
    push rsi
    push rdx
    push rcx
    push r8

    mov r8d, edi                    ; color
    xor edi, edi                    ; x = 0
    xor esi, esi                    ; y = 0
    mov edx, [screen_width]         ; w = screen_width
    mov ecx, [screen_height]        ; h = screen_height
    call fill_rect

    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIDEO_PIXEL - Draw single pixel
; Input: edi = x, esi = y, edx = color (32-bit BGRA)
; ════════════════════════════════════════════════════════════════════════════
video_pixel:
    push rax
    push rbx
    push rcx

    ; Bounds check
    cmp edi, 0
    jl .done
    cmp edi, [screen_width]
    jge .done
    cmp esi, 0
    jl .done
    cmp esi, [screen_height]
    jge .done

    ; Calculate offset: y * pitch + x * 4
    mov eax, esi
    imul eax, [screen_pitch]
    mov ecx, edi
    shl ecx, 2                      ; x * 4 for 32-bit
    add eax, ecx

    ; Write pixel
    mov rbx, [screen_fb]
    mov dword [rbx + rax], edx

.done:
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIDEO_TEXT - Draw text at x,y coordinates
; Input: edi = x, esi = y, rdx = string ptr, ecx = color
; ════════════════════════════════════════════════════════════════════════════
video_text:
    push rdi
    push rsi
    push r8

    ; Calculate screen position: y * pitch + x * 4
    mov eax, esi
    imul eax, [screen_pitch]
    mov r8d, edi
    shl r8d, 2
    add eax, r8d
    mov rdi, [screen_fb]
    add rdi, rax                    ; rdi = screen position

    mov rsi, rdx                    ; rsi = string
    mov r8d, ecx                    ; r8d = color

    call draw_text

    pop r8
    pop rsi
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIDEO_TEXT_2X - Draw double-size text (16x16) at x,y coordinates
; Input: edi = x, esi = y, rdx = string ptr, ecx = color
; ════════════════════════════════════════════════════════════════════════════
video_text_2x:
    push rdi
    push rsi
    push r8

    ; Calculate screen position: y * pitch + x * 4
    mov eax, esi
    imul eax, [screen_pitch]
    mov r8d, edi
    shl r8d, 2
    add eax, r8d
    mov rdi, [screen_fb]
    add rdi, rax                    ; rdi = screen position

    mov rsi, rdx                    ; rsi = string
    mov r8d, ecx                    ; r8d = color

    call draw_text

    pop r8
    pop rsi
    pop rdi
    ret
