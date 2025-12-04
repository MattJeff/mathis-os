; ════════════════════════════════════════════════════════════════════════════
; GO64.ASM - Transition 32-bit vers 64-bit Long Mode + 3D Graphics
; ════════════════════════════════════════════════════════════════════════════

GFX64_FB    equ 0xA0000
GFX64_W     equ 320
GFX64_H     equ 200
CENTER_X    equ 160
CENTER_Y    equ 100
CUBE_SIZE   equ 50

do_go64:
    cli

    ; Setup page tables at 0x1000 (identity map first 2MB)
    ; PML4 at 0x1000, PDPT at 0x2000, PD at 0x3000
    mov edi, 0x1000
    mov ecx, 3072
    xor eax, eax
    rep stosd

    ; PML4[0] -> PDPT at 0x2000
    mov dword [0x1000], 0x2003
    mov dword [0x1004], 0x0
    ; PDPT[0] -> PD at 0x3000
    mov dword [0x2000], 0x3003
    mov dword [0x2004], 0x0
    ; PD[0] -> 2MB page at 0 (Present + RW + PS)
    mov dword [0x3000], 0x00000083
    mov dword [0x3004], 0x0

    ; Enable PAE in CR4
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; Load CR3 with PML4 address
    mov eax, 0x1000
    mov cr3, eax

    ; Enable Long Mode in EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; Load 64-bit GDT
    lgdt [gdt64_ptr]

    ; Enable Paging (activates Long Mode)
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; Far jump to 64-bit code
    jmp 0x08:long_mode_entry

; ════════════════════════════════════════════════════════════════════════════
; 64-bit Long Mode Entry Point
; ════════════════════════════════════════════════════════════════════════════
[BITS 64]
long_mode_entry:
    cli

    ; Setup 64-bit data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Initialize angle to 0
    xor r12, r12              ; r12 = angle (0-63 for full rotation)

