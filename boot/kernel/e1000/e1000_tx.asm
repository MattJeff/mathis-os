; ════════════════════════════════════════════════════════════════════════════
; E1000 NETWORK DRIVER - TRANSMIT (TX)
; Descriptor ring setup and packet transmission
; ════════════════════════════════════════════════════════════════════════════

; TX Descriptor structure (16 bytes)
; +0:  addr    (64-bit physical address of buffer)
; +8:  length  (16-bit packet length)
; +10: cso     (8-bit checksum offset)
; +11: cmd     (8-bit command: EOP, IFCS, RS)
; +12: status  (8-bit, DD=done)
; +13: css     (8-bit checksum start)
; +14: special (16-bit)

; ════════════════════════════════════════════════════════════════════════════
; E1000_TX_INIT - Initialize transmit descriptor ring
; ════════════════════════════════════════════════════════════════════════════
e1000_tx_init:
    push rax
    push rbx
    push rcx
    push rdi

    ; Clear TX descriptor ring memory
    mov rdi, E1000_TX_DESC_BASE
    mov rcx, E1000_TX_DESC_COUNT * 16
    xor al, al
    rep stosb

    ; Initialize each TX descriptor
    mov rbx, 0                      ; descriptor index
    mov rdi, E1000_TX_DESC_BASE

.init_desc:
    cmp rbx, E1000_TX_DESC_COUNT
    jge .desc_done

    ; Calculate buffer address for this descriptor
    mov rax, E1000_TX_BUFFER_BASE
    mov rcx, rbx
    imul rcx, E1000_TX_BUFFER_SIZE
    add rax, rcx

    ; Set buffer address (offset 0)
    mov [rdi], rax

    ; Set status = DD (descriptor available)
    mov byte [rdi + 12], E1000_TXD_STAT_DD

    ; Next descriptor
    add rdi, 16
    inc rbx
    jmp .init_desc

.desc_done:
    ; Set TX descriptor base address (TDBAL/TDBAH)
    mov ecx, E1000_TDBAL
    mov eax, E1000_TX_DESC_BASE
    call e1000_write_reg

    mov ecx, E1000_TDBAH
    xor eax, eax                    ; High 32 bits = 0
    call e1000_write_reg

    ; Set TX descriptor ring length (TDLEN)
    mov ecx, E1000_TDLEN
    mov eax, E1000_TX_DESC_COUNT * 16
    call e1000_write_reg

    ; Set head pointer (TDH = 0)
    mov ecx, E1000_TDH
    xor eax, eax
    call e1000_write_reg

    ; Set tail pointer (TDT = 0)
    mov ecx, E1000_TDT
    xor eax, eax
    call e1000_write_reg

    ; Configure Inter-Packet Gap (TIPG)
    ; Standard values for 802.3
    mov ecx, E1000_TIPG
    mov eax, E1000_TIPG_IPGT | (E1000_TIPG_IPGR1 << 10) | (E1000_TIPG_IPGR2 << 20)
    call e1000_write_reg

    ; Configure transmit control (TCTL)
    ; Enable transmitter, pad short packets, collision threshold
    mov ecx, E1000_TCTL
    mov eax, E1000_TCTL_EN | E1000_TCTL_PSP
    or eax, (15 << E1000_TCTL_CT_SHIFT)     ; Collision threshold = 15
    or eax, (64 << E1000_TCTL_COLD_SHIFT)   ; Collision distance = 64 (full duplex)
    call e1000_write_reg

    ; Initialize current TX index
    mov dword [e1000_tx_cur], 0

    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_TX_SEND - Send a packet
