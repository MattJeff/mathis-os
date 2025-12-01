; ═══════════════════════════════════════════════════════════════════════════
; JARVIS UI - Iron Man Style Interface for MATHIS OS
; ═══════════════════════════════════════════════════════════════════════════
;
; "Good evening, sir. How may I assist you today?"
;
; Features:
; - VGA Graphics Mode 13h (320x200x256)
; - Holographic blue theme
; - Circular HUD elements
; - Animated cursor
; - Modern text rendering
;
; ═══════════════════════════════════════════════════════════════════════════

[bits 32]

; ═══════════════════════════════════════════════════════════════════════════
; CONSTANTS
; ═══════════════════════════════════════════════════════════════════════════

SCREEN_WIDTH        equ 320
SCREEN_HEIGHT       equ 200
VGA_MEMORY          equ 0xA0000

; JARVIS Color Palette
COLOR_BLACK         equ 0
COLOR_DARK_BG       equ 1
COLOR_JARVIS_DARK   equ 2
COLOR_JARVIS_BLUE   equ 3
COLOR_JARVIS_CYAN   equ 4
COLOR_JARVIS_LIGHT  equ 5
COLOR_WHITE         equ 6
COLOR_ORANGE        equ 7
COLOR_RED           equ 8
COLOR_GREEN         equ 9
COLOR_GRAY          equ 10

; VGA Ports
VGA_DAC_WRITE_INDEX equ 0x3C8
VGA_DAC_DATA        equ 0x3C9

; ═══════════════════════════════════════════════════════════════════════════
; DATA
; ═══════════════════════════════════════════════════════════════════════════

section .data

animation_tick:     dd 0
cursor_visible:     db 1
cursor_x:           dd 45
cursor_y:           dd 165

; Text buffer for input
input_buffer:       times 64 db 0
input_pos:          dd 0

; Messages
msg_welcome:        db "JARVIS AI SYSTEM v1.0", 0
msg_ready:          db "System ready. How may I assist?", 0
msg_prompt:         db ">", 0

; ═══════════════════════════════════════════════════════════════════════════
; JARVIS UI INITIALIZATION
; ═══════════════════════════════════════════════════════════════════════════

section .text
global jarvis_init
global jarvis_update
global jarvis_draw_char
global jarvis_clear_console
global jarvis_print

jarvis_init:
    pushad
    
    ; Switch to VGA Mode 13h (320x200, 256 colors)
    mov eax, 0x13
    ; Note: In protected mode, we can't use BIOS int 0x10 directly
    ; We'll write directly to VGA registers
    call set_mode_13h
    
    ; Setup JARVIS color palette
    call setup_palette
    
    ; Draw background gradient
    call draw_background
    
    ; Draw main HUD
    call draw_hud
    
    ; Draw welcome message
    call draw_welcome
    
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; VGA MODE 13H SETUP (Protected Mode Compatible)
; ═══════════════════════════════════════════════════════════════════════════

set_mode_13h:
    pushad
    
    ; Sequencer registers
    mov dx, 0x3C4
    mov al, 0x00
    out dx, al
    inc dx
    mov al, 0x03        ; Reset
    out dx, al
    
    dec dx
    mov al, 0x01
    out dx, al
    inc dx
    mov al, 0x01        ; Clocking mode
    out dx, al
    
    dec dx
    mov al, 0x02
    out dx, al
    inc dx
    mov al, 0x0F        ; Map mask (all planes)
    out dx, al
    
    dec dx
    mov al, 0x03
    out dx, al
    inc dx
    mov al, 0x00        ; Character map
    out dx, al
    
    dec dx
    mov al, 0x04
    out dx, al
    inc dx
    mov al, 0x0E        ; Memory mode
    out dx, al
    
    ; Miscellaneous output
    mov dx, 0x3C2
    mov al, 0x63
    out dx, al
    
    ; CRTC registers for 320x200
    mov dx, 0x3D4
    
    ; Unlock CRTC
    mov al, 0x11
    out dx, al
    inc dx
    mov al, 0x0E
    out dx, al
    dec dx
    
    ; Set CRTC registers
    mov esi, crtc_regs_13h
    mov ecx, 25
