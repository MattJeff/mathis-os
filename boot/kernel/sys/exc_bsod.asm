; ============================================================================
; EXC_BSOD.ASM - Blue Screen of Death (32bpp)
; ============================================================================
; Displays crash info when an exception occurs
; Uses 32bpp ARGB framebuffer
; ============================================================================

; Colors (32bpp ARGB)
BSOD_BG         equ 0x00000080      ; Dark blue background
BSOD_TITLE      equ 0x00FFFFFF      ; White
BSOD_LABEL      equ 0x00AAAAAA      ; Light gray
BSOD_VALUE      equ 0x00FFFF00      ; Yellow
BSOD_ERROR      equ 0x00FF6666      ; Light red

; ============================================================================
; EXC_COMMON - Main exception handler
; ============================================================================
; Stack on entry:
;   [rsp+0]  = exception number (pushed by stub)
;   [rsp+8]  = error code (pushed by stub or CPU)
;   [rsp+16] = RIP
;   [rsp+24] = CS
;   [rsp+32] = RFLAGS
;   [rsp+40] = RSP (if privilege change)
;   [rsp+48] = SS (if privilege change)
; ============================================================================
exc_common:
    cli

    ; Save registers
    mov [exc_reg_rax], rax
    mov [exc_reg_rbx], rbx
    mov [exc_reg_rcx], rcx
    mov [exc_reg_rdx], rdx
    mov [exc_reg_rsi], rsi
    mov [exc_reg_rdi], rdi
    mov [exc_reg_rbp], rbp
    mov [exc_reg_r8],  r8
    mov [exc_reg_r9],  r9
    mov [exc_reg_r10], r10
    mov [exc_reg_r11], r11
    mov [exc_reg_r12], r12
    mov [exc_reg_r13], r13
    mov [exc_reg_r14], r14
    mov [exc_reg_r15], r15

    ; Save CR2 (page fault address)
    mov rax, cr2
    mov [exc_reg_cr2], rax

    ; Save exception info from stack
    mov rax, [rsp]
    mov [exc_num], rax
    mov rax, [rsp + 8]
    mov [exc_err], rax
    mov rax, [rsp + 16]
    mov [exc_rip], rax
    mov rax, [rsp + 40]
    mov [exc_rsp], rax

    ; Draw BSOD
    call bsod_draw

    ; Halt forever
.halt:
    hlt
    jmp .halt

; ============================================================================
; BSOD_DRAW - Draw the blue screen
; ============================================================================
bsod_draw:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Fill screen with blue
    mov edi, [screen_fb]
    mov ecx, [screen_width]
    imul ecx, [screen_height]
    mov eax, BSOD_BG
