; ════════════════════════════════════════════════════════════════════════════
; UHCI_INIT.ASM - UHCI Controller Initialization
; Scans PCI for UHCI controller and initializes frame list
; ════════════════════════════════════════════════════════════════════════════

; UHCI PCI Class: 0x0C (Serial Bus), Subclass: 0x03 (USB), Interface: 0x00 (UHCI)
UHCI_PCI_CLASS      equ 0x0C
UHCI_PCI_SUBCLASS   equ 0x03
UHCI_PCI_IFACE      equ 0x00

; UHCI Register Offsets (I/O port based)
UHCI_USBCMD         equ 0x00    ; USB Command (16-bit)
UHCI_USBSTS         equ 0x02    ; USB Status (16-bit)
UHCI_USBINTR        equ 0x04    ; USB Interrupt Enable (16-bit)
UHCI_FRNUM          equ 0x06    ; Frame Number (16-bit)
UHCI_FRBASEADD      equ 0x08    ; Frame List Base Address (32-bit)
UHCI_SOFMOD         equ 0x0C    ; Start of Frame Modify (8-bit)
UHCI_PORTSC1        equ 0x10    ; Port 1 Status/Control (16-bit)
UHCI_PORTSC2        equ 0x12    ; Port 2 Status/Control (16-bit)

; USBCMD bits
UHCI_CMD_RS         equ 0x0001  ; Run/Stop
UHCI_CMD_HCRESET    equ 0x0002  ; Host Controller Reset
UHCI_CMD_GRESET     equ 0x0004  ; Global Reset
UHCI_CMD_EGSM       equ 0x0008  ; Enter Global Suspend Mode
UHCI_CMD_FGR        equ 0x0010  ; Force Global Resume
UHCI_CMD_SWDBG      equ 0x0020  ; Software Debug
UHCI_CMD_CF         equ 0x0040  ; Configure Flag
UHCI_CMD_MAXP       equ 0x0080  ; Max Packet (0=32, 1=64)

; USBSTS bits
UHCI_STS_USBINT     equ 0x0001  ; USB Interrupt
UHCI_STS_ERROR      equ 0x0002  ; USB Error Interrupt
UHCI_STS_RD         equ 0x0004  ; Resume Detect
UHCI_STS_HSE        equ 0x0008  ; Host System Error
UHCI_STS_HCPE       equ 0x0010  ; Host Controller Process Error
UHCI_STS_HCH        equ 0x0020  ; HC Halted

; PORTSC bits
UHCI_PORT_CCS       equ 0x0001  ; Current Connect Status
UHCI_PORT_CSC       equ 0x0002  ; Connect Status Change
UHCI_PORT_PED       equ 0x0004  ; Port Enabled/Disabled
UHCI_PORT_PEDC      equ 0x0008  ; Port Enable/Disable Change
UHCI_PORT_LSDA      equ 0x0100  ; Low Speed Device Attached
UHCI_PORT_RESET     equ 0x0200  ; Port Reset
UHCI_PORT_SUSPEND   equ 0x1000  ; Suspend

; Frame list size: 1024 entries * 4 bytes = 4KB (aligned)
UHCI_FRAME_LIST_SIZE    equ 4096
UHCI_FRAME_LIST_ENTRIES equ 1024

; ════════════════════════════════════════════════════════════════════════════
; UHCI_INIT - Find and initialize UHCI controller
; Output: CF set if not found
; ════════════════════════════════════════════════════════════════════════════
uhci_init:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    ; Scan PCI for UHCI controller
    xor ebx, ebx            ; Bus 0

.scan_bus:
    xor ecx, ecx            ; Device 0

.scan_device:
    xor edx, edx            ; Function 0