.crtc_loop:
    lodsb
    out dx, al
    inc dx
    lodsb
    out dx, al
    dec dx
    loop .crtc_loop
    
    ; Graphics controller
    mov dx, 0x3CE
    mov al, 0x00
    out dx, al
    inc dx
    mov al, 0x00
    out dx, al
    dec dx
    
    mov al, 0x01
    out dx, al
    inc dx
    mov al, 0x00
    out dx, al
    dec dx
    
    mov al, 0x02
    out dx, al
    inc dx
    mov al, 0x00
    out dx, al
    dec dx
    
    mov al, 0x03
    out dx, al
    inc dx
    mov al, 0x00
    out dx, al
    dec dx
    
    mov al, 0x04
    out dx, al
    inc dx
    mov al, 0x00
    out dx, al
    dec dx
    
    mov al, 0x05
    out dx, al
    inc dx
    mov al, 0x40        ; 256 color mode
    out dx, al
    dec dx
    
    mov al, 0x06
    out dx, al
    inc dx
    mov al, 0x05
    out dx, al
    dec dx
    
    mov al, 0x07
    out dx, al
    inc dx
    mov al, 0x0F
    out dx, al
    dec dx
    
    mov al, 0x08
    out dx, al
    inc dx
    mov al, 0xFF
    out dx, al
    
    ; Attribute controller
    mov dx, 0x3DA        ; Reset flip-flop
    in al, dx
    
    mov dx, 0x3C0
    mov ecx, 16
    xor ebx, ebx
.attr_palette:
    mov al, bl
    out dx, al
    mov al, bl
    out dx, al
    inc ebx
    loop .attr_palette
    
    ; Attribute mode control
    mov al, 0x10
    out dx, al
    mov al, 0x41
    out dx, al
    
    mov al, 0x11
    out dx, al
    mov al, 0x00
    out dx, al
    
    mov al, 0x12
    out dx, al
    mov al, 0x0F
    out dx, al
    
    mov al, 0x13
    out dx, al
    mov al, 0x00
    out dx, al
    
    mov al, 0x14
    out dx, al
    mov al, 0x00
    out dx, al
    
    mov al, 0x20        ; Enable display
    out dx, al
    
    popad
    ret

; CRTC register values for mode 13h
crtc_regs_13h:
    db 0x00, 0x5F    ; Horizontal total
    db 0x01, 0x4F    ; Horizontal display end
    db 0x02, 0x50    ; Start horizontal blank
    db 0x03, 0x82    ; End horizontal blank
    db 0x04, 0x54    ; Start horizontal retrace
    db 0x05, 0x80    ; End horizontal retrace
    db 0x06, 0xBF    ; Vertical total
    db 0x07, 0x1F    ; Overflow
    db 0x08, 0x00    ; Preset row scan
    db 0x09, 0x41    ; Max scan line
    db 0x0A, 0x00    ; Cursor start
    db 0x0B, 0x00    ; Cursor end
    db 0x0C, 0x00    ; Start address high
    db 0x0D, 0x00    ; Start address low
    db 0x0E, 0x00    ; Cursor location high
    db 0x0F, 0x00    ; Cursor location low
    db 0x10, 0x9C    ; Vertical retrace start
    db 0x11, 0x0E    ; Vertical retrace end
    db 0x12, 0x8F    ; Vertical display end
    db 0x13, 0x28    ; Offset
    db 0x14, 0x40    ; Underline location
    db 0x15, 0x96    ; Start vertical blank
    db 0x16, 0xB9    ; End vertical blank
    db 0x17, 0xA3    ; Mode control
    db 0x18, 0xFF    ; Line compare

; ═══════════════════════════════════════════════════════════════════════════
; JARVIS COLOR PALETTE
; ═══════════════════════════════════════════════════════════════════════════

