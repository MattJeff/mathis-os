; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - 3D Graphics Engine (Simplified)
; Software 3D rendering for MATHIS OS
; ════════════════════════════════════════════════════════════════════════════

; Uses fixed memory addresses for buffers (no .bss section)
; Vertex buffer at 0x100000 (1MB mark)
; Triangle buffer at 0x110000
; Z-buffer at 0x120000
; Matrices at 0x130000

VERTEX_BUFFER   equ 0x100000
TRIANGLE_BUFFER equ 0x110000
ZBUFFER         equ 0x120000
MATRIX_AREA     equ 0x130000

MAX_VERTICES    equ 1024
MAX_TRIANGLES   equ 512
FIXED_SHIFT     equ 16          ; 16.16 fixed point

; ════════════════════════════════════════════════════════════════════════════
; INITIALIZATION
; ════════════════════════════════════════════════════════════════════════════

; g3d_init - Initialize 3D engine
g3d_init:
    pushad

    ; Clear counts
    mov dword [g3d_vertex_count], 0
    mov dword [g3d_triangle_count], 0

    ; Default camera position (0, 2, -5 in fixed point)
    mov dword [g3d_camera_x], 0
    mov dword [g3d_camera_y], 2 << FIXED_SHIFT
    mov dword [g3d_camera_z], -5 << FIXED_SHIFT

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; CLEAR SCREEN / Z-BUFFER
; ════════════════════════════════════════════════════════════════════════════

; g3d_clear_screen - Clear framebuffer with color
; Input: EAX = color
g3d_clear_screen:
    pushad

    mov edi, [FB_ADDRESS]
    test edi, edi
    jz .done

    mov ecx, [FB_WIDTH]
    imul ecx, [FB_HEIGHT]
    rep stosd

.done:
    popad
    ret

; g3d_clear_zbuffer - Clear depth buffer
g3d_clear_zbuffer:
    pushad

    mov edi, ZBUFFER
    mov ecx, [FB_WIDTH]
    imul ecx, [FB_HEIGHT]
    mov eax, 0x7FFFFFFF
    rep stosd

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; VERTEX/TRIANGLE MANAGEMENT
; ════════════════════════════════════════════════════════════════════════════

; g3d_add_vertex - Add vertex to buffer
; Input: EAX = x, EBX = y, ECX = z (16.16 fixed point)
; Output: EAX = vertex index
g3d_add_vertex:
    push ebx
    push ecx
    push edi
    push edx

    mov edx, [g3d_vertex_count]
    cmp edx, MAX_VERTICES
    jge .full

    ; Calculate buffer offset (16 bytes per vertex)
    mov edi, edx
    shl edi, 4
    add edi, VERTEX_BUFFER

    ; Store vertex
    mov [edi], eax          ; x
    mov [edi + 4], ebx      ; y
    mov [edi + 8], ecx      ; z
    mov dword [edi + 12], 1 << FIXED_SHIFT  ; w = 1.0

    ; Return index and increment count
    mov eax, edx
    inc dword [g3d_vertex_count]
    jmp .done

.full:
    mov eax, -1

.done:
    pop edx
    pop edi
    pop ecx
    pop ebx
    ret

; g3d_add_triangle - Add triangle (3 vertex indices)
; Input: EAX = v0, EBX = v1, ECX = v2
g3d_add_triangle:
    push edi
    push edx

    mov edx, [g3d_triangle_count]
    cmp edx, MAX_TRIANGLES
    jge .full

    ; Calculate buffer offset (12 bytes per triangle)
    mov edi, edx
    imul edi, 12
    add edi, TRIANGLE_BUFFER

    ; Store indices
    mov [edi], eax
    mov [edi + 4], ebx
    mov [edi + 8], ecx

    inc dword [g3d_triangle_count]

.full:
    pop edx
    pop edi
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIMPLE 3D TO 2D PROJECTION
; ════════════════════════════════════════════════════════════════════════════

