; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL v3.0 - JARVIS GRAPHICAL INTERFACE
; ════════════════════════════════════════════════════════════════════════════
;
; "Good evening, sir. JARVIS at your service."
;
; Features:
; - VGA Mode 13h (320x200x256 colors)
; - Holographic JARVIS interface
; - Animated HUD elements
; - Full command system
;
; Assemble with: nasm -f bin kernel_jarvis.asm -o kernel_jarvis.bin
; ════════════════════════════════════════════════════════════════════════════

[BITS 32]
[ORG 0x10000]

; ════════════════════════════════════════════════════════════════════════════
; CONSTANTS
; ════════════════════════════════════════════════════════════════════════════

SCREEN_WIDTH        equ 320
SCREEN_HEIGHT       equ 200
VGA_MEMORY          equ 0xA0000

; JARVIS Colors
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

; Console area
CONSOLE_X           equ 30
CONSOLE_Y           equ 148
CONSOLE_WIDTH       equ 260
CONSOLE_HEIGHT      equ 40
CONSOLE_LINES       equ 5

; ════════════════════════════════════════════════════════════════════════════
; ENTRY POINT
; ════════════════════════════════════════════════════════════════════════════

kernel_entry:
    ; Setup stack
    mov esp, 0x2FFFF
    
    ; Initialize PIC for keyboard
    call init_pic
    
    ; Setup and load IDT
    call setup_idt
    lidt [idt_ptr]
    
    ; VGA Mode 13h is already set by bootloader
    ; Just setup the color palette
    call setup_palette
    
    ; Draw JARVIS interface
    call draw_jarvis_ui
    
    ; Enable interrupts
    sti
    
    ; Main loop with animation
.main_loop:
    ; Update animation
    call update_animation
    
    ; Small delay
    mov ecx, 100000
.delay:
    loop .delay
    
    hlt
    jmp .main_loop

; ════════════════════════════════════════════════════════════════════════════
; PIC INITIALIZATION
; ════════════════════════════════════════════════════════════════════════════

init_pic:
    mov al, 0x11
    out 0x20, al
    out 0xA0, al
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al
    mov al, 0x01
    out 0x21, al
    out 0xA1, al
    mov al, 0xFD        ; Enable keyboard only
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al
    ret

; ════════════════════════════════════════════════════════════════════════════
; VGA MODE 13H (320x200x256)
; ════════════════════════════════════════════════════════════════════════════

set_mode_13h:
    pushad
    
    ; Use BIOS to set mode (via V86 or direct)
    ; For protected mode, we set registers directly
    
    ; Sequencer
    mov dx, 0x3C4
    mov ax, 0x0100      ; Reset
    out dx, ax
    mov ax, 0x0101      ; Clocking
    out dx, ax
    mov ax, 0x0F02      ; Map mask
    out dx, ax
    mov ax, 0x0003      ; Char map
    out dx, ax
    mov ax, 0x0E04      ; Memory mode
    out dx, ax
    mov ax, 0x0300      ; Reset done
    out dx, ax
    
    ; Misc output
    mov dx, 0x3C2
    mov al, 0x63
    out dx, al
    
    ; CRTC unlock
    mov dx, 0x3D4
    mov ax, 0x0E11
    out dx, ax
    
    ; CRTC registers
    mov ax, 0x5F00
    out dx, ax
    mov ax, 0x4F01
    out dx, ax
    mov ax, 0x5002
    out dx, ax
    mov ax, 0x8203
    out dx, ax
    mov ax, 0x5404
    out dx, ax
    mov ax, 0x8005
    out dx, ax
    mov ax, 0xBF06
    out dx, ax
    mov ax, 0x1F07
    out dx, ax
    mov ax, 0x0008
    out dx, ax
    mov ax, 0x4109
    out dx, ax
    mov ax, 0x000A
    out dx, ax
    mov ax, 0x000B
    out dx, ax
    mov ax, 0x000C
    out dx, ax
    mov ax, 0x000D
    out dx, ax
    mov ax, 0x000E
    out dx, ax
    mov ax, 0x000F
    out dx, ax
    mov ax, 0x9C10
    out dx, ax
    mov ax, 0x8E11
    out dx, ax
    mov ax, 0x8F12
    out dx, ax
    mov ax, 0x2813
    out dx, ax
    mov ax, 0x4014
    out dx, ax
    mov ax, 0x9615
    out dx, ax
    mov ax, 0xB916
    out dx, ax
    mov ax, 0xA317
    out dx, ax
    mov ax, 0xFF18
    out dx, ax
    
    ; Graphics controller
    mov dx, 0x3CE
    mov ax, 0x0000
    out dx, ax
    mov ax, 0x0001
    out dx, ax
    mov ax, 0x0002
    out dx, ax
    mov ax, 0x0003
    out dx, ax
    mov ax, 0x0004
    out dx, ax
    mov ax, 0x4005      ; 256 color
    out dx, ax
    mov ax, 0x0506
    out dx, ax
    mov ax, 0x0F07
    out dx, ax
    mov ax, 0xFF08
    out dx, ax
    
    ; Attribute controller
    mov dx, 0x3DA
    in al, dx           ; Reset flip-flop
    
    mov dx, 0x3C0
    xor ecx, ecx