setup_palette:
    pushad
    
    mov dx, VGA_DAC_WRITE_INDEX
    xor al, al
    out dx, al
    
    mov dx, VGA_DAC_DATA
    
    ; 0: Black
    xor al, al
    out dx, al
    out dx, al
    out dx, al
    
    ; 1: Dark background (very dark blue)
    mov al, 1
    out dx, al
    mov al, 2
    out dx, al
    mov al, 8
    out dx, al
    
    ; 2: JARVIS Dark blue
    mov al, 3
    out dx, al
    mov al, 8
    out dx, al
    mov al, 18
    out dx, al
    
    ; 3: JARVIS Blue (main)
    mov al, 8
    out dx, al
    mov al, 20
    out dx, al
    mov al, 38
    out dx, al
    
    ; 4: JARVIS Cyan (highlight)
    mov al, 15
    out dx, al
    mov al, 40
    out dx, al
    mov al, 55
    out dx, al
    
    ; 5: JARVIS Light (bright accent)
    mov al, 30
    out dx, al
    mov al, 55
    out dx, al
    mov al, 63
    out dx, al
    
    ; 6: White
    mov al, 63
    out dx, al
    mov al, 63
    out dx, al
    mov al, 63
    out dx, al
    
    ; 7: Orange (Iron Man accent)
    mov al, 63
    out dx, al
    mov al, 30
    out dx, al
    mov al, 5
    out dx, al
    
    ; 8: Red (warnings)
    mov al, 55
    out dx, al
    mov al, 8
    out dx, al
    mov al, 8
    out dx, al
    
    ; 9: Green (success)
    mov al, 10
    out dx, al
    mov al, 55
    out dx, al
    mov al, 20
    out dx, al
    
    ; 10: Gray
    mov al, 25
    out dx, al
    mov al, 25
    out dx, al
    mov al, 28
    out dx, al
    
    ; 11-63: Gradient blues for effects
    mov ecx, 53
    mov bl, 10
.gradient:
    mov al, bl
    shr al, 2
    out dx, al          ; R
    mov al, bl
    shr al, 1
    out dx, al          ; G
    mov al, bl
    out dx, al          ; B
    inc bl
    loop .gradient
    
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; DRAWING PRIMITIVES
; ═══════════════════════════════════════════════════════════════════════════

; Put pixel at (EBX=x, ECX=y) with color AL
put_pixel:
    pushad
    
    ; Bounds check
    cmp ebx, SCREEN_WIDTH
    jae .done
    cmp ecx, SCREEN_HEIGHT
    jae .done
    
    ; Calculate offset: y * 320 + x
    push eax
    mov eax, ecx
    imul eax, SCREEN_WIDTH
    add eax, ebx
    mov edi, eax
    add edi, VGA_MEMORY
    pop eax
    
    mov [edi], al
    
.done:
    popad
    ret

; Draw horizontal line: EBX=x, ECX=y, EDX=length, AL=color
draw_hline:
    pushad
    
    cmp ecx, SCREEN_HEIGHT
    jae .done
    
    push eax
    mov eax, ecx
    imul eax, SCREEN_WIDTH
    add eax, ebx
    mov edi, eax
    add edi, VGA_MEMORY
    pop eax
    
    mov ecx, edx
    rep stosb
    
.done:
    popad
    ret

; Draw vertical line: EBX=x, ECX=y, EDX=length, AL=color
draw_vline:
    pushad
    
    cmp ebx, SCREEN_WIDTH
    jae .done
    
    push eax
    mov eax, ecx
    imul eax, SCREEN_WIDTH
    add eax, ebx
    mov edi, eax
    add edi, VGA_MEMORY
    pop eax
    
.vloop:
    mov [edi], al
    add edi, SCREEN_WIDTH
    dec edx
    jnz .vloop
    
.done:
    popad
    ret

; Draw filled rectangle: EBX=x, ECX=y, ESI=width, EDI_param=height, AL=color
; Note: height passed via stack or separate register
draw_filled_rect:
    pushad
    
    mov ebp, [esp + 36]     ; Height from stack
    
.rect_loop:
    push ecx
    mov edx, esi            ; Width
    call draw_hline
    pop ecx
    inc ecx
    dec ebp
    jnz .rect_loop
    
    popad
    ret

