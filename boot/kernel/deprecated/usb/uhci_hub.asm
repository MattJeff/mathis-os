; ════════════════════════════════════════════════════════════════════════════
; UHCI_HUB.ASM - UHCI Root Hub and Device Enumeration
; Handles port status, device connection, and enumeration
; ════════════════════════════════════════════════════════════════════════════

; USB Device Descriptor (18 bytes)
USB_DEV_DESC_SIZE       equ 18

; USB Configuration Descriptor (9 bytes)
USB_CFG_DESC_SIZE       equ 9

; ════════════════════════════════════════════════════════════════════════════
; UHCI_ENUMERATE_DEVICES - Enumerate all connected USB devices
; ════════════════════════════════════════════════════════════════════════════
uhci_enumerate_devices:
    push rax
    push rbx
    push rcx
    push rdi

    cmp byte [uhci_found], 0
    je .enum_done

    mov byte [usb_device_count], 0
    mov byte [usb_next_address], 1

    ; Check port 1
    mov edi, 1
    call uhci_check_port

    ; Check port 2
    mov edi, 2
    call uhci_check_port

.enum_done:
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_CHECK_PORT - Check and enumerate device on port
; Input: EDI = port number (1 or 2)
; ════════════════════════════════════════════════════════════════════════════
uhci_check_port:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov ebx, edi                ; Save port number

    ; Read port status
    call uhci_read_port

    ; Check if device connected
    test ax, UHCI_PORT_CCS
    jz .port_done

    ; Device connected - reset port
    mov edi, ebx
    call uhci_port_reset

    ; Wait for port to stabilize
    mov ecx, 100000
.stabilize:
    pause
    loop .stabilize

    ; Read port status again
    mov edi, ebx
    call uhci_read_port

    ; Check if still connected and enabled
    test ax, UHCI_PORT_CCS
    jz .port_done
    test ax, UHCI_PORT_PED
    jz .port_done

    ; Determine speed
    mov cl, 1                   ; Full speed
    test ax, UHCI_PORT_LSDA
    jz .full_speed
    xor cl, cl                  ; Low speed
.full_speed:
    mov [usb_temp_speed], cl

    ; Enumerate the device
    call uhci_enumerate_device

.port_done:
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_ENUMERATE_DEVICE - Enumerate a single USB device
; Uses address 0 initially, then assigns new address
; ════════════════════════════════════════════════════════════════════════════
uhci_enumerate_device:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Check if we have room for another device
    movzx eax, byte [usb_device_count]
    cmp eax, MAX_USB_DEVICES
    jae .enum_dev_done

    ; Calculate device entry pointer
    imul eax, USB_DEVICE_SIZE
    lea rbx, [usb_devices + rax]

    ; Initialize device entry at address 0
    mov byte [rbx], 1               ; Present
    mov byte [rbx + 1], 0           ; Address 0 initially
    mov al, [usb_temp_speed]
    mov [rbx + 2], al               ; Speed
    mov byte [rbx + 3], 8           ; Default max packet = 8

    ; Get device descriptor (first 8 bytes to learn max packet size)
    mov rdi, rbx                    ; Device
    lea rsi, [usb_get_desc_setup]   ; Setup packet
    mov word [rsi + 6], 8           ; Only get 8 bytes first
    lea rdx, [usb_enum_buffer]      ; Data buffer
    mov ecx, 8
    call uhci_control_transfer

    cmp eax, 0
    jl .enum_dev_error

    ; Update max packet size from descriptor byte 7
    mov al, [usb_enum_buffer + 7]
    test al, al
    jz .use_default_packet
    mov [rbx + 3], al
    jmp .set_address

.use_default_packet:
    mov byte [rbx + 3], 8

.set_address:
    ; Assign new address
    movzx eax, byte [usb_next_address]
    mov [rbx + 1], al               ; Store new address
    inc byte [usb_next_address]

    ; Send SET_ADDRESS request
    mov rdi, rbx
    mov byte [rbx + 1], 0           ; Use address 0 for this request
    lea rsi, [usb_set_addr_setup]
    mov [rsi + 2], al               ; New address in wValue
    mov byte [rsi + 3], 0
    xor rdx, rdx                    ; No data stage
    xor ecx, ecx
    call uhci_control_transfer

    cmp eax, 0
    jl .enum_dev_error

    ; Wait for device to process address change
    mov ecx, 50000
