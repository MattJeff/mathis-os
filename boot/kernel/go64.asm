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

    ; Initialize angles to 0
    xor r12, r12              ; r12 = angleY (0-63 for full rotation)
    mov qword [angleX], 0     ; angleX stored in memory

.main_loop:
    ; Clear screen (black)
    mov rdi, GFX64_FB
    mov rcx, GFX64_W * GFX64_H / 8
    xor rax, rax
    rep stosq

    ; Get sinY and cosY from lookup table
    mov rax, r12
    and rax, 0x3F
    mov rbx, rax
    add rbx, 16
    and rbx, 0x3F
    movsx r13, byte [sin_table + rax]   ; r13 = sinY * 32
    movsx r14, byte [sin_table + rbx]   ; r14 = cosY * 32

    ; Get sinX and cosX (angleX rotates slower for nice tumbling effect)
    mov rax, [angleX]
    and rax, 0x3F
    mov rbx, rax
    add rbx, 16
    and rbx, 0x3F
    movsx r8, byte [sin_table + rax]    ; r8 = sinX * 32
    movsx r9, byte [sin_table + rbx]    ; r9 = cosX * 32

    ; ══════════════════════════════════════════════════════════════════
    ; TRANSFORM 8 VERTICES with full 3D rotation (Y then X)
    ; Rotation Y: x' = x*cosY + z*sinY, z' = -x*sinY + z*cosY
    ; Rotation X: y' = y*cosX - z'*sinX, z'' = y*sinX + z'*cosX
    ; ══════════════════════════════════════════════════════════════════

    ; Vertex 0: (-40, -40, -40)
    mov rdi, -40
    mov rsi, -40
    mov rdx, -40
    call transform_vertex
    mov [v0x], rax
    mov [v0y], rbx

    ; Vertex 1: (40, -40, -40)
    mov rdi, 40
    mov rsi, -40
    mov rdx, -40
    call transform_vertex
    mov [v1x], rax
    mov [v1y], rbx

    ; Vertex 2: (40, 40, -40)
    mov rdi, 40
    mov rsi, 40
    mov rdx, -40
    call transform_vertex
    mov [v2x], rax
    mov [v2y], rbx

    ; Vertex 3: (-40, 40, -40)
    mov rdi, -40
    mov rsi, 40
    mov rdx, -40
    call transform_vertex
    mov [v3x], rax
    mov [v3y], rbx

    ; Vertex 4: (-40, -40, 40)
    mov rdi, -40
    mov rsi, -40
    mov rdx, 40
    call transform_vertex
    mov [v4x], rax
    mov [v4y], rbx

    ; Vertex 5: (40, -40, 40)
    mov rdi, 40
    mov rsi, -40
    mov rdx, 40
    call transform_vertex
    mov [v5x], rax
    mov [v5y], rbx

    ; Vertex 6: (40, 40, 40)
    mov rdi, 40
    mov rsi, 40
    mov rdx, 40
    call transform_vertex
    mov [v6x], rax
    mov [v6y], rbx

    ; Vertex 7: (-40, 40, 40)
    mov rdi, -40
    mov rsi, 40
    mov rdx, 40
    call transform_vertex
    mov [v7x], rax
    mov [v7y], rbx

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

    ; Front face X (red)
    mov rdi, [v0x]
    mov rsi, [v0y]
    mov rdx, [v2x]
    mov rcx, [v2y]
    mov r8, 4
    call draw_line
    mov rdi, [v1x]
    mov rsi, [v1y]
    mov rdx, [v3x]
    mov rcx, [v3y]
    mov r8, 4
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

    ; Back face X (yellow)
    mov rdi, [v4x]
    mov rsi, [v4y]
    mov rdx, [v6x]
    mov rcx, [v6y]
    mov r8, 14
    call draw_line
    mov rdi, [v5x]
    mov rsi, [v5y]
    mov rdx, [v7x]
    mov rcx, [v7y]
    mov r8, 14
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

    ; Top face X (blue) - v0,v1,v5,v4
    mov rdi, [v0x]
    mov rsi, [v0y]
    mov rdx, [v5x]
    mov rcx, [v5y]
    mov r8, 1
    call draw_line
    mov rdi, [v1x]
    mov rsi, [v1y]
    mov rdx, [v4x]
    mov rcx, [v4y]
    mov r8, 1
    call draw_line

    ; Bottom face X (magenta) - v3,v2,v6,v7
    mov rdi, [v3x]
    mov rsi, [v3y]
    mov rdx, [v6x]
    mov rcx, [v6y]
    mov r8, 5
    call draw_line
    mov rdi, [v2x]
    mov rsi, [v2y]
    mov rdx, [v7x]
    mov rcx, [v7y]
    mov r8, 5
    call draw_line

    ; Increment angles (Y faster, X slower for tumbling effect)
    inc r12
    mov rax, [angleX]
    add rax, 1              ; X rotates at same speed but different phase
    mov [angleX], rax

    ; Delay (slower rotation)
    mov rcx, 8000000
.delay:
    dec rcx
    jnz .delay

    jmp .main_loop

; ════════════════════════════════════════════════════════════════════════════
; TRANSFORM VERTEX - Apply Y and X rotation, project to 2D
; Input: rdi=x, rsi=y, rdx=z
; Output: rax=screen_x, rbx=screen_y
; Uses: r8=sinX, r9=cosX, r13=sinY, r14=cosY (set before calling)
; ════════════════════════════════════════════════════════════════════════════
transform_vertex:
    push rcx
    push r10
    push r11

    ; Step 1: Rotate around Y axis
    ; x' = x*cosY + z*sinY
    ; z' = -x*sinY + z*cosY
    mov rax, rdi
    imul rax, r14             ; x * cosY
    mov rcx, rdx
    imul rcx, r13             ; z * sinY
    add rax, rcx              ; x' = x*cosY + z*sinY
    sar rax, 5                ; divide by 32
    mov r10, rax              ; r10 = x'

    mov rax, rdi
    imul rax, r13             ; x * sinY
    neg rax                   ; -x * sinY
    mov rcx, rdx
    imul rcx, r14             ; z * cosY
    add rax, rcx              ; z' = -x*sinY + z*cosY
    sar rax, 5
    mov r11, rax              ; r11 = z'

    ; Step 2: Rotate around X axis
    ; y' = y*cosX - z'*sinX
    ; z'' = y*sinX + z'*cosX
    mov rax, rsi
    imul rax, r9              ; y * cosX
    mov rcx, r11
    imul rcx, r8              ; z' * sinX
    sub rax, rcx              ; y' = y*cosX - z'*sinX
    sar rax, 5
    mov rbx, rax              ; rbx = y' (will become screen_y)

    ; z'' for perspective (optional, we use simple projection)
    mov rax, rsi
    imul rax, r8              ; y * sinX
    mov rcx, r11
    imul rcx, r9              ; z' * cosX
    add rax, rcx              ; z'' = y*sinX + z'*cosX
    sar rax, 5                ; r11 = z'' (depth, could use for perspective)

    ; Project to screen coordinates
    mov rax, r10
    add rax, CENTER_X         ; screen_x = x' + center
    add rbx, CENTER_Y         ; screen_y = y' + center

    pop r11
    pop r10
    pop rcx
    ret

; ════════════════════════════════════════════════════════════════════════════
; VERTEX STORAGE (in BSS-like area)
; ════════════════════════════════════════════════════════════════════════════
align 8
angleX: dq 0
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