.main_loop:
    ; Clear screen (black)
    mov rdi, GFX64_FB
    mov rcx, GFX64_W * GFX64_H / 8
    xor rax, rax
    rep stosq

    ; Get sin and cos from lookup table (angle 0-63)
    mov rax, r12
    and rax, 0x3F             ; 0-63 range

    ; cos = sin_table[(angle + 16) & 63]  (phase shift by 90 degrees)
    mov rbx, rax
    add rbx, 16
    and rbx, 0x3F

    movsx r13, byte [sin_table + rax]   ; r13 = sin(angle) * 32
    movsx r14, byte [sin_table + rbx]   ; r14 = cos(angle) * 32

    ; Define cube vertices in 3D: (-1,-1,-1) to (1,1,1) scaled by 40
    ; Apply Y-axis rotation: x' = x*cos + z*sin, z' = -x*sin + z*cos
    ; Then project: screen_x = center + x' * scale / (z' + distance)

    ; Vertex 0: (-40, -40, -40) -> front-top-left
    mov rax, -40
    imul rax, r14             ; x * cos
    mov rcx, -40
    imul rcx, r13             ; z * sin
    add rax, rcx              ; x' = x*cos + z*sin
    sar rax, 5                ; divide by 32
    add rax, CENTER_X
    mov [v0x], rax
    mov qword [v0y], CENTER_Y - 30

    ; Vertex 1: (40, -40, -40) -> front-top-right
    mov rax, 40
    imul rax, r14
    mov rcx, -40
    imul rcx, r13
    add rax, rcx
    sar rax, 5
    add rax, CENTER_X
    mov [v1x], rax
    mov qword [v1y], CENTER_Y - 30

    ; Vertex 2: (40, 40, -40) -> front-bottom-right
    mov rax, 40
    imul rax, r14
    mov rcx, -40
    imul rcx, r13
    add rax, rcx
    sar rax, 5
    add rax, CENTER_X
    mov [v2x], rax
    mov qword [v2y], CENTER_Y + 30

    ; Vertex 3: (-40, 40, -40) -> front-bottom-left
    mov rax, -40
    imul rax, r14
    mov rcx, -40
    imul rcx, r13
    add rax, rcx
    sar rax, 5
    add rax, CENTER_X
    mov [v3x], rax
    mov qword [v3y], CENTER_Y + 30

    ; Vertex 4: (-40, -40, 40) -> back-top-left
    mov rax, -40
    imul rax, r14
    mov rcx, 40
    imul rcx, r13
    add rax, rcx
    sar rax, 5
    add rax, CENTER_X
    mov [v4x], rax
    mov qword [v4y], CENTER_Y - 25

    ; Vertex 5: (40, -40, 40) -> back-top-right
    mov rax, 40
    imul rax, r14
    mov rcx, 40
    imul rcx, r13
    add rax, rcx
    sar rax, 5
    add rax, CENTER_X
    mov [v5x], rax
    mov qword [v5y], CENTER_Y - 25

    ; Vertex 6: (40, 40, 40) -> back-bottom-right
    mov rax, 40
    imul rax, r14
    mov rcx, 40
    imul rcx, r13
    add rax, rcx
    sar rax, 5
    add rax, CENTER_X
    mov [v6x], rax
    mov qword [v6y], CENTER_Y + 25

    ; Vertex 7: (-40, 40, 40) -> back-bottom-left
    mov rax, -40
    imul rax, r14
    mov rcx, 40
    imul rcx, r13
    add rax, rcx
    sar rax, 5
    add rax, CENTER_X
    mov [v7x], rax
    mov qword [v7y], CENTER_Y + 25

    ; ══════════════════════════════════════════════════════════════════
    ; DRAW 12 EDGES OF CUBE
    ; ══════════════════════════════════════════════════════════════════

    ; Front face (4 edges) - white
    mov rdi, [v0x]
    mov rsi, [v0y]
    mov rdx, [v1x]
    mov rcx, [v1y]
    mov r8, 15
    call draw_line

    mov rdi, [v1x]
    mov rsi, [v1y]
    mov rdx, [v2x]
    mov rcx, [v2y]
    mov r8, 15
    call draw_line

    mov rdi, [v2x]
    mov rsi, [v2y]
    mov rdx, [v3x]
    mov rcx, [v3y]
    mov r8, 15
    call draw_line

    mov rdi, [v3x]
    mov rsi, [v3y]
    mov rdx, [v0x]
    mov rcx, [v0y]
    mov r8, 15
    call draw_line

    ; Back face (4 edges) - green
    mov rdi, [v4x]
    mov rsi, [v4y]
    mov rdx, [v5x]
    mov rcx, [v5y]
    mov r8, 10
    call draw_line

    mov rdi, [v5x]
    mov rsi, [v5y]
    mov rdx, [v6x]
    mov rcx, [v6y]
    mov r8, 10
    call draw_line

    mov rdi, [v6x]
    mov rsi, [v6y]
    mov rdx, [v7x]
    mov rcx, [v7y]
    mov r8, 10
    call draw_line

    mov rdi, [v7x]
    mov rsi, [v7y]
    mov rdx, [v4x]
    mov rcx, [v4y]
    mov r8, 10
    call draw_line

    ; Connecting edges (4 edges) - cyan
    mov rdi, [v0x]
    mov rsi, [v0y]
    mov rdx, [v4x]
    mov rcx, [v4y]
    mov r8, 11
    call draw_line

    mov rdi, [v1x]
    mov rsi, [v1y]
    mov rdx, [v5x]
    mov rcx, [v5y]
    mov r8, 11
    call draw_line

    mov rdi, [v2x]
    mov rsi, [v2y]
    mov rdx, [v6x]
    mov rcx, [v6y]
    mov r8, 11
    call draw_line

    mov rdi, [v3x]
    mov rsi, [v3y]
    mov rdx, [v7x]
    mov rcx, [v7y]
    mov r8, 11
    call draw_line

    ; Increment angle
    inc r12

    ; Delay (slower rotation)
    mov rcx, 15000000
