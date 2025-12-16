; ════════════════════════════════════════════════════════════════════════════
; UHCI_TRANSFER.ASM - UHCI Transfer Descriptors and USB Transfers
; Implements Control and Bulk transfers using TDs and QHs
; ════════════════════════════════════════════════════════════════════════════

; Transfer Descriptor (TD) structure (32 bytes, 16-byte aligned)
; +0:  Link Pointer (4 bytes) - Vf=0, Q=0, T=terminate
; +4:  Control and Status (4 bytes)
; +8:  Token (4 bytes)
; +12: Buffer Pointer (4 bytes)
; +16: Software use (16 bytes)

; TD Link Pointer bits
TD_LP_TERMINATE     equ 0x0001  ; No more TDs
TD_LP_QH            equ 0x0002  ; Link points to QH (not TD)
TD_LP_DEPTH         equ 0x0004  ; Depth-first (not breadth)

; TD Control and Status bits
TD_CS_ACTLEN_MASK   equ 0x07FF  ; Actual length (bits 0-10)
TD_CS_BITSTUFF      equ (1 << 17)   ; Bitstuff error
TD_CS_CRC           equ (1 << 18)   ; CRC/Timeout error
TD_CS_NAK           equ (1 << 19)   ; NAK received
TD_CS_BABBLE        equ (1 << 20)   ; Babble detected
TD_CS_DBERR         equ (1 << 21)   ; Data buffer error
TD_CS_STALLED       equ (1 << 22)   ; Stalled
TD_CS_ACTIVE        equ (1 << 23)   ; Active
TD_CS_IOC           equ (1 << 24)   ; Interrupt on Complete
TD_CS_IOS           equ (1 << 25)   ; Isochronous Select
TD_CS_LS            equ (1 << 26)   ; Low Speed Device
TD_CS_ERRCNT_SHIFT  equ 27          ; Error count (bits 27-28)
TD_CS_SPD           equ (1 << 29)   ; Short Packet Detect

; TD Token bits
TD_TOKEN_PID_MASK   equ 0xFF        ; Packet ID
TD_TOKEN_ADDR_SHIFT equ 8           ; Device address (bits 8-14)
TD_TOKEN_ADDR_MASK  equ 0x7F00
TD_TOKEN_EP_SHIFT   equ 15          ; Endpoint (bits 15-18)
TD_TOKEN_EP_MASK    equ 0x78000
TD_TOKEN_TOGGLE     equ (1 << 19)   ; Data toggle
TD_TOKEN_MAXLEN_SHIFT equ 21        ; Max length (bits 21-31)

; PID values
USB_PID_OUT         equ 0xE1
USB_PID_IN          equ 0x69
USB_PID_SETUP       equ 0x2D

; Queue Head (QH) structure (16 bytes, 16-byte aligned)
; +0: Horizontal Link Pointer (4 bytes)
; +4: Element Link Pointer (4 bytes)
; +8: Reserved/Software use (8 bytes)

; ════════════════════════════════════════════════════════════════════════════
; UHCI_ALLOC_TD - Allocate a Transfer Descriptor
; Output: RAX = TD pointer or 0
; ════════════════════════════════════════════════════════════════════════════
uhci_alloc_td:
    push rbx
    push rcx

    mov rbx, uhci_td_pool
    mov ecx, UHCI_TD_POOL_SIZE

.find_free:
    ; Check if TD is free (link = 0 and not active)
    mov eax, [rbx + 4]          ; Control/Status
    test eax, TD_CS_ACTIVE
    jnz .next_td

    ; Found free TD
    mov rax, rbx

    ; Clear it
    push rdi
    push rcx
    mov rdi, rbx
    xor eax, eax
    mov ecx, 8                  ; 8 dwords = 32 bytes
    rep stosd
    pop rcx
    pop rdi

    mov rax, rbx
    jmp .alloc_done

.next_td:
    add rbx, 32
    dec ecx
    jnz .find_free

    xor eax, eax                ; No free TD

