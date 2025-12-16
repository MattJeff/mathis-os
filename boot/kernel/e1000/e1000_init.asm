; ════════════════════════════════════════════════════════════════════════════
; E1000 NETWORK DRIVER - INITIALIZATION (FIXED)
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
pci_device:         dd 0            ; PCI device number

; ════════════════════════════════════════════════════════════════════════════
; E1000_INIT - Initialize E1000 network card
; Output: CF set on error
; DEBUG VERSION - Testing step by step
; ════════════════════════════════════════════════════════════════════════════
e1000_init:
    ; Full E1000 initialization - MMIO region is now mapped in page tables
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    call e1000_pci_scan
    jc .not_found

    ; E1000 found - validate MMIO base is non-zero
    mov rax, [e1000_mmio_base]
    test rax, rax
    jz .not_found

    ; Verify MMIO is in mapped region (0xFE000000-0xFFFFFFFF)
    cmp rax, 0xFE000000
    jb .not_found
    cmp rax, 0xFFFFFFFF
    ja .not_found

    call e1000_pci_enable
    call e1000_reset
    call e1000_read_mac
    call e1000_rx_init
    call e1000_tx_init
    call e1000_enable_irq
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

; Original init code (disabled for debugging)
e1000_init_full:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; DEBUG: Red pixel = starting init
    mov byte [0xA0000], 4

    ; Step 1: Scan PCI for E1000
    call e1000_pci_scan
    jc .not_found

    ; DEBUG: Yellow pixel = PCI scan success
    mov byte [0xA0001], 14

    ; Validate MMIO base
    mov rax, [e1000_mmio_base]
    test rax, rax
    jz .not_found                   ; No valid MMIO base

    ; DEBUG: Light blue = MMIO valid
    mov byte [0xA0002], 11

    ; Step 2: Enable PCI bus mastering
    call e1000_pci_enable

    ; DEBUG: Purple = PCI enabled
    mov byte [0xA0003], 5

    ; Step 3: Reset device
    call e1000_reset

    ; DEBUG: Cyan = Reset done
    mov byte [0xA0004], 3

    ; Step 4: Read MAC address
    call e1000_read_mac

    ; DEBUG: Magenta = MAC read
    mov byte [0xA0005], 13

    ; Step 5: Initialize RX
    call e1000_rx_init

    ; DEBUG: Orange = RX init done
    mov byte [0xA0006], 6

    ; Step 6: Initialize TX
    call e1000_tx_init

    ; DEBUG: Light green = TX init done
    mov byte [0xA0007], 10

    ; Step 7: Enable interrupts
    call e1000_enable_irq

    ; Step 8: Start receiving
    call e1000_start

    ; DEBUG: Bright green = ALL SUCCESS!
    mov byte [0xA0008], 10
    mov byte [0xA0009], 10
    mov byte [0xA000A], 10

    mov byte [e1000_found], 1
    clc
    jmp .done

.not_found:
    ; DEBUG: Gray = not found (this is OK if no E1000 in QEMU)
    mov byte [0xA0000], 8
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
    xor ebx, ebx                    ; device = 0

.scan_device:
    cmp ebx, 32
    jae .not_found                  ; Use unsigned comparison!

    ; Build PCI address: 0x80000000 | (bus << 16) | (dev << 11) | (func << 8) | reg
    mov eax, 0x80000000
    mov ecx, ebx
    shl ecx, 11                     ; device << 11
    or eax, ecx
    ; bus = 0, func = 0, reg = 0 (vendor/device)

    ; Read vendor/device ID
    mov dx, PCI_CONFIG_ADDR
    out dx, eax
    mov dx, PCI_CONFIG_DATA
    in eax, dx

    ; Check for no device (vendor = 0xFFFF)
    cmp ax, 0xFFFF
    je .next_device

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

    ; Check if BAR0 is valid (not 0 or 0xFFFFFFFF)
    cmp eax, 0
    je .not_found
    cmp eax, 0xFFFFFFFF
    je .not_found

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

    ; Write back - need to write address first, then data
    push rax                        ; Save the command value
    mov eax, 0x80000000
    mov ecx, [pci_device]
    shl ecx, 11
    or eax, ecx
    or eax, PCI_COMMAND
    mov dx, PCI_CONFIG_ADDR
    out dx, eax
    pop rax                         ; Restore command value
    mov dx, PCI_CONFIG_DATA
    out dx, eax

    pop rdx
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_WRITE_REG - Write to E1000 register (with safety check)
; Input: ECX = register offset, EAX = value
; ════════════════════════════════════════════════════════════════════════════
e1000_write_reg:
    push rdx
    mov rdx, [e1000_mmio_base]
    test rdx, rdx
    jz .skip                        ; Skip if no valid MMIO base
    add rdx, rcx
    mov [rdx], eax