; g3d_project_vertex - Project 3D vertex to 2D screen
; Input: ESI = vertex buffer offset
; Output: EAX = screen_x, EBX = screen_y, ECX = depth
g3d_project_vertex:
    push edx
    push edi

    ; Load vertex
    mov eax, [esi]          ; x
    mov ebx, [esi + 4]      ; y
    mov ecx, [esi + 8]      ; z

    ; Apply camera translation
    sub eax, [g3d_camera_x]
    sub ebx, [g3d_camera_y]
    sub ecx, [g3d_camera_z]

    ; Simple perspective: screen = pos * scale / z
    ; Avoid division by zero
    cmp ecx, 0x1000
    jl .behind_camera

    ; Perspective divide
    push ecx                ; save z

    ; Scale factor for perspective
    mov edi, 300 << FIXED_SHIFT

    ; screen_x = x * scale / z + width/2
    push eax
    imul eax, edi
    cdq
    idiv ecx
    mov edx, [FB_WIDTH]
    shr edx, 1
    add eax, edx
    mov [esp + 4], eax      ; save screen_x temporarily

    ; screen_y = height/2 - y * scale / z
    pop eax                 ; restore original x (we saved screen_x)
    mov eax, ebx            ; use y
    imul eax, edi
    cdq
    pop ecx                 ; restore z
    push ecx
    idiv ecx
    mov edx, [FB_HEIGHT]
    shr edx, 1
    sub edx, eax
    mov ebx, edx            ; screen_y

    pop ecx                 ; depth = z
    pop eax                 ; screen_x

    jmp .done

.behind_camera:
    ; Vertex behind camera
    mov eax, -10000
    mov ebx, -10000
    mov ecx, 0x7FFFFFFF

.done:
    pop edi
    pop edx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAWING PRIMITIVES
; ════════════════════════════════════════════════════════════════════════════

; g3d_draw_pixel - Draw pixel with optional z-test
; Input: EAX = x, EBX = y, ECX = color
g3d_draw_pixel:
    pushad

    ; Bounds check
    cmp eax, 0
    jl .done
    cmp ebx, 0
    jl .done
    cmp eax, [FB_WIDTH]
    jge .done
    cmp ebx, [FB_HEIGHT]
    jge .done

    ; Calculate offset
    mov edi, ebx
    imul edi, [FB_PITCH]
    mov edx, eax
    shl edx, 2              ; x * 4
    add edi, edx
    add edi, [FB_ADDRESS]

    ; Draw pixel
    mov [edi], ecx

.done:
    popad
    ret

; g3d_draw_line_simple - Draw line between two screen points
; Input: EAX = x0, EBX = y0, ECX = x1, EDX = y1, ESI = color
g3d_draw_line_simple:
    pushad

    ; Bresenham's line algorithm
    mov edi, esi            ; color

    ; Calculate dx, dy
    sub ecx, eax            ; dx = x1 - x0
    sub edx, ebx            ; dy = y1 - y0

    ; Determine step directions
    push eax
    push ebx

    ; sx = sign(dx)
    mov esi, 1
    test ecx, ecx
    jns .dx_pos
    neg ecx
    neg esi
.dx_pos:
    push esi                ; save sx

    ; sy = sign(dy)
    mov esi, 1
    test edx, edx
    jns .dy_pos
    neg edx
    neg esi
.dy_pos:
    push esi                ; save sy

    ; err = dx - dy
    mov esi, ecx
    sub esi, edx
    push esi                ; save err

    pop esi                 ; err
    pop ebp                 ; sy (using ebp temporarily)
    pop eax                 ; sx (reusing eax)
    pop ebx                 ; y0
    pop eax                 ; x0 (overwriting sx, need to recalculate)

    ; Simplified: just draw endpoints for now
    ; Full Bresenham would go here
    mov ecx, edi            ; color
    call g3d_draw_pixel

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; HIGH-LEVEL RENDERING
; ════════════════════════════════════════════════════════════════════════════

; g3d_render - Render all triangles as wireframe
g3d_render:
    pushad

    mov ecx, [g3d_triangle_count]
    test ecx, ecx
    jz .done

    mov esi, TRIANGLE_BUFFER

.render_loop:
    push ecx
    push esi

    ; Get triangle vertices
    mov eax, [esi]          ; v0 index
    mov ebx, [esi + 4]      ; v1 index
    mov edx, [esi + 8]      ; v2 index

    ; Project and draw edges
    ; For simplicity, just draw the triangle outline

    ; Edge v0 -> v1
    push edx
    push ebx
    push eax

    ; Project v0
    shl eax, 4
    add eax, VERTEX_BUFFER
    mov esi, eax
    call g3d_project_vertex
    push eax                ; save screen_x0
    push ebx                ; save screen_y0

    ; Project v1
    pop ebx                 ; restore y0
    pop eax                 ; restore x0
    pop edx                 ; v0 index (discard)
    pop edx                 ; v1 index
    push eax
    push ebx

    shl edx, 4
    add edx, VERTEX_BUFFER
    mov esi, edx
    call g3d_project_vertex
    mov ecx, eax            ; x1
    mov edx, ebx            ; y1

    pop ebx                 ; y0
    pop eax                 ; x0
    mov esi, 0x00FFFFFF     ; white color
    call g3d_draw_line_simple

    pop esi
    add esi, 12
    pop ecx
    dec ecx
    jnz .render_loop