; Draw circle outline using Bresenham: EBX=cx, ECX=cy, EDX=radius, AL=color
draw_circle:
    pushad
    
    push eax                ; Save color
    
    mov esi, edx            ; x = radius
    xor edi, edi            ; y = 0
    mov ebp, 1
    sub ebp, edx            ; d = 1 - radius
    
.circle_loop:
    cmp edi, esi
    jg .circle_done
    
    ; Get color
    mov eax, [esp]
    
    ; Draw 8 symmetric points
    ; (cx+x, cy+y)
    push ebx
    push ecx
    add ebx, esi
    add ecx, edi
    call put_pixel
    pop ecx
    pop ebx
    
    ; (cx-x, cy+y)
    push ebx
    push ecx
    sub ebx, esi
    add ecx, edi
    call put_pixel
    pop ecx
    pop ebx
    
    ; (cx+x, cy-y)
    push ebx
    push ecx
    add ebx, esi
    sub ecx, edi
    call put_pixel
    pop ecx
    pop ebx
    
    ; (cx-x, cy-y)
    push ebx
    push ecx
    sub ebx, esi
    sub ecx, edi
    call put_pixel
    pop ecx
    pop ebx
    
    ; (cx+y, cy+x)
    push ebx
    push ecx
    add ebx, edi
    add ecx, esi
    call put_pixel
    pop ecx
    pop ebx
    
    ; (cx-y, cy+x)
    push ebx
    push ecx
    sub ebx, edi
    add ecx, esi
    call put_pixel
    pop ecx
    pop ebx
    
    ; (cx+y, cy-x)
    push ebx
    push ecx
    add ebx, edi
    sub ecx, esi
    call put_pixel
    pop ecx
    pop ebx
    
    ; (cx-y, cy-x)
    push ebx
    push ecx
    sub ebx, edi
    sub ecx, esi
    call put_pixel
    pop ecx
    pop ebx
    
    inc edi                 ; y++
    
    cmp ebp, 0
    jg .dec_x
    
    ; d += 2*y + 1
    mov eax, edi
    shl eax, 1
    inc eax
    add ebp, eax
    jmp .circle_loop
    
.dec_x:
    dec esi                 ; x--
    ; d += 2*(y-x) + 1
    mov eax, edi
    sub eax, esi
    shl eax, 1
    inc eax
    add ebp, eax
    jmp .circle_loop
    
.circle_done:
    pop eax
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; HUD DRAWING
; ═══════════════════════════════════════════════════════════════════════════

draw_background:
    pushad
    
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_HEIGHT
    
.row:
    push ecx
    
    ; Calculate gradient color based on row
    mov eax, SCREEN_HEIGHT
    sub eax, ecx
    shr eax, 4              ; Divide by 16 for gradient steps
    add al, COLOR_DARK_BG
    cmp al, 10
    jbe .color_ok
    mov al, 10
.color_ok:
    
    mov ecx, SCREEN_WIDTH
    rep stosb
    
    pop ecx
    loop .row
    
    popad
    ret