.attr_loop:
    mov al, cl
    out dx, al
    out dx, al
    inc cl
    cmp cl, 16
    jb .attr_loop
    
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
    
    mov al, 0x20        ; Enable
    out dx, al
    
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; JARVIS COLOR PALETTE
; ════════════════════════════════════════════════════════════════════════════

setup_palette:
    pushad
    
    ; Set palette index to 0
    mov dx, 0x3C8
    xor al, al
    out dx, al
    
    mov dx, 0x3C9
    
    ; Color 0: Pure Black
    mov al, 0
    out dx, al
    out dx, al
    out dx, al
    
    ; Color 1: Dark Blue Background
    mov al, 0
    out dx, al
    mov al, 2
    out dx, al
    mov al, 8
    out dx, al
    
    ; Color 2: JARVIS Dark Blue
    mov al, 2
    out dx, al
    mov al, 8
    out dx, al
    mov al, 18
    out dx, al
    
    ; Color 3: JARVIS Blue (main)
    mov al, 8
    out dx, al
    mov al, 20
    out dx, al
    mov al, 40
    out dx, al
    
    ; Color 4: JARVIS Cyan (highlight)
    mov al, 15
    out dx, al
    mov al, 45
    out dx, al
    mov al, 63
    out dx, al
    
    ; Color 5: JARVIS Light Cyan
    mov al, 30
    out dx, al
    mov al, 55
    out dx, al
    mov al, 63
    out dx, al
    
    ; Color 6: White
    mov al, 63
    out dx, al
    mov al, 63
    out dx, al
    mov al, 63
    out dx, al
    
    ; Color 7: Orange (Iron Man accent)
    mov al, 63
    out dx, al
    mov al, 30
    out dx, al
    mov al, 5
    out dx, al
    
    ; Color 8: Red (warnings)
    mov al, 55
    out dx, al
    mov al, 8
    out dx, al
    mov al, 8
    out dx, al
    
    ; Color 9: Green (success)
    mov al, 10
    out dx, al
    mov al, 55
    out dx, al
    mov al, 20
    out dx, al
    
    ; Color 10: Gray
    mov al, 20
    out dx, al
    mov al, 20
    out dx, al
    mov al, 25
    out dx, al
    
    ; Fill rest (11-255) with dark blue
    mov ecx, 245
.fill_dark:
    mov al, 0
    out dx, al
    mov al, 2
    out dx, al
    mov al, 8
    out dx, al
    loop .fill_dark
    
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; DRAWING PRIMITIVES
; ════════════════════════════════════════════════════════════════════════════

; Put pixel: EBX=x, ECX=y, AL=color
put_pixel:
    pushad
    cmp ebx, SCREEN_WIDTH
    jae .done
    cmp ecx, SCREEN_HEIGHT
    jae .done
    
    push eax
    mov eax, ecx
    imul eax, SCREEN_WIDTH
    add eax, ebx
    add eax, VGA_MEMORY
    mov edi, eax
    pop eax
    mov [edi], al
.done:
    popad
    ret