.skip:
    pop rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_READ_REG - Read from E1000 register (with safety check)
; Input: ECX = register offset
; Output: EAX = value (0xFFFFFFFF if no device)
; ════════════════════════════════════════════════════════════════════════════
e1000_read_reg:
    push rdx
    mov rdx, [e1000_mmio_base]
    test rdx, rdx
    jz .no_device
    add rdx, rcx
    mov eax, [rdx]
    jmp .done
.no_device:
    mov eax, 0xFFFFFFFF
.done:
    pop rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_RESET - Reset the E1000 device (with timeout)
; ════════════════════════════════════════════════════════════════════════════
e1000_reset:
    push rax
    push rcx
    push rdx

    ; Check MMIO base is valid
    mov rax, [e1000_mmio_base]
    test rax, rax
    jz .done

    ; Set RST bit in CTRL register
    mov ecx, E1000_CTRL
    call e1000_read_reg
    or eax, E1000_CTRL_RST
    call e1000_write_reg

    ; Wait for reset to complete (poll until RST bit clears)
    mov edx, 100000                 ; Timeout counter
.wait_reset:
    dec edx
    jz .reset_done                  ; Timeout - continue anyway

    mov ecx, E1000_CTRL
    call e1000_read_reg
    test eax, E1000_CTRL_RST
    jnz .wait_reset

.reset_done:
    ; Small delay after reset
    mov ecx, 10000
.delay:
    pause                           ; CPU hint for spin-wait
    dec ecx
    jnz .delay

    ; Disable all interrupts initially
    mov ecx, E1000_IMC
    mov eax, 0xFFFFFFFF
    call e1000_write_reg

.done:
    pop rdx
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_READ_MAC - Read MAC address from registers
; ════════════════════════════════════════════════════════════════════════════
e1000_read_mac:
    push rax
    push rbx
    push rcx
    push rdi

    ; Check MMIO base is valid
    mov rax, [e1000_mmio_base]
    test rax, rax
    jz .mac_done

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

    ; If MAC is all zeros or all FFs, try EEPROM
    mov rdi, e1000_mac
    xor eax, eax
    mov ecx, 6
    repe scasb
    jnz .mac_done                   ; Non-zero MAC found

    ; Read from EEPROM (words 0, 1, 2)
    xor ebx, ebx                    ; word index
.read_eeprom:
    cmp ebx, 3
    jae .mac_done

    ; EERD: start read, address in bits 8-15
    mov eax, ebx
    shl eax, 8
    or eax, 1                       ; Start bit
    mov ecx, E1000_EERD
    call e1000_write_reg

    ; Wait for done with timeout
    mov edx, 10000
.wait_eeprom:
    dec edx
    jz .eeprom_timeout

    mov ecx, E1000_EERD
    call e1000_read_reg
    test eax, 0x10                  ; Done bit
    jz .wait_eeprom

    ; Data in bits 16-31
    shr eax, 16
    mov [e1000_mac + rbx*2], al
    shr eax, 8
    mov [e1000_mac + rbx*2 + 1], al

.eeprom_timeout:
    inc ebx
    jmp .read_eeprom

.mac_done:
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