.fill:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .fill

    ; Title: "KERNEL PANIC"
    mov edi, 40
    mov esi, 30
    lea rdx, [exc_str_title]
    mov ecx, BSOD_TITLE
    call bsod_print

    ; Exception name
    mov edi, 40
    mov esi, 60
    lea rdx, [exc_str_exception]
    mov ecx, BSOD_LABEL
    call bsod_print

    ; Get exception name from table
    mov rax, [exc_num]
    and rax, 0x1F
    shl rax, 3
    lea rbx, [exc_names]
    mov rdx, [rbx + rax]
    mov edi, 160
    mov esi, 60
    mov ecx, BSOD_VALUE
    call bsod_print

    ; RIP
    mov edi, 40
    mov esi, 90
    lea rdx, [exc_str_rip]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_rip]
    mov edi, 100
    mov esi, 90
    call bsod_print_hex

    ; CR2
    mov edi, 40
    mov esi, 110
    lea rdx, [exc_str_cr2]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_reg_cr2]
    mov edi, 100
    mov esi, 110
    call bsod_print_hex

    ; Error code
    mov edi, 40
    mov esi, 130
    lea rdx, [exc_str_err]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_err]
    mov edi, 100
    mov esi, 130
    call bsod_print_hex

    ; RSP
    mov edi, 40
    mov esi, 150
    lea rdx, [exc_str_rsp]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_rsp]
    mov edi, 100
    mov esi, 150
    call bsod_print_hex

    ; Registers header
    mov edi, 40
    mov esi, 190
    lea rdx, [exc_str_regs]
    mov ecx, BSOD_TITLE
    call bsod_print

    ; RAX RBX RCX RDX
    mov edi, 40
    mov esi, 210
    lea rdx, [exc_str_rax]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_reg_rax]
    mov edi, 80
    call bsod_print_hex

    mov edi, 250
    mov esi, 210
    lea rdx, [exc_str_rbx]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_reg_rbx]
    mov edi, 290
    call bsod_print_hex

    ; RCX RDX
    mov edi, 40
    mov esi, 230
    lea rdx, [exc_str_rcx]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_reg_rcx]
    mov edi, 80
    call bsod_print_hex

    mov edi, 250
    mov esi, 230
    lea rdx, [exc_str_rdx]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_reg_rdx]
    mov edi, 290
    call bsod_print_hex

    ; RSI RDI
    mov edi, 40
    mov esi, 250
    lea rdx, [exc_str_rsi]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_reg_rsi]
    mov edi, 80
    call bsod_print_hex

    mov edi, 250
    mov esi, 250
    lea rdx, [exc_str_rdi]
    mov ecx, BSOD_LABEL
    call bsod_print
    mov rax, [exc_reg_rdi]
    mov edi, 290
    call bsod_print_hex

    ; Halt message
    mov edi, 40
    mov esi, 300
    lea rdx, [exc_str_halt]
    mov ecx, BSOD_ERROR
    call bsod_print

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; BSOD_PRINT - Print string
; Input: edi=x, esi=y, rdx=string, ecx=color
; ============================================================================
bsod_print:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov r8d, ecx            ; Save color

.loop:
    movzx eax, byte [rdx]
    test al, al
    jz .done

    call bsod_char
    add edi, 8
    inc rdx
    jmp .loop

.done:
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; BSOD_CHAR - Draw single character (8x8)
; Input: al=char, edi=x, esi=y, r8d=color
; ============================================================================
bsod_char:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9

    ; Get font bitmap
    movzx ebx, al
    sub ebx, 32
    js .done
    cmp ebx, 95
    ja .done

    shl ebx, 3
    lea rax, [exc_font]
    add rbx, rax

    ; Calculate screen position
    mov eax, esi
    imul eax, [screen_pitch]
    mov r9d, edi
    shl r9d, 2              ; x * 4 (32bpp)
    add eax, r9d
    add eax, [screen_fb]
    mov rdi, rax

    ; Draw 8 rows
    mov ecx, 8
.row:
    movzx eax, byte [rbx]
    push rcx
    mov ecx, 8
.pixel:
    test al, 0x80
    jz .skip
    mov [rdi], r8d
.skip:
    shl al, 1
    add rdi, 4
    dec ecx
    jnz .pixel

    pop rcx
    inc rbx

    ; Next row
    mov eax, [screen_pitch]
    sub eax, 32
    add rdi, rax
    dec ecx
    jnz .row

.done:
    pop r9
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; BSOD_PRINT_HEX - Print 64-bit hex value
; Input: rax=value, edi=x, esi=y
; ============================================================================
bsod_print_hex:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push r8

    mov r8d, BSOD_VALUE
    mov rbx, rax

    ; Print "0x"
    mov al, '0'
    call bsod_char
    add edi, 8
    mov al, 'x'
    call bsod_char
    add edi, 8

    ; Print 16 hex digits
    mov ecx, 16
.hex:
    rol rbx, 4
    mov eax, ebx
    and eax, 0xF
    cmp al, 10
    jb .digit
    add al, 'A' - 10
    jmp .draw
.digit:
    add al, '0'
.draw:
    push rcx
    call bsod_char
    pop rcx
    add edi, 8
    dec ecx
    jnz .hex

    pop r8
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
