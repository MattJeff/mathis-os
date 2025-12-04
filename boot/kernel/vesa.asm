; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - VESA/VBE Graphics Module
; High-resolution framebuffer graphics for 3D rendering
; ════════════════════════════════════════════════════════════════════════════

; NOTE: Framebuffer info is read from fixed addresses set by stage2:
; FB_ENABLED = 0x500, FB_ADDRESS = 0x510, FB_WIDTH = 0x514, etc.
; (defined in core.asm)

; ════════════════════════════════════════════════════════════════════════════
; FRAMEBUFFER OPERATIONS (32-bit protected mode)
; ════════════════════════════════════════════════════════════════════════════

; fb_clear - Clear framebuffer with color
; Input: EAX = color (0x00RRGGBB)
fb_clear:
    push eax
    push ecx
    push edi

    mov edi, [FB_ADDRESS]
    mov ecx, [FB_WIDTH]
    imul ecx, [FB_HEIGHT]

    rep stosd

    pop edi
    pop ecx
    pop eax
    ret

; fb_putpixel - Draw a pixel
; Input: EAX = x, EBX = y, ECX = color (0x00RRGGBB)
fb_putpixel:
    push eax
    push ebx
    push edx
    push edi

    ; Bounds check
    cmp eax, 0
    jl .done
    cmp ebx, 0
    jl .done
    cmp eax, [FB_WIDTH]
    jge .done
    cmp ebx, [FB_HEIGHT]
    jge .done

    ; Calculate offset: y * pitch + x * 4 (for 32bpp)
    mov edi, [FB_ADDRESS]
    imul ebx, [FB_PITCH]
    add edi, ebx
    shl eax, 2
    add edi, eax

    ; Write pixel
    mov [edi], ecx

.done:
    pop edi
    pop edx
    pop ebx
    pop eax
    ret

; fb_fillrect - Fill rectangle
; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
fb_fillrect:
    pushad

    ; Bounds check start position
    cmp eax, [FB_WIDTH]
    jge .done
    cmp ebx, [FB_HEIGHT]
    jge .done

    mov edi, [FB_ADDRESS]

    ; Calculate starting offset
    push eax
    imul ebx, [FB_PITCH]
    add edi, ebx
    pop eax
    shl eax, 2
    add edi, eax

.rect_row:
    push edi
    push ecx

    mov eax, esi            ; color
.rect_pixel:
    stosd
    dec ecx
    jnz .rect_pixel

    pop ecx
    pop edi

    ; Next row
    add edi, [FB_PITCH]
    dec edx
    jnz .rect_row

.done:
    popad
    ret
