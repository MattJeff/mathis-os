; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - VGA Mode 13h Graphics (320x200x256)
; Simple and reliable graphics for 3D rendering
; ════════════════════════════════════════════════════════════════════════════

; VGA Mode 13h constants
VGA_FRAMEBUFFER equ 0xA0000
VGA_WIDTH       equ 320
VGA_HEIGHT      equ 200

; ════════════════════════════════════════════════════════════════════════════
; SET VGA MODE 13h FROM PROTECTED MODE
; We program VGA registers directly (can't use BIOS int 10h in PM)
; ════════════════════════════════════════════════════════════════════════════

vga13_set_mode:
    pushad

    ; Unlock VGA registers
    mov dx, 0x3C2
    mov al, 0x63            ; Misc output register
    out dx, al

    ; Sequencer registers
    mov dx, 0x3C4
    mov al, 0x00            ; Reset
    out dx, al
    inc dx
    mov al, 0x03
    out dx, al

    dec dx
    mov al, 0x01            ; Clocking mode
    out dx, al
    inc dx
    mov al, 0x01
    out dx, al

    dec dx
    mov al, 0x02            ; Map mask
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al

    dec dx
    mov al, 0x03            ; Character map
    out dx, al
    inc dx
    mov al, 0x00
    out dx, al

    dec dx
    mov al, 0x04            ; Memory mode
    out dx, al
    inc dx
    mov al, 0x0E
    out dx, al

    ; CRTC registers - unlock
    mov dx, 0x3D4
    mov al, 0x11
    out dx, al
    inc dx
    in al, dx
    and al, 0x7F
    out dx, al

    ; CRTC mode 13h values
    dec dx
    mov esi, vga13_crtc_regs
    xor ecx, ecx
.crtc_loop:
    mov al, cl
    out dx, al
    inc dx
    lodsb
    out dx, al
    dec dx
    inc cl
    cmp cl, 25
    jb .crtc_loop

    ; Graphics controller
    mov dx, 0x3CE
    xor ecx, ecx
    mov esi, vga13_gc_regs
.gc_loop:
    mov al, cl
    out dx, al
    inc dx
    lodsb
    out dx, al
    dec dx
    inc cl
    cmp cl, 9
    jb .gc_loop

    ; Attribute controller
    mov dx, 0x3DA           ; Reset flip-flop
    in al, dx
    mov dx, 0x3C0
    xor ecx, ecx
    mov esi, vga13_attr_regs
.attr_loop:
    mov al, cl
    out dx, al
    lodsb
    out dx, al
    inc cl
    cmp cl, 21
    jb .attr_loop

    ; Enable display
    mov al, 0x20
    out dx, al

    popad
    ret

; VGA Mode 13h register tables
vga13_crtc_regs:
    db 0x5F, 0x4F, 0x50, 0x82, 0x54, 0x80, 0xBF, 0x1F
    db 0x00, 0x41, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    db 0x9C, 0x0E, 0x8F, 0x28, 0x40, 0x96, 0xB9, 0xA3
    db 0xFF

vga13_gc_regs:
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x05, 0x0F
    db 0xFF

vga13_attr_regs:
    db 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07
    db 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
    db 0x41, 0x00, 0x0F, 0x00, 0x00

; ════════════════════════════════════════════════════════════════════════════
; RETURN TO TEXT MODE
; ════════════════════════════════════════════════════════════════════════════

vga_set_text_mode:
    pushad

    ; Similar process but with text mode registers
    ; For now just clear screen at 0xB8000
    mov edi, 0xB8000
    mov ecx, 2000
    mov eax, 0x0720
    rep stosd

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; PALETTE SETUP - Create a nice color palette
; ════════════════════════════════════════════════════════════════════════════

; vga13_setup_palette - Setup a gradient palette
vga13_setup_palette:
    pushad

    ; Write to VGA palette (port 0x3C8 = index, 0x3C9 = RGB data)
    mov dx, 0x3C8
    xor al, al              ; Start at color 0
    out dx, al

    mov dx, 0x3C9
    xor ecx, ecx

.palette_loop:
    ; Create gradient: dark blue -> cyan -> white
    mov al, cl
    shr al, 2               ; R = index / 4
    out dx, al

    mov al, cl
    shr al, 1               ; G = index / 2
    out dx, al

    mov al, cl              ; B = index
    out dx, al

    inc cl
    jnz .palette_loop

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; BASIC DRAWING FUNCTIONS
; ════════════════════════════════════════════════════════════════════════════

; vga13_clear - Clear screen with color
; Input: AL = color index
vga13_clear:
    pushad

    mov edi, VGA_FRAMEBUFFER
    mov ah, al              ; Duplicate color for word write
    mov ecx, (VGA_WIDTH * VGA_HEIGHT) / 4
    mov edx, eax
    shl eax, 16
    or eax, edx             ; 4 pixels at once
    rep stosd

    popad
    ret

; vga13_putpixel - Draw a single pixel
; Input: EAX = x, EBX = y, CL = color
vga13_putpixel:
    push edi
    push edx

    ; Bounds check
    cmp eax, VGA_WIDTH
    jae .done
    cmp ebx, VGA_HEIGHT
    jae .done

    ; Calculate offset: y * 320 + x
    mov edi, ebx
    shl edi, 8              ; y * 256
    push eax
    mov eax, ebx
    shl eax, 6              ; y * 64
    add edi, eax            ; y * 256 + y * 64 = y * 320
    pop eax
    add edi, eax            ; + x
    add edi, VGA_FRAMEBUFFER

    mov [edi], cl

.done:
    pop edx
    pop edi
    ret

; vga13_line - Draw line using Bresenham's algorithm
; Input: EAX = x0, EBX = y0, ECX = x1, EDX = y1, [esp+4] = color
vga13_line:
    pushad
    mov ebp, esp

    mov esi, [ebp + 36]     ; color from stack

    ; Calculate dx = abs(x1 - x0)
    sub ecx, eax            ; dx = x1 - x0
    mov edi, ecx
    sar edi, 31             ; sign extend
    xor ecx, edi
    sub ecx, edi            ; abs(dx)

    ; sx = x0 < x1 ? 1 : -1
    mov edi, 1
    cmp eax, [ebp + 36 - 28]  ; compare with original x1
    jl .sx_done
    neg edi
.sx_done:
    push edi                ; save sx

    ; Calculate dy = -abs(y1 - y0)
    mov edi, edx
    sub edi, ebx            ; dy = y1 - y0
    push edx                ; save y1
    mov edx, edi
    sar edx, 31
    xor edi, edx
    sub edi, edx            ; abs(dy)
    neg edi                 ; dy = -abs(dy)

    ; sy = y0 < y1 ? 1 : -1
    pop edx                 ; restore y1
    push edi                ; save dy
    mov edi, 1
    cmp ebx, edx
    jl .sy_done
    neg edi
.sy_done:
    push edi                ; save sy

    ; err = dx + dy
    pop edi                 ; sy
    pop ebp                 ; dy
    pop edx                 ; sx (reusing edx)

    push edi                ; sy back
    push edx                ; sx back

    mov edi, ecx            ; err = dx
    add edi, ebp            ; err += dy

    ; Line loop
.line_loop:
    ; Draw pixel at (eax, ebx)
    push ecx
    push esi
    and esi, 0xFF           ; mask to get low byte
    mov ecx, esi
    pop esi
    call vga13_putpixel
    pop ecx

    ; Check if done
    cmp eax, [esp + 40]     ; x1
    jne .not_done
    cmp ebx, [esp + 44]     ; y1
    je .line_done
.not_done:

    ; e2 = 2 * err
    mov edx, edi
    shl edx, 1

    ; if e2 >= dy: err += dy, x += sx
    cmp edx, ebp
    jl .skip_x
    add edi, ebp
    add eax, [esp]          ; sx
.skip_x:

    ; if e2 <= dx: err += dx, y += sy
    cmp edx, ecx
    jg .skip_y
    add edi, ecx
    add ebx, [esp + 4]      ; sy
.skip_y:

    jmp .line_loop

.line_done:
    add esp, 8              ; clean sx, sy
    popad
    ret 4                   ; clean color from stack

; vga13_fillrect - Fill rectangle
; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
vga13_fillrect:
    pushad

    ; Calculate starting address
    mov edi, ebx
    shl edi, 8              ; y * 256
    push eax
    mov eax, ebx
    shl eax, 6              ; y * 64
    add edi, eax            ; y * 320
    pop eax
    add edi, eax
    add edi, VGA_FRAMEBUFFER

    mov eax, esi            ; color

.row_loop:
    push edi
    push ecx

    rep stosb               ; fill row

    pop ecx
    pop edi
    add edi, VGA_WIDTH      ; next row
    dec edx
    jnz .row_loop

    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; DEMO - Show something on screen
; ════════════════════════════════════════════════════════════════════════════

; vga13_demo - Draw a test pattern
vga13_demo:
    pushad

    ; Setup nice palette
    call vga13_setup_palette

    ; Clear to dark blue
    mov al, 16
    call vga13_clear

    ; Draw some rectangles
    mov eax, 50             ; x
    mov ebx, 50             ; y
    mov ecx, 60             ; width
    mov edx, 40             ; height
    mov esi, 40             ; color (cyan-ish)
    call vga13_fillrect

    mov eax, 100
    mov ebx, 70
    mov ecx, 80
    mov edx, 60
    mov esi, 80             ; brighter
    call vga13_fillrect

    mov eax, 180
    mov ebx, 40
    mov ecx, 100
    mov edx, 80
    mov esi, 120            ; white-ish
    call vga13_fillrect

    ; Draw some lines
    mov eax, 10             ; x0
    mov ebx, 10             ; y0
    mov ecx, 310            ; x1
    mov edx, 190            ; y1
    push dword 255          ; color white
    call vga13_line

    mov eax, 310
    mov ebx, 10
    mov ecx, 10
    mov edx, 190
    push dword 200          ; color
    call vga13_line

    popad
    ret