.alloc_done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_FREE_TD - Free a Transfer Descriptor
; Input: RDI = TD pointer
; ════════════════════════════════════════════════════════════════════════════
uhci_free_td:
    push rax
    push rcx
    push rdi

    ; Clear the TD
    xor eax, eax
    mov ecx, 8
    rep stosd

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_SETUP_TD - Setup a Transfer Descriptor
; Input: RDI = TD, ESI = control/status, EDX = token, R8 = buffer
; ════════════════════════════════════════════════════════════════════════════
uhci_setup_td:
    mov dword [rdi], TD_LP_TERMINATE    ; Link = terminate
    mov [rdi + 4], esi                  ; Control/Status
    mov [rdi + 8], edx                  ; Token
    mov [rdi + 12], r8d                 ; Buffer pointer
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_ALLOC_QH - Allocate a Queue Head
; Output: RAX = QH pointer or 0
; ════════════════════════════════════════════════════════════════════════════
uhci_alloc_qh:
    push rbx
    push rcx

    mov rbx, uhci_qh_pool
    mov ecx, UHCI_QH_POOL_SIZE

.find_free:
    ; Check if QH is free
    cmp dword [rbx], 0
    je .found_free
    cmp dword [rbx], TD_LP_TERMINATE
    je .found_free

    add rbx, 16
    dec ecx
    jnz .find_free

    xor eax, eax
    jmp .qh_done

.found_free:
    ; Initialize QH
    mov dword [rbx], TD_LP_TERMINATE        ; H-Link = terminate
    mov dword [rbx + 4], TD_LP_TERMINATE    ; Element = terminate
    mov rax, rbx

.qh_done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_CONTROL_TRANSFER - Perform a control transfer
; Input: RDI = device, RSI = setup packet, RDX = data buffer, ECX = data length
; Output: EAX = bytes transferred or -1
; ════════════════════════════════════════════════════════════════════════════
uhci_control_transfer:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13

    mov r10, rdi                ; Device
    mov r11, rsi                ; Setup packet
    mov r12, rdx                ; Data buffer
    mov r13d, ecx               ; Data length

    ; Get device address
    movzx r8d, byte [r10 + 1]   ; Address at offset 1
    movzx r9d, byte [r10 + 3]   ; Max packet size at offset 3
    test r9d, r9d
    jnz .have_max_packet
    mov r9d, 8                  ; Default max packet
.have_max_packet:

    ; Allocate QH
    call uhci_alloc_qh
    test rax, rax
    jz .control_error
    mov rbx, rax                ; RBX = QH

    ; === SETUP Stage ===
    call uhci_alloc_td
    test rax, rax
    jz .control_error
    mov rdi, rax                ; RDI = Setup TD

    ; Setup TD: control/status
    mov esi, TD_CS_ACTIVE | (3 << TD_CS_ERRCNT_SHIFT)
    cmp byte [r10 + 2], 0       ; Check speed
    jne .setup_full_speed
    or esi, TD_CS_LS            ; Low speed
.setup_full_speed:

    ; Setup TD: token (SETUP, device addr, endpoint 0, 8 bytes)
    mov edx, USB_PID_SETUP
    mov eax, r8d
    shl eax, TD_TOKEN_ADDR_SHIFT
    or edx, eax
    mov eax, 7                  ; Max length = 8 - 1
    shl eax, TD_TOKEN_MAXLEN_SHIFT
    or edx, eax

    ; Buffer = setup packet (copy to aligned buffer)
    mov r8, uhci_setup_buffer
    push rdi
    push rcx
    mov rdi, r8
    mov rsi, r11
    mov ecx, 8
    rep movsb
    pop rcx
    pop rdi
    mov rsi, r11                ; Restore

    mov r8d, uhci_setup_buffer
    and r8d, 0xFFFFFFFF

    call uhci_setup_td

    ; Link Setup TD to QH
    mov eax, edi
    and eax, 0xFFFFFFFF
    mov [rbx + 4], eax

    ; === DATA Stage (if any) ===
    test r13d, r13d
    jz .no_data_stage

    ; Check direction (bit 7 of bmRequestType)
    mov al, [r11]
    test al, 0x80
    jnz .data_in
    jmp .data_out

.data_in:
    ; Allocate Data IN TD
    push rdi                    ; Save setup TD
    call uhci_alloc_td
    test rax, rax
    jz .control_error_cleanup
    mov r14, rax                ; R14 = Data TD

    ; Link setup TD -> data TD
    pop rdi
    mov eax, r14d
    and eax, 0xFFFFFFFF
    mov [rdi], eax

    ; Setup Data IN TD
    mov rdi, r14
    mov esi, TD_CS_ACTIVE | TD_CS_SPD | (3 << TD_CS_ERRCNT_SHIFT)
    cmp byte [r10 + 2], 0
    jne .data_in_full
    or esi, TD_CS_LS
