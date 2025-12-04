; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - Simple 3D Graphics (for VGA 13h)
; Software 3D rendering at 320x200
; ════════════════════════════════════════════════════════════════════════════

; Fixed point: 8.8 format (simpler for 320x200)
FIXED_SHIFT_3D  equ 8

; Limits
MAX_VERTS_3D    equ 64
MAX_TRIS_3D     equ 32

; ════════════════════════════════════════════════════════════════════════════
; 3D STATE - Stored after code
; ════════════════════════════════════════════════════════════════════════════

; g3d_init_simple - Initialize 3D engine
g3d_init_simple:
    pushad

    mov dword [g3d_num_verts], 0
    mov dword [g3d_num_tris], 0

    ; Camera at (0, 0, -200) in 8.8 fixed point
    mov dword [g3d_cam_x], 0
    mov dword [g3d_cam_y], 0
    mov dword [g3d_cam_z], -200 << FIXED_SHIFT_3D

    ; Rotation angle
    mov dword [g3d_angle], 0

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; CUBE GENERATION
; ════════════════════════════════════════════════════════════════════════════

; g3d_make_cube - Create a cube centered at origin
; Input: EAX = size (8.8 fixed point)
g3d_make_cube:
    pushad

    mov esi, eax            ; size
    sar esi, 1              ; half size

    ; Reset counts
    mov dword [g3d_num_verts], 0
    mov dword [g3d_num_tris], 0

    mov edi, g3d_vertices

    ; 8 vertices of a cube
    ; v0: -s, -s, -s
    mov eax, esi
    neg eax
    mov [edi], eax          ; x
    mov [edi+4], eax        ; y
    mov [edi+8], eax        ; z
    add edi, 12

    ; v1: +s, -s, -s
    mov [edi], esi
    mov eax, esi
    neg eax
    mov [edi+4], eax
    mov [edi+8], eax
    add edi, 12

    ; v2: +s, +s, -s
    mov [edi], esi
    mov [edi+4], esi
    mov eax, esi
    neg eax
    mov [edi+8], eax
    add edi, 12

    ; v3: -s, +s, -s
    mov eax, esi
    neg eax
    mov [edi], eax
    mov [edi+4], esi
    mov [edi+8], eax
    add edi, 12

    ; v4: -s, -s, +s
    mov eax, esi
    neg eax
    mov [edi], eax
    mov [edi+4], eax
    mov [edi+8], esi
    add edi, 12

    ; v5: +s, -s, +s
    mov eax, esi
    neg eax
    mov [edi], esi
    mov [edi+4], eax
    mov [edi+8], esi
    add edi, 12

    ; v6: +s, +s, +s
    mov [edi], esi
    mov [edi+4], esi
    mov [edi+8], esi
    add edi, 12

    ; v7: -s, +s, +s
    mov eax, esi
    neg eax
    mov [edi], eax
    mov [edi+4], esi
    mov [edi+8], esi

    mov dword [g3d_num_verts], 8

    ; 12 triangles (2 per face)
    mov edi, g3d_triangles

    ; Front face (z = -s): 0,1,2  0,2,3
    mov dword [edi], 0
    mov dword [edi+4], 1
    mov dword [edi+8], 2
    add edi, 12
    mov dword [edi], 0
    mov dword [edi+4], 2
    mov dword [edi+8], 3
    add edi, 12

    ; Back face (z = +s): 5,4,7  5,7,6
    mov dword [edi], 5
    mov dword [edi+4], 4
    mov dword [edi+8], 7
    add edi, 12
    mov dword [edi], 5
    mov dword [edi+4], 7
    mov dword [edi+8], 6
    add edi, 12

    ; Top face (y = +s): 3,2,6  3,6,7
    mov dword [edi], 3
    mov dword [edi+4], 2
    mov dword [edi+8], 6
    add edi, 12
    mov dword [edi], 3
    mov dword [edi+4], 6
    mov dword [edi+8], 7
    add edi, 12

    ; Bottom face (y = -s): 4,5,1  4,1,0
    mov dword [edi], 4
    mov dword [edi+4], 5
    mov dword [edi+8], 1
    add edi, 12
    mov dword [edi], 4
    mov dword [edi+4], 1
    mov dword [edi+8], 0
    add edi, 12

    ; Left face (x = -s): 4,0,3  4,3,7
    mov dword [edi], 4
    mov dword [edi+4], 0
    mov dword [edi+8], 3
    add edi, 12
    mov dword [edi], 4
    mov dword [edi+4], 3
    mov dword [edi+8], 7
    add edi, 12

    ; Right face (x = +s): 1,5,6  1,6,2
    mov dword [edi], 1
    mov dword [edi+4], 5
    mov dword [edi+8], 6
    add edi, 12
    mov dword [edi], 1
    mov dword [edi+4], 6
    mov dword [edi+8], 2

    mov dword [g3d_num_tris], 12

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; ROTATION (Y-axis only for simplicity)
; ════════════════════════════════════════════════════════════════════════════

