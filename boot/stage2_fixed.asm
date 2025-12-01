; Stage 2 Bootloader - Loads kernel using INT 13h extensions (LBA mode)
; Loads at 0x7E00, jumps to protected mode, then to kernel at 0x10000
; Uses LBA mode for reliable multi-sector reads

[BITS 16]
[ORG 0x7E00]

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
    ; Load kernel using CHS mode (LBA mode unreliable in QEMU floppy)
    ; kernel.bin is at LBA sector 9 (0-indexed), which is disk offset 0x1200
    ; boot.bin = sector 0, stage2.bin = sectors 1-8, kernel = sectors 9+
    ; Need to load 32 sectors (16KB kernel)
    ; ═══════════════════════════════════════════════════════════════════

    ; Skip LBA detection and go straight to CHS mode
    jmp no_lba

    ; (LBA code below is kept but not used)
    ; First, check if INT 13h extensions are available
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, 0x00            ; Drive 0 (floppy A)
    int 0x13
    jc no_lba               ; Extensions not available
    cmp bx, 0xAA55
    jne no_lba              ; Extensions not available

    ; Use LBA mode to load 32 sectors starting from LBA 9
    mov si, dap
    mov ah, 0x42
    mov dl, 0x00            ; Drive 0 (floppy A)
    int 0x13
    jc disk_error

    jmp enable_a20

no_lba:
    ; Fallback: Use CHS mode with multiple reads
    ; Floppy: 18 sectors/track, 2 heads
    ; Kernel starts at LBA 9 (sector 10 on track 0, head 0)
    ; Need to read 32 sectors total (16KB kernel)

    ; Print '1' before Read 1
    mov ah, 0x0E
    mov al, '1'
    int 0x10

    ; Read 1: 9 sectors from Track 0, Head 0, Sector 10 -> 0x10000
    ; LBA 9-17 -> physical 0x10000-0x111FF (9 sectors = 0x1200 bytes)
    mov ax, 0x1000
    mov es, ax
    xor bx, bx              ; ES:BX = 0x1000:0x0000 = 0x10000

    mov ah, 0x02            ; Read sectors
    mov al, 9               ; 9 sectors
    mov ch, 0               ; Cylinder 0
    mov cl, 10              ; Sector 10 (1-based)
    mov dh, 0               ; Head 0
    mov dl, 0               ; Drive 0
    int 0x13
    jc disk_error

    ; Print '2' before Read 2
    mov ah, 0x0E
    mov al, '2'
    int 0x10

    ; Read 2: 18 sectors from Track 0, Head 1, Sector 1 -> 0x11200
    ; LBA 18-35 -> physical 0x11200-0x135FF (18 sectors = 0x2400 bytes)
    mov ax, 0x1000
    mov es, ax
    mov bx, 0x1200          ; ES:BX = 0x1000:0x1200 = 0x11200

    mov ah, 0x02            ; Read sectors
    mov al, 18              ; 18 sectors (full track)
    mov ch, 0               ; Cylinder 0
    mov cl, 1               ; Sector 1
    mov dh, 1               ; Head 1
    mov dl, 0               ; Drive 0
    int 0x13
    jc disk_error

    ; Print '3' before Read 3
    mov ah, 0x0E
    mov al, '3'
    int 0x10

    ; Read 3: 5 sectors from Track 1, Head 0, Sector 1 -> 0x13600
    ; LBA 36-40 -> physical 0x13600-0x13FFF (5 sectors = 0xA00 bytes)
    mov ax, 0x1000
    mov es, ax
    mov bx, 0x3600          ; ES:BX = 0x1000:0x3600 = 0x13600

    mov ah, 0x02            ; Read sectors
    mov al, 5               ; 5 sectors
    mov ch, 1               ; Cylinder 1
    mov cl, 1               ; Sector 1
    mov dh, 0               ; Head 0
    mov dl, 0               ; Drive 0
    int 0x13
    jc disk_error

    ; Print 'OK' if all reads succeeded
    mov ah, 0x0E
    mov al, 'O'
    int 0x10
    mov al, 'K'
    int 0x10

    ; ═══════════════════════════════════════════════════════════════════
    ; SWITCH TO VGA MODE 13h (320x200x256) - JARVIS GRAPHICS MODE
    ; Must be done BEFORE entering protected mode (while BIOS is available)
    ; ═══════════════════════════════════════════════════════════════════
    mov ax, 0x0013      ; VGA Mode 13h: 320x200, 256 colors
    int 0x10            ; Call BIOS video interrupt

    jmp enable_a20

disk_error:
    ; Print 'E' on error and halt
    mov ax, 0xB800
    mov es, ax
    mov word [es:0], 0x4F45  ; 'E' in red
    cli
    hlt

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

; DAP (Disk Address Packet) for INT 13h AH=42h - placed AFTER the jump
dap:
    db 0x10                 ; Size of DAP (16 bytes)
    db 0                    ; Reserved
    dw 32                   ; Number of sectors to read
    dw 0x0000               ; Offset (destination)
    dw 0x1000               ; Segment (destination) = 0x1000:0 = 0x10000
    dq 9                    ; Starting LBA (sector 9 = kernel start)

[BITS 32]
pm_entry:
    ; Set up segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; We're now in VGA Mode 13h (320x200 graphics)
    ; No text mode VGA writes - kernel will draw JARVIS UI
    
    ; Jump to kernel at 0x10000
    jmp 0x08:0x10000

; GDT Pointer
gdt_ptr:
    dw gdt_end - gdt - 1    ; GDT limit
    dd gdt                  ; GDT base (will be 0x7F06)

; GDT at offset 0x106 (address 0x7F06)
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

loading_msg: db "Loading...", 13, 10, 0

    ; Pad to 4096 bytes
    times 4096 - ($ - $$) db 0