.data_in_full:

    ; Token: IN, address, endpoint 0, toggle 1, length
    mov edx, USB_PID_IN
    mov eax, r8d
    shl eax, TD_TOKEN_ADDR_SHIFT
    or edx, eax
    or edx, TD_TOKEN_TOGGLE     ; Data toggle = 1
    mov eax, r13d
    dec eax                     ; Max length = actual - 1
    shl eax, TD_TOKEN_MAXLEN_SHIFT
    or edx, eax

    mov r8d, uhci_data_buffer
    call uhci_setup_td
    jmp .status_stage

.data_out:
    ; Copy data to buffer
    push rdi
    push rcx
    mov rdi, uhci_data_buffer
    mov rsi, r12
    mov ecx, r13d
    rep movsb
    pop rcx
    pop rdi

    ; Allocate Data OUT TD
    push rdi
    call uhci_alloc_td
    test rax, rax
    jz .control_error_cleanup
    mov r14, rax

    pop rdi
    mov eax, r14d
    mov [rdi], eax

    mov rdi, r14
    mov esi, TD_CS_ACTIVE | (3 << TD_CS_ERRCNT_SHIFT)
    cmp byte [r10 + 2], 0
    jne .data_out_full
    or esi, TD_CS_LS
.data_out_full:

    mov edx, USB_PID_OUT
    mov eax, r8d
    shl eax, TD_TOKEN_ADDR_SHIFT
    or edx, eax
    or edx, TD_TOKEN_TOGGLE
    mov eax, r13d
    dec eax
    shl eax, TD_TOKEN_MAXLEN_SHIFT
    or edx, eax

    mov r8d, uhci_data_buffer
    call uhci_setup_td
    jmp .status_stage

.no_data_stage:
    mov r14, rdi                ; No data TD, use setup TD

.status_stage:
    ; Allocate Status TD
    push rdi
    call uhci_alloc_td
    test rax, rax
    jz .control_error_cleanup
    mov r15, rax                ; R15 = Status TD

    ; Link data/setup TD -> status TD
    pop rdi
    cmp r13d, 0
    je .link_setup_to_status
    mov rdi, r14
.link_setup_to_status:
    mov eax, r15d
    mov [rdi], eax

    ; Setup Status TD (opposite direction of data, or IN if no data)
    mov rdi, r15
    mov esi, TD_CS_ACTIVE | TD_CS_IOC | (3 << TD_CS_ERRCNT_SHIFT)
    cmp byte [r10 + 2], 0
    jne .status_full
    or esi, TD_CS_LS
.status_full:

    ; Status direction: OUT if data was IN, IN if data was OUT or no data
    mov al, [r11]
    test al, 0x80
    jz .status_in
    mov edx, USB_PID_OUT
    jmp .status_token
.status_in:
    mov edx, USB_PID_IN
.status_token:
    mov eax, r8d
    shl eax, TD_TOKEN_ADDR_SHIFT
    or edx, eax
    or edx, TD_TOKEN_TOGGLE     ; Toggle = 1
    mov eax, 0x7FF              ; Max length = null packet
    shl eax, TD_TOKEN_MAXLEN_SHIFT
    or edx, eax

    xor r8d, r8d                ; No buffer
    call uhci_setup_td

    ; === Schedule the QH ===
    ; Insert QH into frame list entry 0
    mov eax, ebx
    or eax, TD_LP_QH            ; Mark as QH
    mov [uhci_frame_list], eax

    ; Wait for completion
    mov ecx, 100000             ; Timeout
.wait_complete:
    ; Check if status TD is done
    mov eax, [r15 + 4]
    test eax, TD_CS_ACTIVE
    jz .transfer_done

    push rcx
    mov ecx, 100
.poll_delay:
    pause
    loop .poll_delay
    pop rcx
    dec ecx
    jnz .wait_complete

    ; Timeout
    mov eax, -1
    jmp .control_cleanup

.transfer_done:
    ; Check for errors
    mov eax, [r15 + 4]
    test eax, TD_CS_STALLED | TD_CS_DBERR | TD_CS_BABBLE | TD_CS_NAK | TD_CS_CRC | TD_CS_BITSTUFF
    jnz .control_error_result

    ; Success - copy data if IN transfer
    mov al, [r11]
    test al, 0x80
    jz .no_copy_in

    ; Get actual length from data TD
    mov eax, [r14 + 4]
    and eax, TD_CS_ACTLEN_MASK
    inc eax                     ; Actual length + 1

    ; Copy from buffer to user buffer
    push rcx
    mov rdi, r12
    mov rsi, uhci_data_buffer
    mov ecx, eax
    rep movsb
    pop rcx

    jmp .control_cleanup