.scan_function:
    ; Read Class/Subclass/Interface
    mov eax, ebx
    shl eax, 16
    or eax, ecx
    shl eax, 3
    or eax, edx
    shl eax, 8
    or eax, 0x08            ; Offset 0x08 = Revision/Class
    or eax, 0x80000000      ; Enable bit

    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx

    ; Check class (byte 3) = 0x0C, subclass (byte 2) = 0x03, interface (byte 1) = 0x00
    shr eax, 8              ; Shift to get class/subclass/iface
    cmp ah, UHCI_PCI_CLASS  ; Class 0x0C
    jne .next_function
    mov al, ah
    shr eax, 8
    cmp al, UHCI_PCI_SUBCLASS   ; Subclass 0x03
    jne .next_function
    ; Read interface separately
    push rbx
    push rcx
    push rdx

    mov eax, ebx
    shl eax, 16
    or eax, ecx
    shl eax, 3
    or eax, [rsp]           ; Function from stack
    shl eax, 8
    or eax, 0x09            ; Offset for interface
    or eax, 0x80000000

    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    and eax, 0xFF

    pop rdx
    pop rcx
    pop rbx

    cmp al, UHCI_PCI_IFACE
    jne .next_function

    ; Found UHCI! Save bus/device/function
    mov [uhci_pci_bus], bl
    mov [uhci_pci_dev], cl
    mov [uhci_pci_func], dl

    ; Read BAR4 (I/O Base Address)
    mov eax, ebx
    shl eax, 16
    or eax, ecx
    shl eax, 3
    or eax, edx
    shl eax, 8
    or eax, 0x20            ; BAR4
    or eax, 0x80000000

    push rdx
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    pop rdx

    and eax, 0xFFFFFFFC     ; Mask I/O bit
    mov [uhci_io_base], ax

    ; Enable bus mastering and I/O space
    mov eax, ebx
    shl eax, 16
    or eax, ecx
    shl eax, 3
    or eax, edx
    shl eax, 8
    or eax, 0x04            ; Command register
    or eax, 0x80000000

    push rdx
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx

    or eax, 0x05            ; Bus Master + I/O Space
    push rax
    mov dx, 0xCF8
    mov eax, ebx
    shl eax, 16
    or eax, ecx
    shl eax, 3
    or eax, [rsp + 8]       ; Function
    shl eax, 8
    or eax, 0x04
    or eax, 0x80000000
    out dx, eax
    pop rax
    mov dx, 0xCFC
    out dx, eax
    pop rdx

    mov byte [uhci_found], 1
    clc
    jmp .init_done

.next_function:
    inc edx
    cmp edx, 8
    jl .scan_function

    inc ecx
    cmp ecx, 32
    jl .scan_device

    inc ebx
    cmp ebx, 256
    jl .scan_bus

    ; Not found
    mov byte [uhci_found], 0
    stc

.init_done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_RESET - Reset the UHCI controller
; ════════════════════════════════════════════════════════════════════════════
uhci_reset:
    push rax
    push rcx
    push rdx

    cmp byte [uhci_found], 0
    je .reset_done

    mov dx, [uhci_io_base]

    ; Stop controller
    xor ax, ax
    out dx, ax

    ; Wait for halt
    mov ecx, 1000
.wait_halt:
    add dx, UHCI_USBSTS
    in ax, dx
    sub dx, UHCI_USBSTS
    test ax, UHCI_STS_HCH
    jnz .halted
    push rcx
    mov ecx, 1000
.delay1:
    pause
    loop .delay1
    pop rcx
    loop .wait_halt

.halted:
    ; Global reset
    mov ax, UHCI_CMD_GRESET
    out dx, ax

    ; Wait 10ms (approximately)
    mov ecx, 100000
.greset_delay:
    pause
    loop .greset_delay

    ; Clear global reset
    xor ax, ax
    out dx, ax

    ; Host controller reset
    mov ax, UHCI_CMD_HCRESET
    out dx, ax

    ; Wait for reset complete
    mov ecx, 1000
.wait_reset:
    in ax, dx
    test ax, UHCI_CMD_HCRESET
    jz .reset_complete
    push rcx
    mov ecx, 1000
.delay2:
    pause
    loop .delay2
    pop rcx
    loop .wait_reset

.reset_complete:
    ; Clear status
    add dx, UHCI_USBSTS
    mov ax, 0x3F            ; Clear all status bits
    out dx, ax
    sub dx, UHCI_USBSTS

    ; Setup frame list
    call uhci_setup_frame_list

