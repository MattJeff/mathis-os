; ════════════════════════════════════════════════════════════════════════════
; UHCI.ASM - Universal Host Controller Interface (USB 1.1)
; Intel's USB 1.1 Host Controller specification
; ════════════════════════════════════════════════════════════════════════════
; UHCI uses I/O port-mapped registers and a frame list for scheduling
; Transfer types: Control, Bulk, Interrupt, Isochronous
; ════════════════════════════════════════════════════════════════════════════

; Include UHCI submodules
%include "usb/uhci_init.asm"
%include "usb/uhci_transfer.asm"
%include "usb/uhci_hub.asm"

; ════════════════════════════════════════════════════════════════════════════
; HIGH-LEVEL USB API
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; USB_INIT - Initialize USB subsystem
; Output: CF set if no USB controller found
; ────────────────────────────────────────────────────────────────────────────
usb_init:
    push rax
    push rbx

    ; Initialize UHCI controller
    call uhci_init
    jc .usb_init_failed

    ; Reset controller and start frame processing
    call uhci_reset
    call uhci_start

    ; Enumerate connected devices
    call uhci_enumerate_devices

    mov byte [usb_initialized], 1
    clc
    jmp .usb_init_done

.usb_init_failed:
    mov byte [usb_initialized], 0
    stc

.usb_init_done:
    pop rbx
    pop rax
    ret

; ────────────────────────────────────────────────────────────────────────────
; USB_STATUS - Check if USB is available
; Output: AL = 1 if USB available, 0 otherwise
; ────────────────────────────────────────────────────────────────────────────
usb_status:
    mov al, [usb_initialized]
    ret

; ────────────────────────────────────────────────────────────────────────────
; USB_GET_DEVICE_COUNT - Get number of connected devices
; Output: EAX = device count
; ────────────────────────────────────────────────────────────────────────────
usb_get_device_count:
    movzx eax, byte [usb_device_count]
    ret

; ────────────────────────────────────────────────────────────────────────────
; USB_GET_DEVICE_INFO - Get device information
; Input: EDI = device index
; Output: RAX = device descriptor pointer (or 0 if invalid)
; ────────────────────────────────────────────────────────────────────────────
usb_get_device_info:
    cmp edi, MAX_USB_DEVICES
    jae .invalid_device

    ; Calculate device entry offset
    mov eax, edi
    imul eax, USB_DEVICE_SIZE
    lea rax, [usb_devices + rax]

    ; Check if device is present
    cmp byte [rax], 0
    je .invalid_device

    ret

.invalid_device:
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; USB_CONTROL_TRANSFER - Perform control transfer
; Input: RDI = device, RSI = setup packet, RDX = data buffer, ECX = data length
; Output: EAX = bytes transferred or -1 on error
; ────────────────────────────────────────────────────────────────────────────
usb_control_transfer:
    call uhci_control_transfer
    ret

; ────────────────────────────────────────────────────────────────────────────
; USB_BULK_TRANSFER - Perform bulk transfer
; Input: RDI = device, ESI = endpoint, RDX = buffer, ECX = length
; Output: EAX = bytes transferred or -1 on error
; ────────────────────────────────────────────────────────────────────────────
usb_bulk_transfer:
    call uhci_bulk_transfer
    ret

; ════════════════════════════════════════════════════════════════════════════
; USB CONSTANTS
; ════════════════════════════════════════════════════════════════════════════

; USB Request Types
USB_REQ_GET_STATUS      equ 0x00
USB_REQ_CLEAR_FEATURE   equ 0x01
USB_REQ_SET_FEATURE     equ 0x03
USB_REQ_SET_ADDRESS     equ 0x05
USB_REQ_GET_DESCRIPTOR  equ 0x06
USB_REQ_SET_DESCRIPTOR  equ 0x07
USB_REQ_GET_CONFIG      equ 0x08
USB_REQ_SET_CONFIG      equ 0x09

; USB Descriptor Types
USB_DESC_DEVICE         equ 0x01
USB_DESC_CONFIG         equ 0x02
USB_DESC_STRING         equ 0x03
USB_DESC_INTERFACE      equ 0x04
USB_DESC_ENDPOINT       equ 0x05

; USB Class Codes
USB_CLASS_HID           equ 0x03
USB_CLASS_MASS_STORAGE  equ 0x08
USB_CLASS_HUB           equ 0x09

; Device limits
MAX_USB_DEVICES         equ 8
USB_DEVICE_SIZE         equ 64

; ════════════════════════════════════════════════════════════════════════════
; USB DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

usb_initialized:    db 0
usb_device_count:   db 0
                    dw 0    ; padding

; USB devices table
; Structure per device (64 bytes):
;   +0:  present (1 byte)
;   +1:  address (1 byte)
;   +2:  speed (1 byte) - 0=low, 1=full
;   +3:  max_packet (1 byte)
;   +4:  vendor_id (2 bytes)
;   +6:  product_id (2 bytes)
;   +8:  class (1 byte)
;   +9:  subclass (1 byte)
;   +10: protocol (1 byte)
;   +11: num_configs (1 byte)
;   +12-63: reserved
usb_devices:    times MAX_USB_DEVICES * USB_DEVICE_SIZE db 0

; Setup packet buffer
usb_setup_packet:   times 8 db 0

; Data buffer for control transfers
usb_data_buffer:    times 256 db 0