; Horizontal line: EBX=x, ECX=y, EDX=length, AL=color
draw_hline:
    pushad
    cmp ecx, SCREEN_HEIGHT
    jae .done
    
    push eax
    mov eax, ecx
    imul eax, SCREEN_WIDTH
    add eax, ebx
    add eax, VGA_MEMORY
    mov edi, eax
    pop eax
    mov ecx, edx
    rep stosb
.done:
    popad
    ret

; Vertical line: EBX=x, ECX=y, EDX=length, AL=color
draw_vline:
    pushad
    cmp ebx, SCREEN_WIDTH
    jae .done
    
    push eax
    mov eax, ecx
    imul eax, SCREEN_WIDTH
    add eax, ebx
    add eax, VGA_MEMORY
    mov edi, eax
    pop eax
.vloop:
    mov [edi], al
    add edi, SCREEN_WIDTH
    dec edx
    jnz .vloop
.done:
    popad
    ret

; Circle: EBX=cx, ECX=cy, EDX=radius, AL=color
draw_circle:
    pushad
    push eax
    mov esi, edx            ; x = radius
    xor edi, edi            ; y = 0
    mov ebp, 1
    sub ebp, edx            ; d = 1 - r
    
.loop:
    cmp edi, esi
    jg .done_circle
    
    mov eax, [esp]
    
    ; 8 points
    push ebx
    push ecx
    add ebx, esi
    add ecx, edi
    call put_pixel
    pop ecx
    pop ebx
    
    push ebx
    push ecx
    sub ebx, esi
    add ecx, edi
    call put_pixel
    pop ecx
    pop ebx
    
    push ebx
    push ecx
    add ebx, esi
    sub ecx, edi
    call put_pixel
    pop ecx
    pop ebx
    
    push ebx
    push ecx
    sub ebx, esi
    sub ecx, edi
    call put_pixel
    pop ecx
    pop ebx
    
    push ebx
    push ecx
    add ebx, edi
    add ecx, esi
    call put_pixel
    pop ecx
    pop ebx
    
    push ebx
    push ecx
    sub ebx, edi
    add ecx, esi
    call put_pixel
    pop ecx
    pop ebx
    
    push ebx
    push ecx
    add ebx, edi
    sub ecx, esi
    call put_pixel
    pop ecx
    pop ebx
    
    push ebx
    push ecx
    sub ebx, edi
    sub ecx, esi
    call put_pixel
    pop ecx
    pop ebx
    
    inc edi
    cmp ebp, 0
    jg .dec_x
    mov eax, edi
    shl eax, 1
    inc eax
    add ebp, eax
    jmp .loop
.dec_x:
    dec esi
    mov eax, edi
    sub eax, esi
    shl eax, 1
    inc eax
    add ebp, eax
    jmp .loop
    
.done_circle:
    pop eax
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; JARVIS UI DRAWING
; ════════════════════════════════════════════════════════════════════════════

draw_jarvis_ui:
    pushad
    
    ; === Background - solid dark blue ===
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT
    mov al, COLOR_DARK_BG       ; Color 1 = dark blue
    rep stosb
    
    ; === Main circles (HUD) ===
    mov ebx, 160
    mov ecx, 75
    
    ; Outer glow
    mov edx, 65
    mov al, COLOR_JARVIS_DARK
    call draw_circle
    
    ; Outer
    mov edx, 60
    mov al, COLOR_JARVIS_CYAN
    call draw_circle
    
    ; Middle
    mov edx, 45
    mov al, COLOR_JARVIS_BLUE
    call draw_circle
    
    ; Inner
    mov edx, 30
    mov al, COLOR_JARVIS_CYAN
    call draw_circle
    
    ; Core
    mov edx, 15
    mov al, COLOR_JARVIS_LIGHT
    call draw_circle
    
    ; Center
    mov edx, 5
    mov al, COLOR_WHITE
    call draw_circle
    
    ; === Corner brackets ===
    
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
    mov edx, 25
    call draw_hline
    mov ebx, 309
    mov edx, 15
    call draw_vline
    
    ; Bottom-left
    mov ebx, 10
    mov ecx, 175
    mov edx, 15
    call draw_vline
    mov ecx, 189
    mov edx, 25
    call draw_hline
    
    ; Bottom-right
    mov ebx, 285
    call draw_hline
    mov ebx, 309
    mov ecx, 175
    mov edx, 15
    call draw_vline
    
    ; === Status bars ===
    
    ; Left bar
    mov ebx, 15
    mov ecx, 35
    mov edx, 70
    mov al, COLOR_JARVIS_DARK
    call draw_vline
    mov ebx, 16
    call draw_vline
    
    mov ebx, 15
    mov ecx, 50
    mov edx, 55
    mov al, COLOR_JARVIS_CYAN
    call draw_vline
    mov ebx, 16
    call draw_vline
    
    ; Right bar
    mov ebx, 303
    mov ecx, 35
    mov edx, 70
    mov al, COLOR_JARVIS_DARK
    call draw_vline
    mov ebx, 304
    call draw_vline
    
    mov ebx, 303
    mov ecx, 40
    mov edx, 65
    mov al, COLOR_ORANGE
    call draw_vline
    mov ebx, 304
    call draw_vline
    
    ; === Console area ===
    
    ; Border
    mov ebx, 25
    mov ecx, 140
    mov edx, 270
    mov al, COLOR_JARVIS_BLUE
    call draw_hline
    mov ecx, 192
    call draw_hline
    mov ebx, 25
    mov ecx, 140
    mov edx, 53
    call draw_vline
    mov ebx, 294
    call draw_vline
    
    ; Console background
    mov edi, VGA_MEMORY + 141 * SCREEN_WIDTH + 26
    mov ecx, 50