draw_hud:
    pushad
    
    ; === Main circular HUD in center ===
    
    ; Outer glow circle
    mov ebx, 160            ; Center X
    mov ecx, 85             ; Center Y
    mov edx, 70             ; Radius
    mov al, COLOR_JARVIS_DARK
    call draw_circle
    
    ; Outer circle
    mov edx, 65
    mov al, COLOR_JARVIS_CYAN
    call draw_circle
    
    ; Middle circle
    mov edx, 50
    mov al, COLOR_JARVIS_BLUE
    call draw_circle
    
    ; Inner circle
    mov edx, 35
    mov al, COLOR_JARVIS_CYAN
    call draw_circle
    
    ; Core circle
    mov edx, 20
    mov al, COLOR_JARVIS_LIGHT
    call draw_circle
    
    ; Center dot
    mov edx, 5
    mov al, COLOR_WHITE
    call draw_circle
    
    ; === Corner brackets (HUD style) ===
    
    ; Top-left
    mov ebx, 10
    mov ecx, 10
    mov edx, 25
    mov al, COLOR_JARVIS_CYAN
    call draw_hline
    mov edx, 15
    call draw_vline
    
    ; Top-right
    mov ebx, 285
    mov ecx, 10
    mov edx, 25
    mov al, COLOR_JARVIS_CYAN
    call draw_hline
    mov ebx, 309
    mov edx, 15
    call draw_vline
    
    ; Bottom-left
    mov ebx, 10
    mov ecx, 175
    mov edx, 15
    mov al, COLOR_JARVIS_CYAN
    call draw_vline
    mov ecx, 189
    mov edx, 25
    call draw_hline
    
    ; Bottom-right
    mov ebx, 285
    mov ecx, 189
    mov edx, 25
    mov al, COLOR_JARVIS_CYAN
    call draw_hline
    mov ebx, 309
    mov ecx, 175
    mov edx, 15
    call draw_vline
    
    ; === Side status bars ===
    
    ; Left bar background
    mov ebx, 15
    mov ecx, 35
    mov edx, 80
    mov al, COLOR_GRAY
    call draw_vline
    mov ebx, 16
    call draw_vline
    
    ; Left bar fill (animated level)
    mov ebx, 15
    mov ecx, 55
    mov edx, 60
    mov al, COLOR_JARVIS_CYAN
    call draw_vline
    mov ebx, 16
    call draw_vline
    
    ; Right bar background
    mov ebx, 303
    mov ecx, 35
    mov edx, 80
    mov al, COLOR_GRAY
    call draw_vline
    mov ebx, 304
    call draw_vline
    
    ; Right bar fill
    mov ebx, 303
    mov ecx, 45
    mov edx, 70
    mov al, COLOR_ORANGE
    call draw_vline
    mov ebx, 304
    call draw_vline
    
    ; === Console area at bottom ===
    
    ; Console border top
    mov ebx, 25
    mov ecx, 145
    mov edx, 270
    mov al, COLOR_JARVIS_BLUE
    call draw_hline
    
    ; Console border bottom
    mov ecx, 192
    call draw_hline
    
    ; Console border left
    mov ebx, 25
    mov ecx, 145
    mov edx, 48
    call draw_vline
    
    ; Console border right
    mov ebx, 294
    call draw_vline
    
    ; Console background (darker)
    mov edi, VGA_MEMORY
    add edi, 146 * SCREEN_WIDTH + 26
    mov ecx, 45
.console_bg:
    push ecx
    mov ecx, 268
    mov al, COLOR_DARK_BG
    rep stosb
    add edi, SCREEN_WIDTH - 268
    pop ecx
    loop .console_bg
    
    popad
    ret

draw_welcome:
    pushad
    
    ; Draw "JARVIS" title in the center circle
    ; Simple approach: draw text at center
    
    ; Position for JARVIS text (center of circles)
    mov ebx, 140
    mov ecx, 82
    mov esi, msg_jarvis_title
    mov al, COLOR_WHITE
    call draw_text
    
    ; Draw subtitle
    mov ebx, 125
    mov ecx, 95
    mov esi, msg_jarvis_sub
    mov al, COLOR_JARVIS_CYAN
    call draw_text
    
    ; Draw welcome in console
    mov ebx, 30
    mov ecx, 150
    mov esi, msg_welcome
    mov al, COLOR_JARVIS_LIGHT
    call draw_text
    
    ; Draw ready message
    mov ebx, 30
    mov ecx, 160
    mov esi, msg_ready
    mov al, COLOR_JARVIS_CYAN
    call draw_text
    
    ; Draw prompt
    mov ebx, 30
    mov ecx, 175
    mov esi, msg_prompt
    mov al, COLOR_JARVIS_LIGHT
    call draw_text
    
    popad
    ret

msg_jarvis_title: db "JARVIS", 0
msg_jarvis_sub:   db "A.I. SYSTEM", 0

; ═══════════════════════════════════════════════════════════════════════════
; TEXT RENDERING (8x8 font)
; ═══════════════════════════════════════════════════════════════════════════

; Draw text string at EBX=x, ECX=y, ESI=string, AL=color
draw_text:
    pushad
    mov ah, al              ; Save color in AH
    