.delay:
    dec rcx
    jnz .delay

    jmp .main_loop

; ════════════════════════════════════════════════════════════════════════════
; VERTEX STORAGE (in BSS-like area)
; ════════════════════════════════════════════════════════════════════════════
align 8
v0x: dq 0
v0y: dq 0
v1x: dq 0
v1y: dq 0
v2x: dq 0
v2y: dq 0
v3x: dq 0
v3y: dq 0
v4x: dq 0
v4y: dq 0
v5x: dq 0
v5y: dq 0
v6x: dq 0
v6y: dq 0
v7x: dq 0
v7y: dq 0

; ════════════════════════════════════════════════════════════════════════════
; DRAW LINE - Bresenham: rdi=x0, rsi=y0, rdx=x1, rcx=y1, r8=color
; ════════════════════════════════════════════════════════════════════════════
draw_line:
    push rbx
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov r9, rdx               ; x1
    mov r10, rcx              ; y1
    mov r14, r8               ; color

    ; dx = abs(x1 - x0)
    mov rax, r9
    sub rax, rdi
    mov r11, rax
    test r11, r11
    jns .dx_pos
    neg r11
.dx_pos:

    ; dy = -abs(y1 - y0)
    mov rax, r10
    sub rax, rsi
    mov r12, rax
    test r12, r12
    jns .dy_pos
    neg r12
.dy_pos:
    neg r12

    ; sx = x0 < x1 ? 1 : -1
    mov r13, 1
    cmp rdi, r9
    jl .sx_done
    neg r13
.sx_done:

    ; sy = y0 < y1 ? 1 : -1
    mov r15, 1
    cmp rsi, r10
    jl .sy_done
    neg r15
.sy_done:

    ; err = dx + dy
    mov rbx, r11
    add rbx, r12

.line_loop:
    ; Bounds check
    cmp rdi, 0
    jl .skip_pixel
    cmp rdi, GFX64_W
    jge .skip_pixel
    cmp rsi, 0
    jl .skip_pixel
    cmp rsi, GFX64_H
    jge .skip_pixel

    ; Plot pixel
    push rax
    mov rax, rsi
    imul rax, GFX64_W
    add rax, rdi
    add rax, GFX64_FB
    mov byte [rax], r14b
    pop rax

.skip_pixel:
    cmp rdi, r9
    jne .not_done
    cmp rsi, r10
    je .line_done
.not_done:

    mov rax, rbx
    shl rax, 1

    cmp rax, r12
    jl .skip_x
    add rbx, r12
    add rdi, r13
.skip_x:

    cmp rax, r11
    jg .skip_y
    add rbx, r11
    add rsi, r15
.skip_y:

    jmp .line_loop

.line_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop rbx
    ret

msg64_title: db "MATHIS OS 64-BIT 3D MODE", 0

; Sin lookup table: 64 entries, values = sin(angle) * 32
; angle 0-63 maps to 0-360 degrees
align 8
sin_table:
    db  0,  3,  6,  9, 12, 15, 18, 21    ; 0-7
    db 24, 26, 28, 30, 31, 32, 32, 32    ; 8-15
    db 32, 32, 32, 31, 30, 28, 26, 24    ; 16-23
    db 21, 18, 15, 12,  9,  6,  3,  0    ; 24-31
    db  0, -3, -6, -9,-12,-15,-18,-21    ; 32-39
    db -24,-26,-28,-30,-31,-32,-32,-32   ; 40-47
    db -32,-32,-32,-31,-30,-28,-26,-24   ; 48-55
    db -21,-18,-15,-12, -9, -6, -3,  0   ; 56-63

[BITS 32]

; ════════════════════════════════════════════════════════════════════════════
; GDT 64-bit
; ════════════════════════════════════════════════════════════════════════════
align 16
gdt64:
    dq 0                         ; Null descriptor
    dq 0x00209A0000000000        ; 0x08: 64-bit code segment
    dq 0x0000920000000000        ; 0x10: 64-bit data segment
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64