.done:
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; PRIMITIVE SHAPES
; ════════════════════════════════════════════════════════════════════════════

; g3d_draw_cube - Add a cube to the scene
; Input: EAX = x, EBX = y, ECX = z, EDX = size (all 16.16 fixed point)
g3d_draw_cube:
    pushad

    ; Calculate half size
    mov esi, edx
    sar esi, 1

    ; Save center position
    push ecx                ; z
    push ebx                ; y
    push eax                ; x

    ; Add 8 vertices (front face then back face)
    ; v0: x-s, y-s, z-s
    sub eax, esi
    sub ebx, esi
    sub ecx, esi
    call g3d_add_vertex
    push eax                ; save v0

    ; v1: x+s, y-s, z-s
    mov eax, [esp + 4]
    add eax, esi
    mov ebx, [esp + 8]
    sub ebx, esi
    mov ecx, [esp + 12]
    sub ecx, esi
    call g3d_add_vertex
    push eax                ; save v1

    ; v2: x+s, y+s, z-s
    mov eax, [esp + 8]
    add eax, esi
    mov ebx, [esp + 12]
    add ebx, esi
    mov ecx, [esp + 16]
    sub ecx, esi
    call g3d_add_vertex
    push eax                ; save v2

    ; v3: x-s, y+s, z-s
    mov eax, [esp + 12]
    sub eax, esi
    mov ebx, [esp + 16]
    add ebx, esi
    mov ecx, [esp + 20]
    sub ecx, esi
    call g3d_add_vertex
    push eax                ; save v3

    ; v4: x-s, y-s, z+s
    mov eax, [esp + 16]
    sub eax, esi
    mov ebx, [esp + 20]
    sub ebx, esi
    mov ecx, [esp + 24]
    add ecx, esi
    call g3d_add_vertex
    push eax                ; save v4

    ; v5: x+s, y-s, z+s
    mov eax, [esp + 20]
    add eax, esi
    mov ebx, [esp + 24]
    sub ebx, esi
    mov ecx, [esp + 28]
    add ecx, esi
    call g3d_add_vertex
    push eax                ; save v5

    ; v6: x+s, y+s, z+s
    mov eax, [esp + 24]
    add eax, esi
    mov ebx, [esp + 28]
    add ebx, esi
    mov ecx, [esp + 32]
    add ecx, esi
    call g3d_add_vertex
    push eax                ; save v6

    ; v7: x-s, y+s, z+s
    mov eax, [esp + 28]
    sub eax, esi
    mov ebx, [esp + 32]
    add ebx, esi
    mov ecx, [esp + 36]
    add ecx, esi
    call g3d_add_vertex
    push eax                ; save v7

    ; Stack now: v7 v6 v5 v4 v3 v2 v1 v0 x y z

    ; Add 12 triangles (2 per face)
    ; Front face (v0, v1, v2), (v0, v2, v3)
    mov eax, [esp + 28]     ; v0
    mov ebx, [esp + 24]     ; v1
    mov ecx, [esp + 20]     ; v2
    call g3d_add_triangle

    mov eax, [esp + 28]     ; v0
    mov ebx, [esp + 20]     ; v2
    mov ecx, [esp + 16]     ; v3
    call g3d_add_triangle

    ; Back face (v5, v4, v7), (v5, v7, v6)
    mov eax, [esp + 8]      ; v5
    mov ebx, [esp + 12]     ; v4
    mov ecx, [esp]          ; v7
    call g3d_add_triangle

    mov eax, [esp + 8]      ; v5
    mov ebx, [esp]          ; v7
    mov ecx, [esp + 4]      ; v6
    call g3d_add_triangle

    ; Clean up stack
    add esp, 44             ; 8 vertices + 3 coords

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA (in code section for flat binary)
; ════════════════════════════════════════════════════════════════════════════

g3d_vertex_count:   dd 0
g3d_triangle_count: dd 0
g3d_camera_x:       dd 0
g3d_camera_y:       dd 0
g3d_camera_z:       dd 0