.addr_delay:
    pause
    loop .addr_delay

    ; Update device to use new address
    mov al, [usb_set_addr_setup + 2]
    mov [rbx + 1], al

    ; Get full device descriptor
    mov rdi, rbx
    lea rsi, [usb_get_desc_setup]
    mov word [rsi + 6], USB_DEV_DESC_SIZE
    lea rdx, [usb_enum_buffer]
    mov ecx, USB_DEV_DESC_SIZE
    call uhci_control_transfer

    cmp eax, 0
    jl .enum_dev_error

    ; Parse device descriptor
    ; Offset 8-9: idVendor
    mov ax, [usb_enum_buffer + 8]
    mov [rbx + 4], ax               ; Vendor ID

    ; Offset 10-11: idProduct
    mov ax, [usb_enum_buffer + 10]
    mov [rbx + 6], ax               ; Product ID

    ; Offset 4: bDeviceClass
    mov al, [usb_enum_buffer + 4]
    mov [rbx + 8], al               ; Class

    ; Offset 5: bDeviceSubClass
    mov al, [usb_enum_buffer + 5]
    mov [rbx + 9], al               ; Subclass

    ; Offset 6: bDeviceProtocol
    mov al, [usb_enum_buffer + 6]
    mov [rbx + 10], al              ; Protocol

    ; Offset 17: bNumConfigurations
    mov al, [usb_enum_buffer + 17]
    mov [rbx + 11], al              ; Num configs

    ; Get configuration descriptor
    mov rdi, rbx
    lea rsi, [usb_get_cfg_setup]
    mov word [rsi + 6], 64          ; Get up to 64 bytes
    lea rdx, [usb_enum_buffer]
    mov ecx, 64
    call uhci_control_transfer

    cmp eax, 0
    jl .enum_dev_error

    ; Set configuration (usually configuration 1)
    mov rdi, rbx
    lea rsi, [usb_set_cfg_setup]
    mov al, [usb_enum_buffer + 5]   ; bConfigurationValue
    mov [rsi + 2], al
    xor rdx, rdx
    xor ecx, ecx
    call uhci_control_transfer

    ; Device enumerated successfully
    inc byte [usb_device_count]
    jmp .enum_dev_done

.enum_dev_error:
    ; Clear device entry
    mov byte [rbx], 0

.enum_dev_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; USB_POLL_DEVICES - Poll for device connect/disconnect
; ════════════════════════════════════════════════════════════════════════════
usb_poll_devices:
    push rax
    push rdi

    cmp byte [uhci_found], 0
    je .poll_done

    ; Check port 1 for status change
    mov edi, 1
    call uhci_read_port
    test ax, UHCI_PORT_CSC
    jz .check_port2

    ; Clear status change
    or ax, UHCI_PORT_CSC
    mov edi, 1
    call uhci_write_port

    ; Re-enumerate
    call uhci_enumerate_devices
    jmp .poll_done

.check_port2:
    mov edi, 2
    call uhci_read_port
    test ax, UHCI_PORT_CSC
    jz .poll_done

    or ax, UHCI_PORT_CSC
    mov edi, 2
    call uhci_write_port

    call uhci_enumerate_devices

.poll_done:
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; USB_GET_STRING - Get USB string descriptor
; Input: RDI = device, ESI = string index, RDX = buffer, ECX = max length
; Output: EAX = string length or -1
; ════════════════════════════════════════════════════════════════════════════
usb_get_string:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov r8, rdx                     ; Save buffer

    ; Setup GET_DESCRIPTOR for string
    lea rsi, [usb_get_string_setup]
    mov byte [rsi + 3], 0x03        ; Descriptor type = string
    mov [rsi + 2], sil              ; String index (from ESI)
    mov [rsi + 6], cx               ; Max length

    mov rdx, r8
    call uhci_control_transfer

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; HUB DATA - Setup packets and buffers
; ════════════════════════════════════════════════════════════════════════════
align 8

usb_next_address:   db 1
usb_temp_speed:     db 0
                    dw 0    ; padding

; GET_DESCRIPTOR (Device) setup packet
usb_get_desc_setup:
    db 0x80                 ; bmRequestType: Device-to-host, Standard, Device
    db USB_REQ_GET_DESCRIPTOR
    dw 0x0100               ; wValue: Descriptor type (device=1) << 8 | index
    dw 0x0000               ; wIndex: 0
    dw USB_DEV_DESC_SIZE    ; wLength

; GET_DESCRIPTOR (Config) setup packet
usb_get_cfg_setup:
    db 0x80
    db USB_REQ_GET_DESCRIPTOR
    dw 0x0200               ; Configuration descriptor
    dw 0x0000
    dw USB_CFG_DESC_SIZE

; SET_ADDRESS setup packet
usb_set_addr_setup:
    db 0x00                 ; bmRequestType: Host-to-device, Standard, Device
    db USB_REQ_SET_ADDRESS
    dw 0x0000               ; wValue: Address (filled in)
    dw 0x0000               ; wIndex: 0
    dw 0x0000               ; wLength: 0

; SET_CONFIGURATION setup packet
usb_set_cfg_setup:
    db 0x00
    db USB_REQ_SET_CONFIG
    dw 0x0001               ; wValue: Configuration value
    dw 0x0000
    dw 0x0000

; GET_DESCRIPTOR (String) setup packet
usb_get_string_setup:
    db 0x80
    db USB_REQ_GET_DESCRIPTOR
    dw 0x0300               ; String descriptor
    dw 0x0409               ; Language ID (English US)
    dw 0x00FF               ; Max length

; Enumeration buffer
usb_enum_buffer:    times 256 db 0
