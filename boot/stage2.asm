; Stage 2 Bootloader - MATHIS OS 3D Edition
; Loads kernel, initializes VESA graphics, enters protected mode
; Uses LBA mode for reliable multi-sector reads

[BITS 16]
[ORG 0x7E00]

; ═══════════════════════════════════════════════════════════════════════════
; VESA CONSTANTS
; ═══════════════════════════════════════════════════════════════════════════
VESA_INFO       equ 0x9000      ; VBE controller info
VESA_MODE_INFO  equ 0x9200      ; VBE mode info
VESA_MODE       equ 0x4118      ; 1024x768x32 (or try 0x4115 for 800x600x32)
; Common VESA modes:
; 0x4101 = 640x480x8    0x4111 = 640x480x16   0x4112 = 640x480x32
; 0x4103 = 800x600x8    0x4114 = 800x600x16   0x4115 = 800x600x32
; 0x4105 = 1024x768x8   0x4117 = 1024x768x16  0x4118 = 1024x768x32
; 0x4107 = 1280x1024x8  0x411A = 1280x1024x16 0x411B = 1280x1024x32

start:
    ; Print "Loading..."
    mov si, loading_msg
.print:
    lodsb
    or al, al
    jz .done_print
    mov ah, 0x0E
    int 0x10
    jmp .print
.done_print:

    ; ═══════════════════════════════════════════════════════════════════
    ; Stay in TEXT MODE for now - graphics via kernel later
    ; ═══════════════════════════════════════════════════════════════════
    mov byte [vesa_enabled], 0
    mov dword [vesa_fb_addr], 0xA0000
    mov word [vesa_width], 320
    mov word [vesa_height], 200
    mov word [vesa_pitch], 320
    mov byte [vesa_bpp], 8

    ; ═══════════════════════════════════════════════════════════════════
    ; Load kernel using CHS mode (LBA mode unreliable in QEMU floppy)
    ; ═══════════════════════════════════════════════════════════════════

    ; Read 1: 9 sectors C0/H0/S10 -> 0x10000
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 9
    mov cx, 0x000A          ; C=0, S=10
    mov dx, 0x0000          ; H=0, Drive=0
    int 0x13
    jc disk_error

    ; Read 2: 18 sectors C0/H1/S1 -> 0x11200
    mov bx, 0x1200
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0001          ; C=0, S=1
    mov dx, 0x0100          ; H=1
    int 0x13
    jc disk_error

    ; Read 3: 18 sectors C1/H0/S1 -> 0x13600
    mov bx, 0x3600
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0101          ; C=1, S=1
    mov dx, 0x0000          ; H=0
    int 0x13
    jc disk_error

    ; Read 4: 18 sectors C1/H1/S1 -> 0x15A00
    mov bx, 0x5A00
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0101          ; C=1, S=1
    mov dx, 0x0100          ; H=1
    int 0x13
    jc disk_error

    ; Read 5: 18 sectors C2/H0/S1 -> 0x17E00
    mov bx, 0x7E00
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0201          ; C=2, S=1
    mov dx, 0x0000          ; H=0
    int 0x13
    jc disk_error

    ; Read 6: 18 sectors C2/H1/S1 -> 0x1A200
    mov ax, 0x1A20
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0201          ; C=2, S=1
    mov dx, 0x0100          ; H=1
    int 0x13
    jc disk_error

    ; Read 7: 18 sectors C3/H0/S1 -> 0x1C600
    mov ax, 0x1C60
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0301          ; C=3, S=1
    mov dx, 0x0000          ; H=0
    int 0x13
    jc disk_error

    ; Read 8: 11 sectors C3/H1/S1 -> 0x1EA00 (128 total = 64KB)
    mov ax, 0x1EA0
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 11
    mov cx, 0x0301          ; C=3, S=1
    mov dx, 0x0100          ; H=1
    int 0x13
    jc disk_error

    ; Print "64K+"
    mov ah, 0x0E
    mov al, '6'
    int 0x10
    mov al, '4'
    int 0x10
    mov al, 'K'
    int 0x10
    mov al, '+'
    int 0x10

    ; ═══════════════════════════════════════════════════════════════════
    ; SET VGA MODE 13h (320x200x256) - BIOS call in real mode
    ; ═══════════════════════════════════════════════════════════════════
    mov ax, 0x0013
    int 0x10

    jmp enable_a20

disk_error:
    ; Print 'E' on error and halt
    mov ax, 0xB800
    mov es, ax
    mov word [es:0], 0x4F45  ; 'E' in red
    cli
    hlt