.console_bg:
    push ecx
    mov ecx, 268
    mov al, COLOR_DARK_BG
    rep stosb
    add edi, SCREEN_WIDTH - 268
    pop ecx
    loop .console_bg
    
    ; === Draw "JARVIS" text using simple method ===
    ; Each letter is 6 pixels wide
    
    ; "J" at x=130
    mov ebx, 132
    mov ecx, 68
    mov edx, 12
    mov al, COLOR_WHITE
    call draw_vline
    mov ebx, 128
    mov ecx, 78
    mov edx, 6
    call draw_hline
    mov ebx, 128
    mov ecx, 74
    mov edx, 5
    call draw_vline
    
    ; "A" at x=140
    mov ebx, 140
    mov ecx, 68
    mov edx, 12
    call draw_vline
    mov ebx, 146
    call draw_vline
    mov ebx, 140
    mov ecx, 68
    mov edx, 7
    call draw_hline
    mov ecx, 74
    call draw_hline
    
    ; "R" at x=150
    mov ebx, 150
    mov ecx, 68
    mov edx, 12
    call draw_vline
    mov ebx, 150
    mov ecx, 68
    mov edx, 6
    call draw_hline
    mov ebx, 155
    mov ecx, 68
    mov edx, 4
    call draw_vline
    mov ebx, 150
    mov ecx, 72
    mov edx, 6
    call draw_hline
    
    ; "V" at x=160
    mov ebx, 160
    mov ecx, 68
    mov edx, 12
    call draw_vline
    mov ebx, 166
    call draw_vline
    mov ebx, 162
    mov ecx, 79
    mov edx, 3
    call draw_hline
    
    ; "I" at x=170
    mov ebx, 172
    mov ecx, 68
    mov edx, 12
    call draw_vline
    
    ; "S" at x=178
    mov ebx, 178
    mov ecx, 68
    mov edx, 6
    call draw_hline
    mov ebx, 178
    mov ecx, 68
    mov edx, 5
    call draw_vline
    mov ebx, 178
    mov ecx, 73
    mov edx, 6
    call draw_hline
    mov ebx, 183
    mov ecx, 73
    mov edx, 5
    call draw_vline
    mov ebx, 178
    mov ecx, 78
    mov edx, 6
    call draw_hline
    
    ; === Prompt ">_" in console ===
    mov ebx, 35
    mov ecx, 155
    mov edx, 6
    mov al, COLOR_JARVIS_LIGHT
    call draw_hline
    mov ebx, 41
    mov ecx, 158
    mov edx, 4
    call draw_hline
    mov ebx, 35
    mov ecx, 161
    mov edx, 6
    call draw_hline
    
    ; Cursor block
    mov ebx, 50
    mov ecx, 155
    mov edx, 8
    call draw_hline
    mov ecx, 156
    call draw_hline
    mov ecx, 157
    call draw_hline
    mov ecx, 158
    call draw_hline
    mov ecx, 159
    call draw_hline
    mov ecx, 160
    call draw_hline
    mov ecx, 161
    call draw_hline
    
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; TEXT RENDERING
; ════════════════════════════════════════════════════════════════════════════