.text_loop:
    lodsb
    test al, al
    jz .text_done
    
    push eax
    push ebx
    push ecx
    
    ; Draw character
    mov al, ah              ; Restore color
    call draw_char
    
    pop ecx
    pop ebx
    pop eax
    
    add ebx, 6              ; Character width + spacing
    jmp .text_loop
    
.text_done:
    popad
    ret

; Draw single character at EBX=x, ECX=y, AL=color, character in [esp+?]
; Simplified 5x7 font
draw_char:
    pushad
    
    mov dl, al              ; Save color
    mov al, [esp + 32]      ; Get character from stack (after pushad)
    
    ; Calculate font data offset
    sub al, 32              ; ASCII offset
    movzx eax, al
    imul eax, 5             ; 5 bytes per character
    add eax, font_5x7
    mov esi, eax
    
    ; Draw 5 columns
    mov dh, 5               ; Column counter
.char_col:
    lodsb                   ; Get column bitmap
    push ebx
    
    mov ch, 7               ; 7 rows
.char_row:
    test al, 1
    jz .skip_pixel
    
    push eax
    mov al, dl              ; Color
    call put_pixel
    pop eax
    
.skip_pixel:
    shr al, 1
    inc ecx
    dec ch
    jnz .char_row
    
    pop ebx
    sub ecx, 7              ; Reset Y
    inc ebx                 ; Next column
    dec dh
    jnz .char_col
    
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; 5x7 FONT DATA (subset)
; ═══════════════════════════════════════════════════════════════════════════

