; ════════════════════════════════════════════════════════════════════════════
; E1000 NETWORK DRIVER - INITIALIZATION
; PCI enumeration, MMIO setup, device reset, MAC address
; ════════════════════════════════════════════════════════════════════════════

%include "e1000/e1000_regs.asm"

; PCI Configuration Space Ports
PCI_CONFIG_ADDR     equ 0xCF8
PCI_CONFIG_DATA     equ 0xCFC

; PCI Config Space Offsets
PCI_VENDOR_ID       equ 0x00
PCI_DEVICE_ID       equ 0x02
PCI_COMMAND         equ 0x04
PCI_STATUS          equ 0x06
PCI_BAR0            equ 0x10
PCI_IRQ_LINE        equ 0x3C

; PCI Command bits
PCI_CMD_IO          equ (1 << 0)    ; I/O Space Enable
PCI_CMD_MEMORY      equ (1 << 1)    ; Memory Space Enable
PCI_CMD_MASTER      equ (1 << 2)    ; Bus Master Enable

; ════════════════════════════════════════════════════════════════════════════
; DRIVER STATE (flat binary - no sections)
; ════════════════════════════════════════════════════════════════════════════
e1000_mmio_base:    dq 0            ; MMIO base address
e1000_irq:          db 0            ; IRQ line
e1000_mac:          times 6 db 0    ; MAC address
e1000_found:        db 0            ; 1 if E1000 found
e1000_rx_cur:       dd 0            ; Current RX descriptor index
e1000_tx_cur:       dd 0            ; Current TX descriptor index

; ════════════════════════════════════════════════════════════════════════════
; E1000_INIT - Initialize E1000 network card
; Output: CF set on error
; ════════════════════════════════════════════════════════════════════════════
e1000_init:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Step 1: Scan PCI for E1000
    call e1000_pci_scan
    jc .not_found

    ; Step 2: Enable PCI bus mastering
    call e1000_pci_enable

    ; Step 3: Reset device
    call e1000_reset

    ; Step 4: Read MAC address
    call e1000_read_mac

    ; Step 5: Initialize RX
    call e1000_rx_init

    ; Step 6: Initialize TX
    call e1000_tx_init

    ; Step 7: Enable interrupts
    call e1000_enable_irq

    ; Step 8: Start receiving
    call e1000_start

    mov byte [e1000_found], 1
    clc
    jmp .done

.not_found:
    mov byte [e1000_found], 0
    stc

.done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_PCI_SCAN - Find E1000 on PCI bus
; Output: CF set if not found, e1000_mmio_base set if found
; ════════════════════════════════════════════════════════════════════════════
e1000_pci_scan:
    push rax
    push rbx
    push rcx
    push rdx

    ; Scan all PCI devices (bus 0, devices 0-31, function 0)
    xor ebx, ebx                    ; bus = 0

.scan_device:
    cmp ebx, 32
    jge .not_found

    ; Build PCI address: 0x80000000 | (bus << 16) | (dev << 11) | (func << 8) | reg
    mov eax, 0x80000000
    mov ecx, ebx
    shl ecx, 11                     ; device << 11
    or eax, ecx
    ; func = 0, reg = 0 (vendor/device)

    ; Read vendor/device ID
    mov dx, PCI_CONFIG_ADDR
    out dx, eax
    mov dx, PCI_CONFIG_DATA
    in eax, dx

    ; Check for E1000 (vendor=0x8086, device=0x100E)
    cmp ax, E1000_VENDOR_ID
    jne .next_device
    shr eax, 16
    cmp ax, E1000_DEVICE_ID
    je .found

.next_device:
    inc ebx
    jmp .scan_device

.found:
    ; Save device number for later
    mov [pci_device], ebx

    ; Read BAR0 (MMIO base address)
    mov eax, 0x80000000
    mov ecx, ebx
    shl ecx, 11
    or eax, ecx
    or eax, PCI_BAR0                ; offset 0x10

    mov dx, PCI_CONFIG_ADDR
    out dx, eax
    mov dx, PCI_CONFIG_DATA
    in eax, dx

    ; Mask low bits (BAR type indicator)
    and eax, 0xFFFFFFF0
    mov [e1000_mmio_base], rax

    ; Read IRQ line
    mov eax, 0x80000000
    mov ecx, ebx
    shl ecx, 11
    or eax, ecx
    or eax, PCI_IRQ_LINE

    mov dx, PCI_CONFIG_ADDR
    out dx, eax
    mov dx, PCI_CONFIG_DATA
    in eax, dx
    mov [e1000_irq], al

    clc
    jmp .done

.not_found:
    stc

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

pci_device: dd 0