; Draw text: ESI=string, EBX=x, ECX=y, AL=color
draw_text:
    pushad
    mov dl, al              ; Save color in DL
.text_loop:
    lodsb                   ; Load char into AL
    test al, al
    jz .text_done
    
    ; Draw this character
    call draw_char_internal
    
    add ebx, 6              ; Next character position
    jmp .text_loop
.text_done:
    popad
    ret

; Draw char: DL=color, AL=character, EBX=x, ECX=y
draw_char_internal:
    pushad
    
    ; Validate character
    cmp al, 32
    jb .char_done
    cmp al, 127
    ja .char_done
    
    ; Get font data pointer
    sub al, 32
    movzx eax, al
    imul eax, 5             ; 5 bytes per character
    add eax, font_5x7
    mov esi, eax
    
    ; Draw 5 columns
    mov dh, 5
.col_loop:
    lodsb                   ; Get column bitmap
    push ebx
    mov ch, 7               ; 7 rows
.row_loop:
    test al, 1              ; Test bottom bit
    jz .skip_pixel
    
    ; Draw pixel
    push eax
    push edx
    mov al, dl              ; Color
    call put_pixel
    pop edx
    pop eax
    
.skip_pixel:
    shr al, 1               ; Next bit
    inc ecx                 ; Next row (Y++)
    dec ch
    jnz .row_loop
    
    pop ebx
    sub ecx, 7              ; Reset Y
    inc ebx                 ; Next column (X++)
    dec dh
    jnz .col_loop
    
.char_done:
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; ANIMATION
; ════════════════════════════════════════════════════════════════════════════

animation_tick: dd 0
cursor_on:      db 1

update_animation:
    pushad
    
    inc dword [animation_tick]
    
    ; Cursor blink every 20 ticks
    mov eax, [animation_tick]
    and eax, 31
    jnz .no_blink
    
    xor byte [cursor_on], 1
    
    ; Draw/erase cursor
    mov ebx, 50
    mov ecx, 175
    cmp byte [cursor_on], 0
    je .cursor_off
    mov al, COLOR_JARVIS_LIGHT
    jmp .draw_cursor
.cursor_off:
    mov al, COLOR_DARK_BG
.draw_cursor:
    mov edx, 5
.cursor_loop:
    push ecx
    push edx
    mov edx, 5
    call draw_hline
    pop edx
    pop ecx
    inc ecx
    dec edx
    jnz .cursor_loop
    
.no_blink:
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; KEYBOARD ISR
; ════════════════════════════════════════════════════════════════════════════

keyboard_isr:
    pushad
    
    ; Read scancode from keyboard
    in al, 0x60
    
    ; Draw a pixel to show keyboard works (moves each keypress)
    mov ebx, [kbd_test_x]
    mov ecx, 145
    push eax
    mov al, COLOR_JARVIS_CYAN
    call put_pixel
    pop eax
    inc dword [kbd_test_x]
    cmp dword [kbd_test_x], 290
    jb .no_wrap_test
    mov dword [kbd_test_x], 30
.no_wrap_test:
    
    ; Ignore key release (high bit set)
    test al, 0x80
    jnz .kbd_done
    
    ; Convert scancode to ASCII
    movzx ebx, al
    mov al, [scancode_table + ebx]
    
    ; Ignore null characters
    test al, al
    jz .kbd_done
    
    ; Draw a block for each character typed
    mov ebx, [input_x]
    mov ecx, 168
    mov edx, 6
    push eax
    mov al, COLOR_JARVIS_LIGHT
    call draw_hline
    mov ecx, 169
    call draw_hline
    mov ecx, 170
    call draw_hline
    mov ecx, 171
    call draw_hline
    mov ecx, 172
    call draw_hline
    pop eax
    
    ; Advance cursor
    add dword [input_x], 8
    cmp dword [input_x], 280
    jb .kbd_done
    mov dword [input_x], 65
    
