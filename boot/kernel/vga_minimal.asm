; ════════════════════════════════════════════════════════════════════════════
; VGA MINIMAL - Just basic pixel operations for mode 13h
; ════════════════════════════════════════════════════════════════════════════

GFX_FB      equ 0xA0000
GFX_W       equ 320
GFX_H       equ 200

; gfx_putpixel - Draw pixel
; EAX = x, EBX = y, CL = color
gfx_putpixel:
    push edi
    push edx

    cmp eax, GFX_W
    jae .gfx_pp_skip
    cmp ebx, GFX_H
    jae .gfx_pp_skip

    mov edi, ebx
    shl edi, 8
    mov edx, ebx
    shl edx, 6
    add edi, edx
    add edi, eax
    add edi, GFX_FB

    mov [edi], cl

.gfx_pp_skip:
    pop edx
    pop edi
    ret

; gfx_clear - Clear VGA framebuffer
; AL = color
gfx_clear_fb:
    pushad
    mov edi, GFX_FB
    mov ah, al
    mov ecx, eax
    shl eax, 16
    or eax, ecx
    mov ecx, (GFX_W * GFX_H) / 4
    rep stosd
    popad
    ret

; gfx_demo - Simple test: draw colored bars to VGA memory
gfx_demo:
    pushad
    mov edi, GFX_FB
    xor edx, edx
.gfx_demo_row:
    mov eax, edx
    mov ecx, GFX_W
    rep stosb
    inc edx
    cmp edx, GFX_H
    jb .gfx_demo_row
    popad
    ret