; ════════════════════════════════════════════════════════════════════════════
; E1000_PCI_ENABLE - Enable bus mastering and memory space
; ════════════════════════════════════════════════════════════════════════════
e1000_pci_enable:
    push rax
    push rcx
    push rdx

    ; Read current PCI command
    mov eax, 0x80000000
    mov ecx, [pci_device]
    shl ecx, 11
    or eax, ecx
    or eax, PCI_COMMAND

    mov dx, PCI_CONFIG_ADDR
    out dx, eax
    mov dx, PCI_CONFIG_DATA
    in eax, dx

    ; Enable memory space + bus master
    or eax, PCI_CMD_MEMORY | PCI_CMD_MASTER

    ; Write back
    push rax
    mov eax, 0x80000000
    mov ecx, [pci_device]
    shl ecx, 11
    or eax, ecx
    or eax, PCI_COMMAND
    mov dx, PCI_CONFIG_ADDR
    out dx, eax
    pop rax
    mov dx, PCI_CONFIG_DATA
    out dx, eax

    pop rdx
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_WRITE_REG - Write to E1000 register
; Input: ECX = register offset, EAX = value
; ════════════════════════════════════════════════════════════════════════════
e1000_write_reg:
    push rdx
    mov rdx, [e1000_mmio_base]
    add rdx, rcx
    mov [rdx], eax
    pop rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_READ_REG - Read from E1000 register
; Input: ECX = register offset
; Output: EAX = value
; ════════════════════════════════════════════════════════════════════════════
e1000_read_reg:
    push rdx
    mov rdx, [e1000_mmio_base]
    add rdx, rcx
    mov eax, [rdx]
    pop rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_RESET - Reset the E1000 device
; ════════════════════════════════════════════════════════════════════════════
e1000_reset:
    push rax
    push rcx

    ; Set RST bit in CTRL register
    mov ecx, E1000_CTRL
    call e1000_read_reg
    or eax, E1000_CTRL_RST
    call e1000_write_reg

    ; Wait for reset to complete (poll until RST bit clears)
    mov ecx, 100000
.wait_reset:
    push rcx
    mov ecx, E1000_CTRL
    call e1000_read_reg
    pop rcx
    test eax, E1000_CTRL_RST
    jz .reset_done
    dec ecx
    jnz .wait_reset

.reset_done:
    ; Small delay after reset
    mov ecx, 10000
.delay:
    nop
    dec ecx
    jnz .delay

    ; Disable all interrupts initially
    mov ecx, E1000_IMC
    mov eax, 0xFFFFFFFF
    call e1000_write_reg

    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_READ_MAC - Read MAC address from EEPROM or registers
; ════════════════════════════════════════════════════════════════════════════
e1000_read_mac:
    push rax
    push rbx
    push rcx
    push rdi

    ; Try reading from RAL0/RAH0 (works on QEMU)
    mov ecx, E1000_RAL0
    call e1000_read_reg
    mov [e1000_mac], al
    shr eax, 8
    mov [e1000_mac + 1], al
    shr eax, 8
    mov [e1000_mac + 2], al
    shr eax, 8
    mov [e1000_mac + 3], al

    mov ecx, E1000_RAH0
    call e1000_read_reg
    mov [e1000_mac + 4], al
    shr eax, 8
    mov [e1000_mac + 5], al

    ; If MAC is all zeros, try EEPROM
    mov rdi, e1000_mac
    xor eax, eax
    mov ecx, 6
    repe scasb
    jnz .mac_valid

    ; Read from EEPROM (words 0, 1, 2)
    mov ebx, 0
.read_eeprom:
    cmp ebx, 3
    jge .mac_valid

    ; EERD: start read, address in bits 8-15
    mov eax, ebx
    shl eax, 8
    or eax, 1                       ; Start bit
    mov ecx, E1000_EERD
    call e1000_write_reg

    ; Wait for done
    mov ecx, 10000
.wait_eeprom:
    push rcx
    mov ecx, E1000_EERD
    call e1000_read_reg
    pop rcx
    test eax, 0x10                  ; Done bit
    jnz .eeprom_done
    dec ecx
    jnz .wait_eeprom

.eeprom_done:
    ; Data in bits 16-31
    shr eax, 16
    mov [e1000_mac + rbx*2], al
    shr eax, 8
    mov [e1000_mac + rbx*2 + 1], al

    inc ebx
    jmp .read_eeprom

.mac_valid:
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_ENABLE_IRQ - Enable receive interrupts
; ════════════════════════════════════════════════════════════════════════════
e1000_enable_irq:
    push rax
    push rcx

    ; Enable RX timer interrupt and link status change
    mov ecx, E1000_IMS
    mov eax, E1000_ICR_RXT0 | E1000_ICR_LSC | E1000_ICR_RXDMT0
    call e1000_write_reg

    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_START - Start the receiver
; ════════════════════════════════════════════════════════════════════════════
e1000_start:
    push rax
    push rcx

    ; Set link up
    mov ecx, E1000_CTRL
    call e1000_read_reg
    or eax, E1000_CTRL_SLU
    call e1000_write_reg

    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_GET_MAC - Get MAC address
; Input: RDI = buffer (6 bytes)
; ════════════════════════════════════════════════════════════════════════════
e1000_get_mac:
    push rsi
    push rcx
    mov rsi, e1000_mac
    mov rcx, 6
    rep movsb
    pop rcx
    pop rsi
    ret