; Simple sine table (64 entries for 0-90 degrees, 8.8 fixed point)
g3d_sin_table:
    dw 0, 6, 13, 19, 25, 31, 37, 44
    dw 50, 56, 62, 68, 74, 79, 85, 91
    dw 97, 102, 108, 113, 118, 124, 129, 134
    dw 139, 143, 148, 152, 157, 161, 165, 169
    dw 173, 177, 181, 184, 188, 191, 194, 197
    dw 200, 203, 205, 208, 210, 212, 214, 216
    dw 218, 219, 221, 222, 223, 224, 225, 226
    dw 227, 227, 228, 228, 228, 228, 228, 228

; g3d_rotate_verts - Rotate all vertices around Y axis
; Input: EAX = angle (0-255)
g3d_rotate_verts:
    pushad

    ; Get sin and cos from table
    mov ebx, eax
    and ebx, 63             ; angle mod 64
    movzx ecx, word [g3d_sin_table + ebx * 2]  ; sin

    ; cos = sin(64 - angle)
    mov edx, 64
    sub edx, ebx
    and edx, 63
    movzx edx, word [g3d_sin_table + edx * 2]  ; cos

    ; Rotate each vertex
    mov esi, g3d_vertices
    mov edi, [g3d_num_verts]

.rotate_loop:
    test edi, edi
    jz .done

    ; x' = x * cos - z * sin
    ; z' = x * sin + z * cos
    mov eax, [esi]          ; x
    mov ebx, [esi + 8]      ; z

    ; x' = x * cos - z * sin
    push edx
    imul eax, edx           ; x * cos
    sar eax, FIXED_SHIFT_3D
    push eax

    mov eax, ebx
    imul eax, ecx           ; z * sin
    sar eax, FIXED_SHIFT_3D

    pop ebx
    sub ebx, eax            ; x' = x*cos - z*sin

    ; z' = x * sin + z * cos
    mov eax, [esi]          ; original x
    imul eax, ecx           ; x * sin
    sar eax, FIXED_SHIFT_3D
    push eax

    mov eax, [esi + 8]      ; original z
    pop edx
    push edx
    pop edx
    push ecx
    mov ecx, [esp + 4]      ; cos
    imul eax, ecx           ; z * cos
    sar eax, FIXED_SHIFT_3D
    pop ecx

    mov edx, [esi]
    imul edx, ecx
    sar edx, FIXED_SHIFT_3D
    add eax, edx            ; z' = x*sin + z*cos

    ; Store rotated
    mov [esi], ebx          ; x'
    mov [esi + 8], eax      ; z'

    pop edx
    add esi, 12
    dec edi
    jmp .rotate_loop

.done:
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; PROJECTION & RENDERING
; ════════════════════════════════════════════════════════════════════════════

; g3d_project - Project 3D point to 2D screen
; Input: EAX = x, EBX = y, ECX = z (all 8.8)
; Output: EAX = screen_x, EBX = screen_y
g3d_project:
    push edx

    ; Add camera offset
    sub ecx, [g3d_cam_z]

    ; Avoid divide by zero
    cmp ecx, 256
    jl .behind

    ; Perspective projection
    ; screen_x = 160 + (x * 256 / z)
    ; screen_y = 100 - (y * 256 / z)

    push ecx
    shl eax, 8              ; x * 256
    cdq
    idiv ecx
    add eax, 160            ; center x
    mov edx, eax            ; save screen_x

    pop ecx
    shl ebx, 8              ; y * 256
    push edx
    cdq
    idiv ecx
    mov ebx, 100
    sub ebx, eax            ; screen_y = 100 - projected_y
    pop eax                 ; screen_x

    pop edx
    ret