.kbd_done:
    ; Send EOI to PIC
    mov al, 0x20
    out 0x20, al
    
    popad
    iret

kbd_test_x: dd 30

input_x: dd 50

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════

txt_jarvis:  db "JARVIS", 0
txt_ai:      db "A.I.", 0
txt_welcome: db "MATHIS OS v3.0 - JARVIS Interface", 0
txt_ready:   db "System online. How may I assist you?", 0
txt_prompt:  db ">", 0

; Scancode table
scancode_table:
    db 0,27,'1','2','3','4','5','6','7','8','9','0','-','=',8,9
    db 'q','w','e','r','t','y','u','i','o','p','[',']',13,0
    db 'a','s','d','f','g','h','j','k','l',';',"'", '`',0,'\'
    db 'z','x','c','v','b','n','m',',','.','/',0,'*',0,' ',0
    times 128 - ($ - scancode_table) db 0

; IDT - Built at runtime
idt_start:
    times 256 * 8 db 0
idt_end:

idt_ptr:
    dw idt_end - idt_start - 1
    dd idt_start

; Setup IDT entry for keyboard (called from init)
setup_idt:
    pushad
    ; IDT entry for INT 0x21 (keyboard)
    mov edi, idt_start + 0x21 * 8
    mov eax, keyboard_isr
    mov [edi], ax           ; Low 16 bits
    mov word [edi + 2], 0x08 ; Code segment
    mov byte [edi + 4], 0
    mov byte [edi + 5], 0x8E ; Present, DPL=0, 32-bit interrupt gate
    shr eax, 16
    mov [edi + 6], ax       ; High 16 bits
    popad
    ret

; ════════════════════════════════════════════════════════════════════════════
; 5x7 FONT
; ════════════════════════════════════════════════════════════════════════════

