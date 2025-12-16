; ═══════════════════════════════════════════════════════════════════════════
; MATHIS OS STAGE2 - VESA High Resolution Edition
; Loads 512KB kernel, sets VESA 1024x768 mode, enters protected mode
; ═══════════════════════════════════════════════════════════════════════════

[BITS 16]
[ORG 0x7E00]

KERNEL_SECTORS  equ 1024        ; 512KB = 1024 sectors
KERNEL_LBA      equ 9           ; Kernel starts at LBA 9

; VESA modes to try (in order of preference)
VESA_MODE_1024  equ 0x118       ; 1024x768x32
VESA_MODE_800   equ 0x115       ; 800x600x32
VESA_MODE_640   equ 0x112       ; 640x480x32

start:
    mov si, msg_loading
    call print_string

    ; Save boot drive
    mov [boot_drive], dl

    ; Load kernel in 16 chunks of 64 sectors (32KB each)
    mov dword [current_lba], KERNEL_LBA
    mov word [current_seg], 0x1000   ; Load at 0x10000
    mov cx, 16                        ; 16 chunks = 512KB

.load_loop:
    push cx

    ; Setup DAP
    mov word [dap_sectors], 64
    mov ax, [current_seg]
    mov word [dap_segment], ax
    mov word [dap_offset], 0
    mov eax, [current_lba]
    mov dword [dap_lba_low], eax

    ; Read sectors using LBA
    mov si, dap
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; Print dot for progress
    mov al, '.'
    mov ah, 0x0E
    int 0x10

    ; Next chunk
    add dword [current_lba], 64
    add word [current_seg], 0x800    ; +32KB

    pop cx
    loop .load_loop

    ; Print OK
    mov si, msg_ok
    call print_string

    ; === Try VESA High Resolution ===
    mov si, msg_vesa
    call print_string

    ; Check VESA availability
    mov ax, 0x4F00
    mov di, vesa_info
    int 0x10
    cmp ax, 0x004F
    jne .try_vga

    ; Try 1024x768x32
    mov cx, VESA_MODE_1024 | 0x4000  ; Linear framebuffer flag
    call try_vesa_mode
    jnc .vesa_ok

    ; Try 800x600x32
    mov cx, VESA_MODE_800 | 0x4000
    call try_vesa_mode
    jnc .vesa_ok

    ; Try 640x480x32
    mov cx, VESA_MODE_640 | 0x4000
    call try_vesa_mode
    jnc .vesa_ok

.try_vga:
    ; Fall back to VGA 320x200
    mov si, msg_vga_fallback
    call print_string
    mov ax, 0x0013
    int 0x10
    mov dword [framebuffer_addr], 0xA0000
    mov word [screen_width], 320
    mov word [screen_height], 200
    mov word [screen_pitch], 320
    mov byte [screen_bpp], 8
    mov byte [vesa_mode], 0
    jmp .video_done

.vesa_ok:
    mov byte [vesa_mode], 1
    mov si, msg_vesa_ok
    call print_string

.video_done:
    ; Enable A20
    in al, 0x92
    or al, 2
    and al, 0xFE
    out 0x92, al

    cli
    lgdt [gdt_ptr]

    ; Enter protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:pm_entry

; ═══════════════════════════════════════════════════════════════════════════
; try_vesa_mode - Try to set a VESA mode
; Input: CX = mode number (with LFB flag)
; Output: CF clear on success, set on failure
; ═══════════════════════════════════════════════════════════════════════════
try_vesa_mode:
    push cx
    push ax
    push di

    ; Get mode info
    and cx, 0x1FF               ; Strip flags for info query
    mov ax, 0x4F01
    mov di, mode_info
    int 0x10
    cmp ax, 0x004F
    jne .mode_fail

    ; Check if mode is supported (bit 0)
    test byte [mode_info], 0x01
    jz .mode_fail

    ; Check if linear framebuffer available (bit 7)
    test byte [mode_info], 0x80
    jz .mode_fail

    ; Set mode
    pop di
    pop ax
    pop cx
    mov ax, 0x4F02
    mov bx, cx
    int 0x10
    cmp ax, 0x004F
    jne .set_fail

    ; Get mode info again to populate our variables
    push cx
    and cx, 0x1FF
    mov ax, 0x4F01
    mov di, mode_info
    int 0x10
    pop cx

    ; Store framebuffer info
    mov eax, [mode_info + 40]   ; PhysBasePtr
    mov [framebuffer_addr], eax
    mov ax, [mode_info + 18]    ; XResolution
    mov [screen_width], ax
    mov ax, [mode_info + 20]    ; YResolution
    mov [screen_height], ax
    mov ax, [mode_info + 16]    ; BytesPerScanLine
    mov [screen_pitch], ax
    mov al, [mode_info + 25]    ; BitsPerPixel
    mov [screen_bpp], al

    clc                         ; Success
    ret

.mode_fail:
    pop di
    pop ax
    pop cx
.set_fail:
    stc                         ; Failure
    ret

disk_error:
    mov si, msg_error
    call print_string
    cli
    hlt

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

; Variables
boot_drive:     db 0
current_lba:    dd 0
current_seg:    dw 0
framebuffer_addr: dd 0xA0000
screen_width:   dw 320
screen_height:  dw 200
screen_pitch:   dw 320
screen_bpp:     db 8
vesa_mode:      db 0

; DAP for LBA read
align 4
dap:
    db 0x10, 0
dap_sectors:    dw 0
dap_offset:     dw 0
dap_segment:    dw 0
dap_lba_low:    dd 0
dap_lba_high:   dd 0

msg_loading: db "MATHIS OS", 0
msg_ok:      db " OK", 13, 10, 0
msg_error:   db " ERR!", 0
msg_vesa:    db "VESA...", 0
msg_vesa_ok: db "OK", 13, 10, 0
msg_vga_fallback: db "VGA", 13, 10, 0

; VESA info buffers
align 16
vesa_info: times 512 db 0
mode_info: times 256 db 0

[BITS 32]
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; Pass video info to kernel at fixed memory location 0x500
    ; Layout:
    ;   0x500: Framebuffer address (4 bytes)
    ;   0x504: Screen width (4 bytes)
    ;   0x508: Screen height (4 bytes)
    ;   0x50C: VESA mode flag (4 bytes)
    ;   0x510: Pitch/BytesPerScanLine (4 bytes)
    ;   0x514: BitsPerPixel (4 bytes)
    mov eax, [framebuffer_addr]
    mov [0x500], eax              ; Framebuffer address
    movzx eax, word [screen_width]
    mov [0x504], eax              ; Screen width
    movzx eax, word [screen_height]
    mov [0x508], eax              ; Screen height
    movzx eax, byte [vesa_mode]
    mov [0x50C], eax              ; VESA mode flag
    movzx eax, word [screen_pitch]
    mov [0x510], eax              ; Pitch
    movzx eax, byte [screen_bpp]
    mov [0x514], eax              ; Bits per pixel

    jmp 0x08:0x10000

; GDT
align 16
gdt:
    dq 0
    dq 0x00CF9A000000FFFF   ; Code
    dq 0x00CF92000000FFFF   ; Data
gdt_end:

gdt_ptr:
    dw gdt_end - gdt - 1
    dd gdt

times 4096 - ($ - $$) db 0
