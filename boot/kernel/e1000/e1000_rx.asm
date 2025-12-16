; ════════════════════════════════════════════════════════════════════════════
; E1000 NETWORK DRIVER - RECEIVE (RX)
; Descriptor ring setup and packet reception
; ════════════════════════════════════════════════════════════════════════════

; RX Descriptor structure (16 bytes)
; +0:  addr    (64-bit physical address of buffer)
; +8:  length  (16-bit received length)
; +10: checksum (16-bit)
; +12: status  (8-bit, DD=done)
; +13: errors  (8-bit)
; +14: special (16-bit)

; ════════════════════════════════════════════════════════════════════════════
; E1000_RX_INIT - Initialize receive descriptor ring
; ════════════════════════════════════════════════════════════════════════════
e1000_rx_init:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    ; Clear RX descriptor ring memory
    mov rdi, E1000_RX_DESC_BASE
    mov rcx, E1000_RX_DESC_COUNT * 16
    xor al, al
    rep stosb

    ; Initialize each RX descriptor
    mov rbx, 0                      ; descriptor index
    mov rdi, E1000_RX_DESC_BASE

.init_desc:
    cmp rbx, E1000_RX_DESC_COUNT
    jge .desc_done

    ; Calculate buffer address for this descriptor
    mov rax, E1000_RX_BUFFER_BASE
    mov rcx, rbx
    imul rcx, E1000_RX_BUFFER_SIZE
    add rax, rcx

    ; Set buffer address (offset 0)
    mov [rdi], rax

    ; Clear status/length/etc (already zeroed)

    ; Next descriptor
    add rdi, 16
    inc rbx
    jmp .init_desc

.desc_done:
    ; Set RX descriptor base address (RDBAL/RDBAH)
    mov ecx, E1000_RDBAL
    mov eax, E1000_RX_DESC_BASE
    call e1000_write_reg

    mov ecx, E1000_RDBAH
    xor eax, eax                    ; High 32 bits = 0 (we're < 4GB)
    call e1000_write_reg

    ; Set RX descriptor ring length (RDLEN)
    ; Must be 128-byte aligned, value = num_descriptors * 16
    mov ecx, E1000_RDLEN
    mov eax, E1000_RX_DESC_COUNT * 16
    call e1000_write_reg

    ; Set head pointer (RDH = 0)
    mov ecx, E1000_RDH
    xor eax, eax
    call e1000_write_reg

    ; Set tail pointer (RDT = N-1, point to last descriptor)
    mov ecx, E1000_RDT
    mov eax, E1000_RX_DESC_COUNT - 1
    call e1000_write_reg

    ; Configure receive control (RCTL)
    ; Enable receiver, accept broadcast, 2048 byte buffers, strip CRC
    mov ecx, E1000_RCTL
    mov eax, E1000_RCTL_EN | E1000_RCTL_BAM | E1000_RCTL_BSIZE_2048 | E1000_RCTL_SECRC
    call e1000_write_reg

    ; Initialize current RX index
    mov dword [e1000_rx_cur], 0

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_RX_POLL - Check for received packets (polling mode)
; Output: RAX = packet length (0 if no packet), RDI = packet buffer address
; ════════════════════════════════════════════════════════════════════════════
e1000_rx_poll:
    push rbx
    push rcx
    push rdx

    ; Get current descriptor
    mov eax, [e1000_rx_cur]
    mov rbx, 16
    mul rbx
    add rax, E1000_RX_DESC_BASE
    mov rdx, rax                    ; RDX = descriptor address

    ; Check DD (descriptor done) bit in status
    mov al, [rdx + 12]              ; status byte
    test al, E1000_RXD_STAT_DD
    jz .no_packet

    ; Packet received! Get length
    movzx eax, word [rdx + 8]       ; length field

    ; Get buffer address
    mov rdi, [rdx]                  ; buffer physical address

    ; Clear the descriptor for reuse
    mov byte [rdx + 12], 0          ; Clear status

    ; Update tail pointer (give descriptor back to hardware)
    push rax
    mov ecx, E1000_RDT
    mov eax, [e1000_rx_cur]
    call e1000_write_reg
    pop rax

    ; Advance to next descriptor
    mov ebx, [e1000_rx_cur]
    inc ebx
    cmp ebx, E1000_RX_DESC_COUNT
    jl .no_wrap
    xor ebx, ebx
.no_wrap:
    mov [e1000_rx_cur], ebx

    jmp .done

.no_packet:
    xor eax, eax                    ; Return 0 length
    xor edi, edi                    ; Return NULL buffer

.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_RX_ISR - Receive interrupt handler
; Called from IRQ handler when packet arrives
; ════════════════════════════════════════════════════════════════════════════
e1000_rx_isr:
    push rax
    push rcx

    ; Read ICR to clear interrupt
    mov ecx, E1000_ICR
    call e1000_read_reg

    ; Check if it's an RX interrupt
    test eax, E1000_ICR_RXT0
    jz .not_rx

    ; Process received packets
.process_packets:
    call e1000_rx_poll
    test eax, eax
    jz .done

    ; Packet received - call handler
    ; RAX = length, RDI = buffer
    call e1000_handle_packet

    jmp .process_packets

.not_rx:
    ; Check for link status change
    test eax, E1000_ICR_LSC
    jz .done

    ; Link status changed - could notify user here

.done:
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_HANDLE_PACKET - Process received packet
; Input: RAX = length, RDI = buffer address
; ════════════════════════════════════════════════════════════════════════════
e1000_handle_packet:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Save packet info
    mov rbx, rax                    ; length
    mov rsi, rdi                    ; buffer

    ; Check minimum ethernet frame size
    cmp rbx, 14
    jl .drop

    ; Parse Ethernet header
    ; Bytes 0-5: Destination MAC
    ; Bytes 6-11: Source MAC
    ; Bytes 12-13: EtherType

    ; Get EtherType (big endian)
    movzx eax, byte [rsi + 12]
    shl eax, 8
    mov al, [rsi + 13]

    ; Check protocol
    cmp eax, 0x0800                 ; IPv4
    je .handle_ipv4
    cmp eax, 0x0806                 ; ARP
    je .handle_arp
    jmp .drop

.handle_ipv4:
    ; TODO: Pass to IP layer
    ; For now, increment counter
    inc dword [rx_ipv4_count]
    jmp .done

.handle_arp:
    ; TODO: Handle ARP
    inc dword [rx_arp_count]
    jmp .done

.drop:
    inc dword [rx_dropped]

.done:
    inc dword [rx_total]

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; RX Statistics
; ════════════════════════════════════════════════════════════════════════════
rx_total:       dd 0
rx_ipv4_count:  dd 0
rx_arp_count:   dd 0
rx_dropped:     dd 0