.no_copy_in:
    mov eax, r13d               ; Return requested length
    jmp .control_cleanup

.control_error_result:
    mov eax, -1
    jmp .control_cleanup

.control_error_cleanup:
    pop rdi
.control_error:
    mov eax, -1

.control_cleanup:
    ; Remove QH from frame list
    mov dword [uhci_frame_list], TD_LP_TERMINATE

    ; Free TDs and QH (simplified - just mark inactive)
    ; Real implementation would properly free them

    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UHCI_BULK_TRANSFER - Perform a bulk transfer
; Input: RDI = device, ESI = endpoint (bit 7 = direction), RDX = buffer, ECX = length
; Output: EAX = bytes transferred or -1
; ════════════════════════════════════════════════════════════════════════════
uhci_bulk_transfer:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11

    mov r10, rdi                ; Device
    mov r11d, esi               ; Endpoint
    mov r8, rdx                 ; Buffer
    mov r9d, ecx                ; Length

    ; Get device address and max packet
    movzx eax, byte [r10 + 1]   ; Address
    mov ebx, eax
    movzx eax, byte [r10 + 3]   ; Max packet
    test eax, eax
    jnz .have_bulk_max
    mov eax, 64
.have_bulk_max:
    mov r12d, eax               ; R12 = max packet

    ; Allocate TD
    call uhci_alloc_td
    test rax, rax
    jz .bulk_error
    mov rdi, rax

    ; Setup TD
    mov esi, TD_CS_ACTIVE | TD_CS_IOC | (3 << TD_CS_ERRCNT_SHIFT)
    cmp byte [r10 + 2], 0
    jne .bulk_full_speed
    or esi, TD_CS_LS
.bulk_full_speed:

    ; Determine direction
    test r11d, 0x80
    jz .bulk_out
    mov edx, USB_PID_IN
    jmp .bulk_token
.bulk_out:
    mov edx, USB_PID_OUT
    ; Copy data to aligned buffer
    push rdi
    push rcx
    mov rdi, uhci_bulk_buffer
    mov rsi, r8
    mov ecx, r9d
    rep movsb
    pop rcx
    pop rdi
.bulk_token:
    ; Add device address
    mov eax, ebx
    shl eax, TD_TOKEN_ADDR_SHIFT
    or edx, eax
    ; Add endpoint
    mov eax, r11d
    and eax, 0x0F
    shl eax, TD_TOKEN_EP_SHIFT
    or edx, eax
    ; Add length
    mov eax, r9d
    dec eax
    shl eax, TD_TOKEN_MAXLEN_SHIFT
    or edx, eax

    ; Buffer
    test r11d, 0x80
    jz .bulk_out_buf
    mov r8d, uhci_bulk_buffer
    jmp .setup_bulk_td
.bulk_out_buf:
    mov r8d, uhci_bulk_buffer

.setup_bulk_td:
    call uhci_setup_td

    ; Schedule TD
    mov eax, edi
    mov [uhci_frame_list], eax

    ; Wait for completion
    mov ecx, 100000
.bulk_wait:
    mov eax, [rdi + 4]
    test eax, TD_CS_ACTIVE
    jz .bulk_done

    push rcx
    mov ecx, 100
.bulk_delay:
    pause
    loop .bulk_delay
    pop rcx
    dec ecx
    jnz .bulk_wait

    mov eax, -1
    jmp .bulk_cleanup

.bulk_done:
    ; Check errors
    mov eax, [rdi + 4]
    test eax, TD_CS_STALLED | TD_CS_DBERR | TD_CS_BABBLE
    jnz .bulk_error_result

    ; Get actual length
    and eax, TD_CS_ACTLEN_MASK
    inc eax

    ; Copy data if IN
    test r11d, 0x80
    jz .bulk_cleanup

    push rax
    push rcx
    mov rdi, r8
    mov rsi, uhci_bulk_buffer
    mov ecx, eax
    rep movsb
    pop rcx
    pop rax
    jmp .bulk_cleanup

.bulk_error_result:
    mov eax, -1
    jmp .bulk_cleanup

.bulk_error:
    mov eax, -1

.bulk_cleanup:
    mov dword [uhci_frame_list], TD_LP_TERMINATE

    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TRANSFER DATA
; ════════════════════════════════════════════════════════════════════════════
align 16

uhci_setup_buffer:  times 8 db 0
uhci_data_buffer:   times 256 db 0
uhci_bulk_buffer:   times 512 db 0
