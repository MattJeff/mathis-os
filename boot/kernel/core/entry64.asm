; ════════════════════════════════════════════════════════════════════════════
; ENTRY64.ASM - 32-bit to 64-bit transition + 64-bit initialization
; ════════════════════════════════════════════════════════════════════════════
; This file contains:
;   - do_go64: Setup paging, GDT, switch to long mode
;   - long_mode_entry: 64-bit initialization (screen, devices, etc.)
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; DO_GO64 - Switch from 32-bit protected mode to 64-bit long mode
; Called from core.asm (32-bit)
; ════════════════════════════════════════════════════════════════════════════
do_go64:
    cli

    ; Setup page tables at 0x1000
    ; Clear 5 pages: PML4(0x1000), PDPT(0x2000), PD0(0x3000), PD3(0x4000), spare(0x5000)
    mov edi, 0x1000
    mov ecx, 5120               ; 5 pages * 1024 dwords
    xor eax, eax
    rep stosd

    ; Page table flags: P=Present, W=Write, U=User accessible, PS=Page Size (2MB)
    ; PML4[0] -> PDPT at 0x2000
    mov dword [0x1000], 0x2007      ; P+W+U

    ; PDPT[0] -> PD at 0x3000 (for 0-1GB)
    mov dword [0x2000], 0x3007      ; P+W+U

    ; PDPT[3] -> PD at 0x4000 (for 3-4GB, covers PCI MMIO)
    mov dword [0x2018], 0x4007      ; P+W+U (offset 0x18 = entry 3)

    ; PD0: Map first 32MB (heap needs 4-20MB)
    mov dword [0x3000], 0x00000087  ; 0-2MB
    mov dword [0x3008], 0x00200087  ; 2-4MB
    mov dword [0x3010], 0x00400087  ; 4-6MB
    mov dword [0x3018], 0x00600087  ; 6-8MB
    mov dword [0x3020], 0x00800087  ; 8-10MB
    mov dword [0x3028], 0x00A00087  ; 10-12MB
    mov dword [0x3030], 0x00C00087  ; 12-14MB
    mov dword [0x3038], 0x00E00087  ; 14-16MB
    mov dword [0x3040], 0x01000087  ; 16-18MB
    mov dword [0x3048], 0x01200087  ; 18-20MB
    mov dword [0x3050], 0x01400087  ; 20-22MB
    mov dword [0x3058], 0x01600087  ; 22-24MB
    mov dword [0x3060], 0x01800087  ; 24-26MB
    mov dword [0x3068], 0x01A00087  ; 26-28MB
    mov dword [0x3070], 0x01C00087  ; 28-30MB
    mov dword [0x3078], 0x01E00087  ; 30-32MB

    ; PD3: Map VESA LFB + PCI MMIO region 0xFD000000-0xFFFFFFFF (48MB)
    mov edi, 0x4000 + (488 * 8)     ; Start at PD entry 488
    mov eax, 0xFD000087             ; Base address 0xFD000000 + P+W+U+PS
    mov ecx, 24                     ; 24 entries for 48MB
.map_mmio:
    mov [edi], eax
    mov dword [edi+4], 0            ; High 32 bits = 0
    add edi, 8
    add eax, 0x200000               ; Next 2MB page
    loop .map_mmio

    ; Enable PAE
    mov eax, cr4
    or eax, 0x20
    mov cr4, eax

    ; Load CR3
    mov eax, 0x1000
    mov cr3, eax

    ; Enable Long Mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 0x100
    wrmsr

    ; Load GDT
    lgdt [gdt64_ptr]

    ; Enable Paging
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    jmp 0x08:long_mode_entry

; ════════════════════════════════════════════════════════════════════════════
; 64-BIT LONG MODE ENTRY
; ════════════════════════════════════════════════════════════════════════════
[BITS 64]
long_mode_entry:
    ; Setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x90000

    ; Initialize screen from stage2 video info at 0x500
    mov eax, [VIDEO_INFO_FB]
    mov [screen_fb], eax
    mov eax, [VIDEO_INFO_W]
    mov [screen_width], eax
    mov eax, [VIDEO_INFO_PITCH]
    mov [screen_pitch], eax
    mov eax, [VIDEO_INFO_H]
    mov [screen_height], eax
    mov eax, [VIDEO_INFO_BPP]
    mov [screen_bpp], eax

    ; Calculate center
    mov eax, [screen_width]
    shr eax, 1
    mov [screen_centerx], eax
    mov eax, [screen_height]
    shr eax, 1
    mov [screen_centery], eax

    ; Center mouse at screen center
    mov eax, [screen_centerx]
    mov [mouse_x], ax
    mov eax, [screen_centery]
    mov [mouse_y], ax

    ; Initialize variables
    mov qword [tick_count], 0
    mov byte [mode_flag], 3          ; Start in 3D GUI mode
    mov byte [mouse_buttons], 0
    mov byte [mouse_cycle], 0
    mov byte [active_window], 0xFF   ; No window active
    mov byte [start_menu_open], 0
    mov byte [dragging], 0

    ; Clear windows
    mov rdi, windows
    mov rcx, MAX_WINDOWS * 32
    xor al, al
    rep stosb

    ; Clear command buffer
    mov rdi, cmd_buf
    mov rcx, 64
    xor al, al
    rep stosb
    mov byte [cmd_pos], 0

    ; Setup IDT with mouse support
    call setup_idt64

    ; Setup TSS for Ring 3 support
    call setup_tss64

    ; Setup PIC
    call setup_pic64

    ; Setup PIT (100Hz)
    call setup_pit64

    ; Initialize PS/2 Mouse
    call mouse_init

    ; Clear keyboard buffer
    in al, 0x60
    in al, 0x60

    ; Initialize scheduler
    call scheduler_init

    ; Initialize network (E1000)
    call net_init

    ; Initialize USB (UHCI controller)
    call usb_init

    ; Initialize ACPI for power management
    call acpi_init

    ; Initialize heap allocator
    call heap_init

    ; Initialize service registry (SOLID Phase 2)
    ; TODO: call registry_init cause boot loop - à investiguer
    ; call alloc_svc_init

    ; Initialize FAT32 filesystem
    call fat32_init

    ; Create demo processes (2 processes with register-only operations)
    mov rdi, demo_process_1
    mov rsi, str_proc_demo1
    call create_process

    mov rdi, demo_process_2
    mov rsi, str_proc_demo2
    call create_process

    ; Enable scheduler tracking
    call scheduler_enable

    ; Enable interrupts
    sti

    ; Jump to main loop
    jmp main_loop