; Input: RSI = packet data, RCX = packet length
; Output: CF set on error (no free descriptors)
; ════════════════════════════════════════════════════════════════════════════
e1000_tx_send:
    push rax
    push rbx
    push rdx
    push rdi
    push rsi
    push rcx

    ; Check packet length
    cmp rcx, E1000_TX_BUFFER_SIZE
    ja .error

    ; Get current TX descriptor
    mov eax, [e1000_tx_cur]
    mov rbx, 16
    mul rbx
    add rax, E1000_TX_DESC_BASE
    mov rdx, rax                    ; RDX = descriptor address

    ; Check if descriptor is available (DD bit set)
    mov al, [rdx + 12]
    test al, E1000_TXD_STAT_DD
    jz .error                       ; Descriptor busy

    ; Get buffer address from descriptor
    mov rdi, [rdx]

    ; Copy packet data to TX buffer
    pop rcx                         ; Restore length
    push rcx
    rep movsb

    ; Set up descriptor
    pop rcx                         ; length
    push rcx

    ; Length (offset 8)
    mov [rdx + 8], cx

    ; Command: End of Packet, Insert FCS, Report Status
    mov byte [rdx + 11], E1000_TXD_CMD_EOP | E1000_TXD_CMD_IFCS | E1000_TXD_CMD_RS

    ; Clear status (DD will be set by hardware when done)
    mov byte [rdx + 12], 0

    ; Update tail pointer to trigger transmission
    mov ecx, E1000_TDT
    mov eax, [e1000_tx_cur]
    inc eax
    cmp eax, E1000_TX_DESC_COUNT
    jl .no_wrap
    xor eax, eax
.no_wrap:
    mov [e1000_tx_cur], eax
    call e1000_write_reg

    ; Success
    inc dword [tx_total]
    clc
    jmp .done

.error:
    inc dword [tx_dropped]
    stc

.done:
    pop rcx
    pop rsi
    pop rdi
    pop rdx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_TX_WAIT - Wait for TX to complete
; Input: Descriptor index in EAX
; ════════════════════════════════════════════════════════════════════════════
e1000_tx_wait:
    push rbx
    push rcx
    push rdx

    ; Calculate descriptor address
    mov rbx, 16
    mul rbx
    add rax, E1000_TX_DESC_BASE
    mov rdx, rax

    ; Wait for DD bit
    mov ecx, 100000
.wait:
    mov al, [rdx + 12]
    test al, E1000_TXD_STAT_DD
    jnz .done
    dec ecx
    jnz .wait

    ; Timeout - increment error counter
    inc dword [tx_timeout]

.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; E1000_SEND_RAW - Send raw ethernet frame
; Input: RSI = source MAC (6 bytes)
;        RDI = dest MAC (6 bytes)
;        DX = EtherType
;        R8 = payload pointer
;        R9 = payload length
; ════════════════════════════════════════════════════════════════════════════
e1000_send_raw:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; Get TX buffer
    mov eax, [e1000_tx_cur]
    mov rbx, 16
    mul rbx
    add rax, E1000_TX_DESC_BASE
    push rax                        ; Save descriptor address

    mov rax, [rax]                  ; Get buffer address
    mov rbx, rax                    ; RBX = buffer start

    ; Build Ethernet header
    ; Destination MAC (6 bytes)
    push rsi
    mov rsi, rdi
    mov rdi, rbx
    mov rcx, 6
    rep movsb

    ; Source MAC (6 bytes)
    pop rsi
    mov rcx, 6
    rep movsb

    ; EtherType (2 bytes, big endian)
    mov al, dh
    stosb
    mov al, dl
    stosb

    ; Copy payload
    mov rsi, r8
    mov rcx, r9
    rep movsb

    ; Calculate total length
    mov rcx, r9
    add rcx, 14                     ; Ethernet header = 14 bytes

    ; Pad to minimum frame size (60 bytes without CRC)
    cmp rcx, 60
    jge .no_pad
    mov rax, 60
    sub rax, rcx
    xor al, al
    rep stosb
    mov rcx, 60
.no_pad:

    ; Set up descriptor and send
    pop rdx                         ; Restore descriptor address

    ; Length
    mov [rdx + 8], cx

    ; Command
    mov byte [rdx + 11], E1000_TXD_CMD_EOP | E1000_TXD_CMD_IFCS | E1000_TXD_CMD_RS

    ; Clear status
    mov byte [rdx + 12], 0

    ; Update tail
    mov ecx, E1000_TDT
    mov eax, [e1000_tx_cur]
    inc eax
    cmp eax, E1000_TX_DESC_COUNT
    jl .no_wrap
    xor eax, eax
.no_wrap:
    mov [e1000_tx_cur], eax
    call e1000_write_reg

    inc dword [tx_total]

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; TX Statistics
; ════════════════════════════════════════════════════════════════════════════
tx_total:       dd 0
tx_dropped:     dd 0
tx_timeout:     dd 0