.reset_done:
    pop rdx
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_START - Start the UHCI controller
; ════════════════════════════════════════════════════════════════════════════
uhci_start:
    push rax
    push rdx

    cmp byte [uhci_found], 0
    je .start_done

    mov dx, [uhci_io_base]

    ; Set frame list base address
    add dx, UHCI_FRBASEADD
    mov eax, uhci_frame_list
    out dx, eax
    sub dx, UHCI_FRBASEADD

    ; Set frame number to 0
    add dx, UHCI_FRNUM
    xor ax, ax
    out dx, ax
    sub dx, UHCI_FRNUM

    ; Set SOF modify to default
    add dx, UHCI_SOFMOD
    mov al, 64
    out dx, al
    sub dx, UHCI_SOFMOD

    ; Start controller with max packet size 64
    mov ax, UHCI_CMD_RS | UHCI_CMD_CF | UHCI_CMD_MAXP
    out dx, ax

    ; Wait a bit for controller to start
    mov ecx, 10000
.start_delay:
    pause
    loop .start_delay

.start_done:
    pop rdx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_SETUP_FRAME_LIST - Initialize the frame list
; ════════════════════════════════════════════════════════════════════════════
uhci_setup_frame_list:
    push rax
    push rcx
    push rdi

    ; Clear frame list (all entries point to terminate)
    mov rdi, uhci_frame_list
    mov eax, 0x00000001     ; T bit = 1 (terminate)
    mov ecx, UHCI_FRAME_LIST_ENTRIES
    rep stosd

    ; Clear TD and QH pools
    mov rdi, uhci_td_pool
    xor al, al
    mov ecx, UHCI_TD_POOL_SIZE * 32
    rep stosb

    mov rdi, uhci_qh_pool
    mov ecx, UHCI_QH_POOL_SIZE * 16
    rep stosb

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_READ_PORT - Read port status
; Input: EDI = port (1 or 2)
; Output: AX = port status
; ════════════════════════════════════════════════════════════════════════════
uhci_read_port:
    push rdx

    mov dx, [uhci_io_base]
    cmp edi, 1
    je .port1
    add dx, UHCI_PORTSC2
    jmp .read
.port1:
    add dx, UHCI_PORTSC1
.read:
    in ax, dx

    pop rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_WRITE_PORT - Write port status
; Input: EDI = port (1 or 2), AX = value
; ════════════════════════════════════════════════════════════════════════════
uhci_write_port:
    push rdx

    mov dx, [uhci_io_base]
    cmp edi, 1
    je .port1
    add dx, UHCI_PORTSC2
    jmp .write
.port1:
    add dx, UHCI_PORTSC1
.write:
    out dx, ax

    pop rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_PORT_RESET - Reset a USB port
; Input: EDI = port (1 or 2)
; ════════════════════════════════════════════════════════════════════════════
uhci_port_reset:
    push rax
    push rcx
    push rdx

    ; Read current port status
    call uhci_read_port
    or ax, UHCI_PORT_RESET
    call uhci_write_port

    ; Hold reset for 50ms
    mov ecx, 500000
.reset_delay:
    pause
    loop .reset_delay

    ; Clear reset
    call uhci_read_port
    and ax, ~UHCI_PORT_RESET
    call uhci_write_port

    ; Wait for reset to complete
    mov ecx, 100000
.wait_reset:
    pause
    loop .wait_reset

    ; Enable port
    call uhci_read_port
    or ax, UHCI_PORT_PED
    call uhci_write_port

    ; Clear status change bits
    call uhci_read_port
    or ax, UHCI_PORT_CSC | UHCI_PORT_PEDC
    call uhci_write_port

    pop rdx
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI INIT DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

uhci_found:     db 0
uhci_pci_bus:   db 0
uhci_pci_dev:   db 0
uhci_pci_func:  db 0
uhci_io_base:   dw 0
                dw 0    ; padding

; Pool sizes
UHCI_TD_POOL_SIZE   equ 32
UHCI_QH_POOL_SIZE   equ 16

; Frame list (must be 4KB aligned in real implementation)
; For simplicity, we just ensure page alignment
align 4096
uhci_frame_list:    times UHCI_FRAME_LIST_ENTRIES dd 0

; Transfer Descriptor pool (32 bytes each)
uhci_td_pool:       times UHCI_TD_POOL_SIZE * 32 db 0

; Queue Head pool (16 bytes each)
uhci_qh_pool:       times UHCI_QH_POOL_SIZE * 16 db 0