font_5x7:
    ; Space (32)
    db 0x00, 0x00, 0x00, 0x00, 0x00
    ; ! (33)
    db 0x00, 0x00, 0x5F, 0x00, 0x00
    ; " (34)
    db 0x00, 0x07, 0x00, 0x07, 0x00
    ; # (35)
    db 0x14, 0x7F, 0x14, 0x7F, 0x14
    ; $ (36)
    db 0x24, 0x2A, 0x7F, 0x2A, 0x12
    ; % (37)
    db 0x23, 0x13, 0x08, 0x64, 0x62
    ; & (38)
    db 0x36, 0x49, 0x55, 0x22, 0x50
    ; ' (39)
    db 0x00, 0x05, 0x03, 0x00, 0x00
    ; ( (40)
    db 0x00, 0x1C, 0x22, 0x41, 0x00
    ; ) (41)
    db 0x00, 0x41, 0x22, 0x1C, 0x00
    ; * (42)
    db 0x08, 0x2A, 0x1C, 0x2A, 0x08
    ; + (43)
    db 0x08, 0x08, 0x3E, 0x08, 0x08
    ; , (44)
    db 0x00, 0x50, 0x30, 0x00, 0x00
    ; - (45)
    db 0x08, 0x08, 0x08, 0x08, 0x08
    ; . (46)
    db 0x00, 0x60, 0x60, 0x00, 0x00
    ; / (47)
    db 0x20, 0x10, 0x08, 0x04, 0x02
    ; 0 (48)
    db 0x3E, 0x51, 0x49, 0x45, 0x3E
    ; 1 (49)
    db 0x00, 0x42, 0x7F, 0x40, 0x00
    ; 2 (50)
    db 0x42, 0x61, 0x51, 0x49, 0x46
    ; 3 (51)
    db 0x21, 0x41, 0x45, 0x4B, 0x31
    ; 4 (52)
    db 0x18, 0x14, 0x12, 0x7F, 0x10
    ; 5 (53)
    db 0x27, 0x45, 0x45, 0x45, 0x39
    ; 6 (54)
    db 0x3C, 0x4A, 0x49, 0x49, 0x30
    ; 7 (55)
    db 0x01, 0x71, 0x09, 0x05, 0x03
    ; 8 (56)
    db 0x36, 0x49, 0x49, 0x49, 0x36
    ; 9 (57)
    db 0x06, 0x49, 0x49, 0x29, 0x1E
    ; : (58)
    db 0x00, 0x36, 0x36, 0x00, 0x00
    ; ; (59)
    db 0x00, 0x56, 0x36, 0x00, 0x00
    ; < (60)
    db 0x00, 0x08, 0x14, 0x22, 0x41
    ; = (61)
    db 0x14, 0x14, 0x14, 0x14, 0x14
    ; > (62)
    db 0x41, 0x22, 0x14, 0x08, 0x00
    ; ? (63)
    db 0x02, 0x01, 0x51, 0x09, 0x06
    ; @ (64)
    db 0x32, 0x49, 0x79, 0x41, 0x3E
    ; A (65)
    db 0x7E, 0x11, 0x11, 0x11, 0x7E
    ; B (66)
    db 0x7F, 0x49, 0x49, 0x49, 0x36
    ; C (67)
    db 0x3E, 0x41, 0x41, 0x41, 0x22
    ; D (68)
    db 0x7F, 0x41, 0x41, 0x22, 0x1C
    ; E (69)
    db 0x7F, 0x49, 0x49, 0x49, 0x41
    ; F (70)
    db 0x7F, 0x09, 0x09, 0x01, 0x01
    ; G (71)
    db 0x3E, 0x41, 0x41, 0x51, 0x32
    ; H (72)
    db 0x7F, 0x08, 0x08, 0x08, 0x7F
    ; I (73)
    db 0x00, 0x41, 0x7F, 0x41, 0x00
    ; J (74)
    db 0x20, 0x40, 0x41, 0x3F, 0x01
    ; K (75)
    db 0x7F, 0x08, 0x14, 0x22, 0x41
    ; L (76)
    db 0x7F, 0x40, 0x40, 0x40, 0x40
    ; M (77)
    db 0x7F, 0x02, 0x04, 0x02, 0x7F
    ; N (78)
    db 0x7F, 0x04, 0x08, 0x10, 0x7F
    ; O (79)
    db 0x3E, 0x41, 0x41, 0x41, 0x3E
    ; P (80)
    db 0x7F, 0x09, 0x09, 0x09, 0x06
    ; Q (81)
    db 0x3E, 0x41, 0x51, 0x21, 0x5E
    ; R (82)
    db 0x7F, 0x09, 0x19, 0x29, 0x46
    ; S (83)
    db 0x46, 0x49, 0x49, 0x49, 0x31
    ; T (84)
    db 0x01, 0x01, 0x7F, 0x01, 0x01
    ; U (85)
    db 0x3F, 0x40, 0x40, 0x40, 0x3F
    ; V (86)
    db 0x1F, 0x20, 0x40, 0x20, 0x1F
    ; W (87)
    db 0x7F, 0x20, 0x18, 0x20, 0x7F
    ; X (88)
    db 0x63, 0x14, 0x08, 0x14, 0x63
    ; Y (89)
    db 0x03, 0x04, 0x78, 0x04, 0x03
    ; Z (90)
    db 0x61, 0x51, 0x49, 0x45, 0x43
    ; Lowercase letters (same as uppercase for simplicity)
    ; [ (91)
    db 0x00, 0x00, 0x7F, 0x41, 0x41
    ; \ (92)
    db 0x02, 0x04, 0x08, 0x10, 0x20
    ; ] (93)
    db 0x41, 0x41, 0x7F, 0x00, 0x00
    ; ^ (94)
    db 0x04, 0x02, 0x01, 0x02, 0x04
    ; _ (95)
    db 0x40, 0x40, 0x40, 0x40, 0x40
    ; ` (96)
    db 0x00, 0x01, 0x02, 0x04, 0x00
    ; a-z (97-122) - use uppercase
    db 0x7E, 0x11, 0x11, 0x11, 0x7E  ; a
    db 0x7F, 0x49, 0x49, 0x49, 0x36  ; b
    db 0x3E, 0x41, 0x41, 0x41, 0x22  ; c
    db 0x7F, 0x41, 0x41, 0x22, 0x1C  ; d
    db 0x7F, 0x49, 0x49, 0x49, 0x41  ; e
    db 0x7F, 0x09, 0x09, 0x01, 0x01  ; f
    db 0x3E, 0x41, 0x41, 0x51, 0x32  ; g
    db 0x7F, 0x08, 0x08, 0x08, 0x7F  ; h
    db 0x00, 0x41, 0x7F, 0x41, 0x00  ; i
    db 0x20, 0x40, 0x41, 0x3F, 0x01  ; j
    db 0x7F, 0x08, 0x14, 0x22, 0x41  ; k
    db 0x7F, 0x40, 0x40, 0x40, 0x40  ; l
    db 0x7F, 0x02, 0x04, 0x02, 0x7F  ; m
    db 0x7F, 0x04, 0x08, 0x10, 0x7F  ; n
    db 0x3E, 0x41, 0x41, 0x41, 0x3E  ; o
    db 0x7F, 0x09, 0x09, 0x09, 0x06  ; p
    db 0x3E, 0x41, 0x51, 0x21, 0x5E  ; q
    db 0x7F, 0x09, 0x19, 0x29, 0x46  ; r
    db 0x46, 0x49, 0x49, 0x49, 0x31  ; s
    db 0x01, 0x01, 0x7F, 0x01, 0x01  ; t
    db 0x3F, 0x40, 0x40, 0x40, 0x3F  ; u
    db 0x1F, 0x20, 0x40, 0x20, 0x1F  ; v
    db 0x7F, 0x20, 0x18, 0x20, 0x7F  ; w
    db 0x63, 0x14, 0x08, 0x14, 0x63  ; x
    db 0x03, 0x04, 0x78, 0x04, 0x03  ; y
    db 0x61, 0x51, 0x49, 0x45, 0x43  ; z

; ═══════════════════════════════════════════════════════════════════════════
; ANIMATION UPDATE (call from main loop)
; ═══════════════════════════════════════════════════════════════════════════

jarvis_update:
    pushad
    
    ; Increment tick
    inc dword [animation_tick]
    
    ; Cursor blink (every 16 ticks)
    mov eax, [animation_tick]
    and eax, 15
    jnz .cursor_on
    
    ; Toggle cursor
    xor byte [cursor_visible], 1
    call draw_cursor
    
.cursor_on:
    
    popad
    ret

draw_cursor:
    pushad
    
    mov ebx, [cursor_x]
    mov ecx, [cursor_y]
    
    cmp byte [cursor_visible], 0
    je .cursor_off
    
    ; Draw cursor block
    mov al, COLOR_JARVIS_LIGHT
    jmp .draw_it
    
.cursor_off:
    mov al, COLOR_DARK_BG
    
.draw_it:
    ; Draw 5x7 cursor block
    mov edx, 5
.cursor_row:
    push ecx
    push edx
    mov edx, 5
    call draw_hline
    pop edx
    pop ecx
    inc ecx
    dec edx
    jnz .cursor_row
    
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; PUBLIC API
; ═══════════════════════════════════════════════════════════════════════════

; Print string to console
; ESI = string pointer
jarvis_print:
    pushad
    
    mov ebx, 30
    mov ecx, [cursor_y]
    mov al, COLOR_JARVIS_CYAN
    call draw_text
    
    ; Move cursor down
    add dword [cursor_y], 10
    cmp dword [cursor_y], 185
    jb .no_scroll
    mov dword [cursor_y], 150
    call jarvis_clear_console
.no_scroll:
    
    popad
    ret

; Clear console area
jarvis_clear_console:
    pushad
    
    mov edi, VGA_MEMORY
    add edi, 146 * SCREEN_WIDTH + 26
    mov ecx, 45
.clear_row:
    push ecx
    mov ecx, 268
    mov al, COLOR_DARK_BG
    rep stosb
    add edi, SCREEN_WIDTH - 268
    pop ecx
    loop .clear_row
    
    mov dword [cursor_y], 150
    mov dword [cursor_x], 45
    
    ; Redraw prompt
    mov ebx, 30
    mov ecx, 175
    mov esi, msg_prompt
    mov al, COLOR_JARVIS_LIGHT
    call draw_text
    
    popad
    ret

; Draw character at cursor and advance
; AL = character
jarvis_draw_char:
    pushad
    
    push eax
    mov ebx, [cursor_x]
    mov ecx, [cursor_y]
    mov al, COLOR_JARVIS_LIGHT
    call draw_char
    add dword [cursor_x], 6
    pop eax
    
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; END OF JARVIS UI
; ═══════════════════════════════════════════════════════════════════════════