; ═══════════════════════════════════════════════════════════════════════════
; VESA INITIALIZATION (Real Mode)
; ═══════════════════════════════════════════════════════════════════════════
init_vesa:
    push es
    push di

    ; Get VBE Controller Info
    mov ax, 0x4F00
    mov di, VESA_INFO
    push ds
    pop es
    int 0x10

    cmp ax, 0x004F
    jne .vesa_fail

    ; Check VBE signature "VESA"
    cmp dword [VESA_INFO], 'VESA'
    jne .vesa_fail

    ; Print 'V' for VESA detected
    mov ah, 0x0E
    mov al, 'V'
    int 0x10

    ; Get Mode Info for our target mode
    mov ax, 0x4F01
    mov cx, VESA_MODE
    mov di, VESA_MODE_INFO
    int 0x10

    cmp ax, 0x004F
    jne .vesa_fail

    ; Check if mode is supported and has LFB
    mov ax, [VESA_MODE_INFO]        ; Mode attributes
    test ax, 0x80                    ; Check LFB available bit
    jz .vesa_fail

    ; Print 'E' for mode enumerated
    mov ah, 0x0E
    mov al, 'E'
    int 0x10

    ; Store framebuffer info for kernel
    ; These will be copied to kernel data area
    mov eax, [VESA_MODE_INFO + 40]  ; PhysBasePtr (LFB address)
    mov [vesa_fb_addr], eax

    mov ax, [VESA_MODE_INFO + 18]   ; XResolution
    mov [vesa_width], ax

    mov ax, [VESA_MODE_INFO + 20]   ; YResolution
    mov [vesa_height], ax

    mov ax, [VESA_MODE_INFO + 16]   ; BytesPerScanLine
    mov [vesa_pitch], ax

    mov al, [VESA_MODE_INFO + 25]   ; BitsPerPixel
    mov [vesa_bpp], al

    ; Set VESA Mode with LFB
    mov ax, 0x4F02
    mov bx, VESA_MODE
    or bx, 0x4000                   ; Enable LFB
    int 0x10

    cmp ax, 0x004F
    jne .vesa_fail

    ; Print 'S' for mode set
    ; Note: After mode set, text output won't work!
    ; We'll draw directly to framebuffer

    ; Success
    mov byte [vesa_enabled], 1
    pop di
    pop es
    ret

.vesa_fail:
    ; VESA failed - continue with VGA text mode
    mov ah, 0x0E
    mov al, '!'
    int 0x10
    mov byte [vesa_enabled], 0
    pop di
    pop es
    ret

; VESA data (will be passed to kernel)
vesa_enabled    db 0
vesa_fb_addr    dd 0
vesa_width      dw 0
vesa_height     dw 0
vesa_pitch      dw 0
vesa_bpp        db 0

enable_a20:
    ; Enable A20 line (fast method)
    in al, 0x92
    or al, 2
    and al, 0xFE            ; Don't reset
    out 0x92, al

    ; Disable interrupts
    cli

    ; Load GDT
    lgdt [gdt_ptr]

    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to 32-bit code
    jmp 0x08:pm_entry

[BITS 32]
pm_entry:
    ; Set up segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; Copy VESA info to kernel data area (0x500)
    ; The kernel will read this to configure graphics
    mov esi, vesa_enabled
    mov edi, 0x500
    mov ecx, 16             ; Copy VESA data block
    rep movsb

    ; Also copy to a fixed location the kernel expects
    ; fb_address at 0x510, fb_width at 0x514, etc.
    movzx eax, byte [0x500]     ; vesa_enabled
    mov [0x500], eax

    mov eax, [0x501]            ; vesa_fb_addr (misaligned but ok)
    mov [0x510], eax            ; fb_address

    movzx eax, word [0x505]     ; vesa_width
    mov [0x514], eax            ; fb_width

    movzx eax, word [0x507]     ; vesa_height
    mov [0x518], eax            ; fb_height

    movzx eax, word [0x509]     ; vesa_pitch
    mov [0x51C], eax            ; fb_pitch

    movzx eax, byte [0x50B]     ; vesa_bpp
    mov [0x520], eax            ; fb_bpp

    ; If VESA enabled, draw a test pixel to confirm it works
    cmp byte [0x500], 1
    jne .no_vesa_test

    ; Draw red pixel at (0,0) to confirm framebuffer works
    mov edi, [0x510]            ; fb_address
    mov dword [edi], 0x00FF0000 ; Red pixel (ARGB)

    ; Draw a gradient bar to show graphics working
    mov ecx, 256
.gradient_loop:
    mov eax, ecx
    shl eax, 16                 ; Red component
    or eax, ecx                 ; Blue component
    shl ecx, 8
    or eax, ecx                 ; Green component
    shr ecx, 8
    stosd
    loop .gradient_loop

.no_vesa_test:
    ; Jump to kernel at 0x10000
    jmp 0x08:0x10000

; GDT Pointer
gdt_ptr:
    dw gdt_end - gdt - 1    ; GDT limit
    dd gdt                  ; GDT base

; GDT
gdt:
    ; Null descriptor
    dq 0

    ; Code segment: base=0, limit=4GB, 32-bit, ring 0
    dw 0xFFFF               ; Limit low
    dw 0x0000               ; Base low
    db 0x00                 ; Base middle
    db 0x9A                 ; Access: present, ring 0, code, exec/read
    db 0xCF                 ; Flags: 4KB granularity, 32-bit + limit high
    db 0x00                 ; Base high

    ; Data segment: base=0, limit=4GB, 32-bit, ring 0
    dw 0xFFFF               ; Limit low
    dw 0x0000               ; Base low
    db 0x00                 ; Base middle
    db 0x92                 ; Access: present, ring 0, data, read/write
    db 0xCF                 ; Flags: 4KB granularity, 32-bit + limit high
    db 0x00                 ; Base high
gdt_end:

loading_msg: db "MATHIS 3D Loading...", 13, 10, 0

    ; Pad to 4096 bytes
    times 4096 - ($ - $$) db 0