font_5x7:
    db 0x00,0x00,0x00,0x00,0x00  ; Space
    db 0x00,0x00,0x5F,0x00,0x00  ; !
    db 0x00,0x07,0x00,0x07,0x00  ; "
    db 0x14,0x7F,0x14,0x7F,0x14  ; #
    db 0x24,0x2A,0x7F,0x2A,0x12  ; $
    db 0x23,0x13,0x08,0x64,0x62  ; %
    db 0x36,0x49,0x55,0x22,0x50  ; &
    db 0x00,0x05,0x03,0x00,0x00  ; '
    db 0x00,0x1C,0x22,0x41,0x00  ; (
    db 0x00,0x41,0x22,0x1C,0x00  ; )
    db 0x08,0x2A,0x1C,0x2A,0x08  ; *
    db 0x08,0x08,0x3E,0x08,0x08  ; +
    db 0x00,0x50,0x30,0x00,0x00  ; ,
    db 0x08,0x08,0x08,0x08,0x08  ; -
    db 0x00,0x60,0x60,0x00,0x00  ; .
    db 0x20,0x10,0x08,0x04,0x02  ; /
    db 0x3E,0x51,0x49,0x45,0x3E  ; 0
    db 0x00,0x42,0x7F,0x40,0x00  ; 1
    db 0x42,0x61,0x51,0x49,0x46  ; 2
    db 0x21,0x41,0x45,0x4B,0x31  ; 3
    db 0x18,0x14,0x12,0x7F,0x10  ; 4
    db 0x27,0x45,0x45,0x45,0x39  ; 5
    db 0x3C,0x4A,0x49,0x49,0x30  ; 6
    db 0x01,0x71,0x09,0x05,0x03  ; 7
    db 0x36,0x49,0x49,0x49,0x36  ; 8
    db 0x06,0x49,0x49,0x29,0x1E  ; 9
    db 0x00,0x36,0x36,0x00,0x00  ; :
    db 0x00,0x56,0x36,0x00,0x00  ; ;
    db 0x00,0x08,0x14,0x22,0x41  ; <
    db 0x14,0x14,0x14,0x14,0x14  ; =
    db 0x41,0x22,0x14,0x08,0x00  ; >
    db 0x02,0x01,0x51,0x09,0x06  ; ?
    db 0x32,0x49,0x79,0x41,0x3E  ; @
    db 0x7E,0x11,0x11,0x11,0x7E  ; A
    db 0x7F,0x49,0x49,0x49,0x36  ; B
    db 0x3E,0x41,0x41,0x41,0x22  ; C
    db 0x7F,0x41,0x41,0x22,0x1C  ; D
    db 0x7F,0x49,0x49,0x49,0x41  ; E
    db 0x7F,0x09,0x09,0x01,0x01  ; F
    db 0x3E,0x41,0x41,0x51,0x32  ; G
    db 0x7F,0x08,0x08,0x08,0x7F  ; H
    db 0x00,0x41,0x7F,0x41,0x00  ; I
    db 0x20,0x40,0x41,0x3F,0x01  ; J
    db 0x7F,0x08,0x14,0x22,0x41  ; K
    db 0x7F,0x40,0x40,0x40,0x40  ; L
    db 0x7F,0x02,0x04,0x02,0x7F  ; M
    db 0x7F,0x04,0x08,0x10,0x7F  ; N
    db 0x3E,0x41,0x41,0x41,0x3E  ; O
    db 0x7F,0x09,0x09,0x09,0x06  ; P
    db 0x3E,0x41,0x51,0x21,0x5E  ; Q
    db 0x7F,0x09,0x19,0x29,0x46  ; R
    db 0x46,0x49,0x49,0x49,0x31  ; S
    db 0x01,0x01,0x7F,0x01,0x01  ; T
    db 0x3F,0x40,0x40,0x40,0x3F  ; U
    db 0x1F,0x20,0x40,0x20,0x1F  ; V
    db 0x7F,0x20,0x18,0x20,0x7F  ; W
    db 0x63,0x14,0x08,0x14,0x63  ; X
    db 0x03,0x04,0x78,0x04,0x03  ; Y
    db 0x61,0x51,0x49,0x45,0x43  ; Z
    db 0x00,0x00,0x7F,0x41,0x41  ; [
    db 0x02,0x04,0x08,0x10,0x20  ; \
    db 0x41,0x41,0x7F,0x00,0x00  ; ]
    db 0x04,0x02,0x01,0x02,0x04  ; ^
    db 0x40,0x40,0x40,0x40,0x40  ; _
    db 0x00,0x01,0x02,0x04,0x00  ; `
    ; Lowercase (same as uppercase)
    db 0x7E,0x11,0x11,0x11,0x7E  ; a
    db 0x7F,0x49,0x49,0x49,0x36  ; b
    db 0x3E,0x41,0x41,0x41,0x22  ; c
    db 0x7F,0x41,0x41,0x22,0x1C  ; d
    db 0x7F,0x49,0x49,0x49,0x41  ; e
    db 0x7F,0x09,0x09,0x01,0x01  ; f
    db 0x3E,0x41,0x41,0x51,0x32  ; g
    db 0x7F,0x08,0x08,0x08,0x7F  ; h
    db 0x00,0x41,0x7F,0x41,0x00  ; i
    db 0x20,0x40,0x41,0x3F,0x01  ; j
    db 0x7F,0x08,0x14,0x22,0x41  ; k
    db 0x7F,0x40,0x40,0x40,0x40  ; l
    db 0x7F,0x02,0x04,0x02,0x7F  ; m
    db 0x7F,0x04,0x08,0x10,0x7F  ; n
    db 0x3E,0x41,0x41,0x41,0x3E  ; o
    db 0x7F,0x09,0x09,0x09,0x06  ; p
    db 0x3E,0x41,0x51,0x21,0x5E  ; q
    db 0x7F,0x09,0x19,0x29,0x46  ; r
    db 0x46,0x49,0x49,0x49,0x31  ; s
    db 0x01,0x01,0x7F,0x01,0x01  ; t
    db 0x3F,0x40,0x40,0x40,0x3F  ; u
    db 0x1F,0x20,0x40,0x20,0x1F  ; v
    db 0x7F,0x20,0x18,0x20,0x7F  ; w
    db 0x63,0x14,0x08,0x14,0x63  ; x
    db 0x03,0x04,0x78,0x04,0x03  ; y
    db 0x61,0x51,0x49,0x45,0x43  ; z

; ════════════════════════════════════════════════════════════════════════════
; END OF KERNEL
; ════════════════════════════════════════════════════════════════════════════