.behind:
    mov eax, -1000
    mov ebx, -1000
    pop edx
    ret

; g3d_render_wireframe - Render all triangles as wireframe
g3d_render_wireframe:
    pushad

    mov ecx, [g3d_num_tris]
    mov esi, g3d_triangles

.tri_loop:
    test ecx, ecx
    jz .done

    push ecx
    push esi

    ; Get vertex indices
    mov eax, [esi]          ; v0
    mov ebx, [esi + 4]      ; v1
    mov edx, [esi + 8]      ; v2

    ; Draw 3 edges
    push edx
    push ebx
    push eax
    call g3d_draw_edge      ; v0 -> v1
    pop eax
    pop ebx
    pop edx

    push edx
    push ebx
    call g3d_draw_edge      ; v1 -> v2
    pop ebx
    pop edx

    push eax
    push edx
    call g3d_draw_edge      ; v2 -> v0
    pop edx
    pop eax

    pop esi
    add esi, 12
    pop ecx
    dec ecx
    jmp .tri_loop

.done:
    popad
    ret

; g3d_draw_edge - Draw edge between two vertices
; Input: on stack - v0_idx, v1_idx
g3d_draw_edge:
    pushad
    mov ebp, esp

    ; Get v0 position
    mov eax, [ebp + 36]     ; v0 index
    imul eax, 12
    add eax, g3d_vertices
    mov esi, eax

    mov eax, [esi]          ; x
    mov ebx, [esi + 4]      ; y
    mov ecx, [esi + 8]      ; z
    call g3d_project
    push ebx                ; save y0
    push eax                ; save x0

    ; Get v1 position
    mov eax, [ebp + 40]     ; v1 index
    imul eax, 12
    add eax, g3d_vertices
    mov esi, eax

    mov eax, [esi]
    mov ebx, [esi + 4]
    mov ecx, [esi + 8]
    call g3d_project
    mov ecx, eax            ; x1
    mov edx, ebx            ; y1

    pop eax                 ; x0
    pop ebx                 ; y0

    ; Skip if any point is behind camera
    cmp eax, -500
    jl .skip
    cmp ecx, -500
    jl .skip

    ; Draw line
    push dword 255          ; white color
    call vga13_line

.skip:
    popad
    ret 8

; ════════════════════════════════════════════════════════════════════════════
; MAIN 3D DEMO
; ════════════════════════════════════════════════════════════════════════════

; g3d_demo_cube - Animated rotating cube demo
g3d_demo_cube:
    pushad

    ; Initialize
    call g3d_init_simple
    call vga13_setup_palette

    ; Create cube (size = 50 in 8.8)
    mov eax, 50 << FIXED_SHIFT_3D
    call g3d_make_cube

    ; Move camera back
    mov dword [g3d_cam_z], -300 << FIXED_SHIFT_3D

.anim_loop:
    ; Clear screen
    mov al, 0               ; black
    call vga13_clear

    ; Rotate cube
    mov eax, [g3d_angle]
    call g3d_rotate_verts

    ; Render wireframe
    call g3d_render_wireframe

    ; Increment angle
    inc dword [g3d_angle]

    ; Small delay
    mov ecx, 100000
.delay:
    dec ecx
    jnz .delay

    ; Recreate cube (rotation destroys original coords)
    mov eax, 50 << FIXED_SHIFT_3D
    call g3d_make_cube

    jmp .anim_loop

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════

g3d_num_verts:  dd 0
g3d_num_tris:   dd 0
g3d_cam_x:      dd 0
g3d_cam_y:      dd 0
g3d_cam_z:      dd 0
g3d_angle:      dd 0

; Vertex buffer: x, y, z (12 bytes each)
g3d_vertices:   times MAX_VERTS_3D * 3 dd 0

; Triangle buffer: v0, v1, v2 indices (12 bytes each)
g3d_triangles:  times MAX_TRIS_3D * 3 dd 0
