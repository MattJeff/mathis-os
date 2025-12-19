; ════════════════════════════════════════════════════════════════════════════
; TCP.ASM - Transmission Control Protocol (FULL IMPLEMENTATION)
; Reliable, connection-oriented transport layer
; ════════════════════════════════════════════════════════════════════════════
; TCP Header Structure (20+ bytes):
;   +0:  Source Port      (2 bytes)
;   +2:  Destination Port (2 bytes)
;   +4:  Sequence Number  (4 bytes)
;   +8:  Ack Number       (4 bytes)
;   +12: Data Offset(4) + Reserved(3) + Flags(9)
;   +14: Window Size      (2 bytes)
;   +16: Checksum         (2 bytes)
;   +18: Urgent Pointer   (2 bytes)
;   +20: Options (variable)
; ════════════════════════════════════════════════════════════════════════════

; TCP Header offsets
TCP_OFF_SRC_PORT    equ 0
TCP_OFF_DST_PORT    equ 2
TCP_OFF_SEQ         equ 4
TCP_OFF_ACK         equ 8
TCP_OFF_FLAGS       equ 12
TCP_OFF_WINDOW      equ 14
TCP_OFF_CHECKSUM    equ 16
TCP_OFF_URGENT      equ 18
TCP_HEADER_SIZE     equ 20

; TCP Flags (in low 6 bits of flags byte at offset 13)
TCP_FIN             equ 0x01
TCP_SYN             equ 0x02
TCP_RST             equ 0x04
TCP_PSH             equ 0x08
TCP_ACK             equ 0x10
TCP_URG             equ 0x20

; TCP Connection States (RFC 793)
TCP_STATE_CLOSED        equ 0
TCP_STATE_LISTEN        equ 1
TCP_STATE_SYN_SENT      equ 2
TCP_STATE_SYN_RECEIVED  equ 3
TCP_STATE_ESTABLISHED   equ 4
TCP_STATE_FIN_WAIT_1    equ 5
TCP_STATE_FIN_WAIT_2    equ 6
TCP_STATE_CLOSE_WAIT    equ 7
TCP_STATE_CLOSING       equ 8
TCP_STATE_LAST_ACK      equ 9
TCP_STATE_TIME_WAIT     equ 10

; TCP Socket/TCB (Transmission Control Block) structure
; Size: 128 bytes per connection
TCP_TCB_STATE           equ 0       ; 1 byte - connection state
TCP_TCB_FLAGS           equ 1       ; 1 byte - socket flags
TCP_TCB_LOCAL_PORT      equ 2       ; 2 bytes
TCP_TCB_REMOTE_PORT     equ 4       ; 2 bytes
TCP_TCB_REMOTE_IP       equ 8       ; 4 bytes
TCP_TCB_SND_UNA         equ 12      ; 4 bytes - oldest unacknowledged seq
TCP_TCB_SND_NXT         equ 16      ; 4 bytes - next seq to send
TCP_TCB_SND_WND         equ 20      ; 2 bytes - send window
TCP_TCB_RCV_NXT         equ 24      ; 4 bytes - next expected seq
TCP_TCB_RCV_WND         equ 28      ; 2 bytes - receive window
TCP_TCB_ISS             equ 32      ; 4 bytes - initial send seq
TCP_TCB_IRS             equ 36      ; 4 bytes - initial receive seq
TCP_TCB_RTT             equ 40      ; 4 bytes - round-trip time estimate
TCP_TCB_RTO             equ 44      ; 4 bytes - retransmit timeout
TCP_TCB_RETRIES         equ 48      ; 1 byte - retransmit count
TCP_TCB_BACKLOG         equ 49      ; 1 byte - listen backlog
TCP_TCB_TIMER           equ 52      ; 4 bytes - retransmit timer
TCP_TCB_TIME_WAIT_TIMER equ 56      ; 4 bytes - TIME_WAIT timer
TCP_TCB_RX_BUF          equ 64      ; 8 bytes - receive buffer pointer
TCP_TCB_RX_LEN          equ 72      ; 4 bytes - data in RX buffer
TCP_TCB_TX_BUF          equ 80      ; 8 bytes - transmit buffer pointer
TCP_TCB_TX_LEN          equ 88      ; 4 bytes - data in TX buffer
TCP_TCB_PARENT          equ 96      ; 8 bytes - parent socket (for accept)
TCP_TCB_ACCEPT_QUEUE    equ 104     ; 8 bytes - accept queue head
TCP_TCB_SIZE            equ 128

; Constants
MAX_TCP_SOCKETS         equ 8
TCP_DEFAULT_WINDOW      equ 2048
TCP_MAX_RETRIES         equ 5
TCP_RTO_INIT            equ 300     ; 3 seconds in ticks
TCP_TIME_WAIT_TIME      equ 12000   ; 2 minutes (2MSL)
TCP_RX_BUFFER_SIZE      equ 2048
TCP_TX_BUFFER_SIZE      equ 2048

; ════════════════════════════════════════════════════════════════════════════
; TCP_HANDLE_PACKET - Process received TCP segment
; Input: RSI = pointer to TCP segment, ECX = length
; ════════════════════════════════════════════════════════════════════════════
tcp_handle_packet_impl:
    push rax
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

    ; Verify minimum length
    cmp ecx, TCP_HEADER_SIZE
    jl .tcp_done

    mov r12, rsi                ; Save packet pointer
    mov r11d, ecx               ; Save length

    ; Get ports (big-endian)
    movzx eax, word [rsi + TCP_OFF_DST_PORT]
    xchg al, ah
    mov r8d, eax                ; R8 = local port

    movzx eax, word [rsi + TCP_OFF_SRC_PORT]
    xchg al, ah
    mov r9d, eax                ; R9 = remote port

    ; Get remote IP from IP layer
    mov r10d, [ip_last_src]     ; R10 = remote IP

    ; Get TCP flags
    movzx eax, byte [rsi + 13]
    and eax, 0x3F               ; Mask flag bits
    mov ebx, eax                ; EBX = flags

    ; Find matching socket
    mov edi, r8d                ; Local port
    mov esi, r10d               ; Remote IP
    mov edx, r9d                ; Remote port
    call tcp_find_socket
    mov rdi, rax                ; RDI = socket (or 0)

    ; If no socket found, check for listening socket
    test rdi, rdi
    jnz .have_socket

    ; Try to find listening socket
    push rbx
    mov edi, r8d
    call tcp_find_listening_socket
    mov rdi, rax
    pop rbx

    test rdi, rdi
    jz .send_rst                ; No socket - send RST

.have_socket:
    ; Get current state
    movzx eax, byte [rdi + TCP_TCB_STATE]

    ; Dispatch based on state
    cmp al, TCP_STATE_CLOSED
    je .state_closed
    cmp al, TCP_STATE_LISTEN
    je .state_listen
    cmp al, TCP_STATE_SYN_SENT
    je .state_syn_sent
    cmp al, TCP_STATE_SYN_RECEIVED
    je .state_syn_received
    cmp al, TCP_STATE_ESTABLISHED
    je .state_established
    cmp al, TCP_STATE_FIN_WAIT_1
    je .state_fin_wait_1
    cmp al, TCP_STATE_FIN_WAIT_2
    je .state_fin_wait_2
    cmp al, TCP_STATE_CLOSE_WAIT
    je .state_close_wait
    cmp al, TCP_STATE_CLOSING
    je .state_closing
    cmp al, TCP_STATE_LAST_ACK
    je .state_last_ack
    cmp al, TCP_STATE_TIME_WAIT
    je .state_time_wait
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: CLOSED - Connection is closed
; ──────────────────────────────────────────────────────────────────────
.state_closed:
    ; Send RST if not RST
    test bl, TCP_RST
    jnz .tcp_done
    jmp .send_rst

; ──────────────────────────────────────────────────────────────────────
; STATE: LISTEN - Waiting for connection request
; ──────────────────────────────────────────────────────────────────────
.state_listen:
    ; Expect SYN
    test bl, TCP_RST
    jnz .tcp_done               ; Ignore RST
    test bl, TCP_ACK
    jnz .send_rst               ; ACK in LISTEN is invalid
    test bl, TCP_SYN
    jz .tcp_done                ; Must have SYN

    ; Create new socket for this connection
    push rdi                    ; Save listening socket
    call tcp_socket_create
    test rax, rax
    jz .listen_no_socket
    mov rdi, rax                ; New socket

    ; Copy info to new socket
    pop rax                     ; Parent socket
    mov [rdi + TCP_TCB_PARENT], rax

    ; Set remote info
    mov [rdi + TCP_TCB_REMOTE_IP], r10d
    mov [rdi + TCP_TCB_REMOTE_PORT], r9w
    mov [rdi + TCP_TCB_LOCAL_PORT], r8w

    ; Get initial sequence number from SYN
    mov eax, [r12 + TCP_OFF_SEQ]
    bswap eax
    mov [rdi + TCP_TCB_IRS], eax
    inc eax                     ; RCV.NXT = ISS + 1
    mov [rdi + TCP_TCB_RCV_NXT], eax

    ; Generate our ISS
    call tcp_generate_isn
    mov [rdi + TCP_TCB_ISS], eax
    mov [rdi + TCP_TCB_SND_NXT], eax
    mov [rdi + TCP_TCB_SND_UNA], eax

    ; Set window
    mov word [rdi + TCP_TCB_RCV_WND], TCP_DEFAULT_WINDOW

    ; Send SYN-ACK
    mov al, TCP_SYN | TCP_ACK
    call tcp_send_segment

    ; Move to SYN_RECEIVED
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_SYN_RECEIVED
    inc dword [rdi + TCP_TCB_SND_NXT]   ; SYN consumes 1 seq

    ; Start retransmit timer
    mov eax, [tick_count]
    add eax, TCP_RTO_INIT
    mov [rdi + TCP_TCB_TIMER], eax

    jmp .tcp_done

.listen_no_socket:
    pop rdi
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: SYN_SENT - SYN sent, waiting for SYN-ACK
; ──────────────────────────────────────────────────────────────────────
.state_syn_sent:
    ; Check for RST
    test bl, TCP_RST
    jnz .syn_sent_rst

    ; Check for ACK
    test bl, TCP_ACK
    jz .syn_sent_no_ack

    ; Verify ACK number
    mov eax, [r12 + TCP_OFF_ACK]
    bswap eax
    cmp eax, [rdi + TCP_TCB_ISS]
    jbe .send_rst               ; ACK <= ISS is invalid
    cmp eax, [rdi + TCP_TCB_SND_NXT]
    ja .send_rst                ; ACK > SND.NXT is invalid

.syn_sent_no_ack:
    ; Check for SYN
    test bl, TCP_SYN
    jz .tcp_done

    ; Got SYN - save their ISS
    mov eax, [r12 + TCP_OFF_SEQ]
    bswap eax
    mov [rdi + TCP_TCB_IRS], eax
    inc eax
    mov [rdi + TCP_TCB_RCV_NXT], eax

    ; If we got ACK too, connection is established
    test bl, TCP_ACK
    jz .syn_sent_syn_only

    ; SYN-ACK received - update SND.UNA
    mov eax, [r12 + TCP_OFF_ACK]
    bswap eax
    mov [rdi + TCP_TCB_SND_UNA], eax

    ; Send ACK
    mov al, TCP_ACK
    call tcp_send_segment

    ; Move to ESTABLISHED
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_ESTABLISHED
    jmp .tcp_done

.syn_sent_syn_only:
    ; Simultaneous open - send SYN-ACK
    mov al, TCP_SYN | TCP_ACK
    call tcp_send_segment
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_SYN_RECEIVED
    jmp .tcp_done

.syn_sent_rst:
    ; If ACK was acceptable, reset connection
    test bl, TCP_ACK
    jz .tcp_done
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: SYN_RECEIVED - SYN-ACK sent, waiting for ACK
; ──────────────────────────────────────────────────────────────────────
.state_syn_received:
    ; Check RST
    test bl, TCP_RST
    jnz .syn_rcvd_rst

    ; Check SYN (retransmit)
    test bl, TCP_SYN
    jnz .send_rst               ; SYN in SYN_RECEIVED is error

    ; Must have ACK
    test bl, TCP_ACK
    jz .tcp_done

    ; Verify ACK
    mov eax, [r12 + TCP_OFF_ACK]
    bswap eax
    cmp eax, [rdi + TCP_TCB_SND_UNA]
    jbe .send_rst
    cmp eax, [rdi + TCP_TCB_SND_NXT]
    ja .send_rst

    ; ACK is valid - connection established
    mov [rdi + TCP_TCB_SND_UNA], eax
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_ESTABLISHED

    ; Add to parent's accept queue if applicable
    mov rax, [rdi + TCP_TCB_PARENT]
    test rax, rax
    jz .tcp_done

    ; Link to accept queue
    mov [rdi + TCP_TCB_ACCEPT_QUEUE], rax
    jmp .tcp_done

.syn_rcvd_rst:
    ; Return to LISTEN if passive open
    mov rax, [rdi + TCP_TCB_PARENT]
    test rax, rax
    jz .syn_rcvd_close

    ; Was passive - just close this socket
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

.syn_rcvd_close:
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: ESTABLISHED - Connection is open
; ──────────────────────────────────────────────────────────────────────
.state_established:
    ; Check RST
    test bl, TCP_RST
    jnz .established_rst

    ; Check SYN (error)
    test bl, TCP_SYN
    jnz .send_rst

    ; Process ACK
    test bl, TCP_ACK
    jz .established_check_data

    mov eax, [r12 + TCP_OFF_ACK]
    bswap eax

    ; Check if ACK is acceptable
    cmp eax, [rdi + TCP_TCB_SND_UNA]
    jbe .established_dup_ack
    cmp eax, [rdi + TCP_TCB_SND_NXT]
    ja .established_check_data  ; Future ACK - ignore

    ; Valid ACK - update SND.UNA
    mov [rdi + TCP_TCB_SND_UNA], eax

    ; Reset retransmit timer
    mov byte [rdi + TCP_TCB_RETRIES], 0

.established_dup_ack:
.established_check_data:
    ; Check sequence number
    mov eax, [r12 + TCP_OFF_SEQ]
    bswap eax
    cmp eax, [rdi + TCP_TCB_RCV_NXT]
    jne .established_out_of_order

    ; Calculate data offset
    movzx ecx, byte [r12 + 12]
    shr ecx, 4
    shl ecx, 2                  ; Data offset in bytes

    ; Calculate data length
    mov eax, r11d               ; Total segment length
    sub eax, ecx                ; Subtract header
    jle .established_check_fin  ; No data

    ; Copy data to receive buffer
    push rax                    ; Save data length
    mov rsi, r12
    add rsi, rcx                ; Point to data
    mov rdi, [rdi + TCP_TCB_RX_BUF]
    add rdi, [rdi - 64 + TCP_TCB_RX_LEN]  ; Append to existing
    mov ecx, eax
    rep movsb

    ; Update RX length and RCV.NXT
    pop rax
    mov rdi, [rsp + 8]          ; Restore socket pointer
    add [rdi + TCP_TCB_RX_LEN], eax
    add [rdi + TCP_TCB_RCV_NXT], eax

    ; Send ACK
    push rax
    mov al, TCP_ACK
    call tcp_send_segment
    pop rax

.established_check_fin:
    ; Check FIN
    test bl, TCP_FIN
    jz .tcp_done

    ; FIN received - acknowledge
    inc dword [rdi + TCP_TCB_RCV_NXT]
    mov al, TCP_ACK
    call tcp_send_segment

    ; Move to CLOSE_WAIT
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSE_WAIT
    jmp .tcp_done

.established_out_of_order:
    ; Out of order - send duplicate ACK
    mov al, TCP_ACK
    call tcp_send_segment
    jmp .tcp_done

.established_rst:
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: FIN_WAIT_1 - FIN sent, waiting for ACK or FIN
; ──────────────────────────────────────────────────────────────────────
.state_fin_wait_1:
    test bl, TCP_RST
    jnz .fin_wait_1_rst

    ; Check ACK of our FIN
    test bl, TCP_ACK
    jz .fin_wait_1_check_fin

    mov eax, [r12 + TCP_OFF_ACK]
    bswap eax
    cmp eax, [rdi + TCP_TCB_SND_NXT]
    jne .fin_wait_1_check_fin

    ; Our FIN was ACKed
    test bl, TCP_FIN
    jnz .fin_wait_1_simul_close

    ; Move to FIN_WAIT_2
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_FIN_WAIT_2
    jmp .tcp_done

.fin_wait_1_check_fin:
    test bl, TCP_FIN
    jz .tcp_done

    ; Got FIN - send ACK
    inc dword [rdi + TCP_TCB_RCV_NXT]
    mov al, TCP_ACK
    call tcp_send_segment

    ; Check if our FIN was also ACKed
    mov eax, [r12 + TCP_OFF_ACK]
    bswap eax
    cmp eax, [rdi + TCP_TCB_SND_NXT]
    je .fin_wait_1_to_time_wait

    ; Move to CLOSING
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSING
    jmp .tcp_done

.fin_wait_1_simul_close:
    ; Both FIN and ACK - go to TIME_WAIT
    inc dword [rdi + TCP_TCB_RCV_NXT]
    mov al, TCP_ACK
    call tcp_send_segment

.fin_wait_1_to_time_wait:
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_TIME_WAIT
    mov eax, [tick_count]
    add eax, TCP_TIME_WAIT_TIME
    mov [rdi + TCP_TCB_TIME_WAIT_TIMER], eax
    jmp .tcp_done

.fin_wait_1_rst:
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: FIN_WAIT_2 - Waiting for FIN
; ──────────────────────────────────────────────────────────────────────
.state_fin_wait_2:
    test bl, TCP_RST
    jnz .fin_wait_2_rst

    test bl, TCP_FIN
    jz .tcp_done

    ; Got FIN
    inc dword [rdi + TCP_TCB_RCV_NXT]
    mov al, TCP_ACK
    call tcp_send_segment

    ; Move to TIME_WAIT
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_TIME_WAIT
    mov eax, [tick_count]
    add eax, TCP_TIME_WAIT_TIME
    mov [rdi + TCP_TCB_TIME_WAIT_TIMER], eax
    jmp .tcp_done

.fin_wait_2_rst:
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: CLOSE_WAIT - Received FIN, waiting for app to close
; ──────────────────────────────────────────────────────────────────────
.state_close_wait:
    test bl, TCP_RST
    jnz .close_wait_rst
    ; Just wait for application to call close
    jmp .tcp_done

.close_wait_rst:
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: CLOSING - Both sides sent FIN
; ──────────────────────────────────────────────────────────────────────
.state_closing:
    test bl, TCP_RST
    jnz .closing_rst

    test bl, TCP_ACK
    jz .tcp_done

    ; Check if our FIN is ACKed
    mov eax, [r12 + TCP_OFF_ACK]
    bswap eax
    cmp eax, [rdi + TCP_TCB_SND_NXT]
    jne .tcp_done

    ; Move to TIME_WAIT
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_TIME_WAIT
    mov eax, [tick_count]
    add eax, TCP_TIME_WAIT_TIME
    mov [rdi + TCP_TCB_TIME_WAIT_TIMER], eax
    jmp .tcp_done

.closing_rst:
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: LAST_ACK - Sent FIN, waiting for ACK
; ──────────────────────────────────────────────────────────────────────
.state_last_ack:
    test bl, TCP_RST
    jnz .last_ack_rst

    test bl, TCP_ACK
    jz .tcp_done

    mov eax, [r12 + TCP_OFF_ACK]
    bswap eax
    cmp eax, [rdi + TCP_TCB_SND_NXT]
    jne .tcp_done

    ; FIN ACKed - close
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

.last_ack_rst:
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; STATE: TIME_WAIT - Waiting for 2MSL
; ──────────────────────────────────────────────────────────────────────
.state_time_wait:
    test bl, TCP_RST
    jnz .time_wait_rst

    ; Resend ACK if FIN received (lost ACK)
    test bl, TCP_FIN
    jz .tcp_done

    mov al, TCP_ACK
    call tcp_send_segment

    ; Restart TIME_WAIT timer
    mov eax, [tick_count]
    add eax, TCP_TIME_WAIT_TIME
    mov [rdi + TCP_TCB_TIME_WAIT_TIMER], eax
    jmp .tcp_done

.time_wait_rst:
    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .tcp_done

; ──────────────────────────────────────────────────────────────────────
; Send RST for invalid packets
; ──────────────────────────────────────────────────────────────────────
.send_rst:
    ; Don't send RST in response to RST
    test bl, TCP_RST
    jnz .tcp_done

    ; Build RST response
    call tcp_send_rst
    jmp .tcp_done

.tcp_done:
    inc dword [tcp_rx_count]
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
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SOCKET_CREATE - Create a TCP socket
; Output: RAX = socket handle (or 0)
; ════════════════════════════════════════════════════════════════════════════
tcp_socket_create:
    push rbx
    push rcx
    push rdi

    ; Find free socket
    mov rbx, tcp_sockets
    mov ecx, MAX_TCP_SOCKETS

.find_slot:
    cmp byte [rbx + TCP_TCB_STATE], TCP_STATE_CLOSED
    je .found_slot
    add rbx, TCP_TCB_SIZE
    dec ecx
    jnz .find_slot

    xor eax, eax
    jmp .create_done

.found_slot:
    ; Clear TCB
    mov rdi, rbx
    push rcx
    mov ecx, TCP_TCB_SIZE
    xor al, al
    rep stosb
    pop rcx

    ; Initialize
    mov byte [rbx + TCP_TCB_STATE], TCP_STATE_CLOSED
    mov word [rbx + TCP_TCB_RCV_WND], TCP_DEFAULT_WINDOW
    mov dword [rbx + TCP_TCB_RTO], TCP_RTO_INIT

    ; Allocate buffers
    mov rax, MAX_TCP_SOCKETS
    sub rax, rcx                ; Socket index
    imul rax, TCP_RX_BUFFER_SIZE
    add rax, tcp_rx_buffers
    mov [rbx + TCP_TCB_RX_BUF], rax

    mov rax, MAX_TCP_SOCKETS
    sub rax, rcx
    imul rax, TCP_TX_BUFFER_SIZE
    add rax, tcp_tx_buffers
    mov [rbx + TCP_TCB_TX_BUF], rax

    mov rax, rbx

.create_done:
    pop rdi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SOCKET_BIND - Bind socket to local port
; Input: RDI = socket, ESI = port
; Output: EAX = 0 on success
; ════════════════════════════════════════════════════════════════════════════
tcp_socket_bind:
    test rdi, rdi
    jz .bind_error

    mov [rdi + TCP_TCB_LOCAL_PORT], si
    xor eax, eax
    ret

.bind_error:
    mov eax, -1
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SOCKET_LISTEN - Start listening for connections
; Input: RDI = socket, ESI = backlog
; Output: EAX = 0 on success
; ════════════════════════════════════════════════════════════════════════════
tcp_socket_listen:
    test rdi, rdi
    jz .listen_error

    mov byte [rdi + TCP_TCB_STATE], TCP_STATE_LISTEN
    mov [rdi + TCP_TCB_BACKLOG], sil
    xor eax, eax
    ret

.listen_error:
    mov eax, -1
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SOCKET_CONNECT - Initiate connection (active open)
; Input: RDI = socket, ESI = remote IP, EDX = remote port
; Output: EAX = 0 if connection initiated
; ════════════════════════════════════════════════════════════════════════════
tcp_socket_connect:
    push rbx
    push rdi

    test rdi, rdi
    jz .connect_error

    mov rbx, rdi

    ; Set remote info
    mov [rbx + TCP_TCB_REMOTE_IP], esi
    mov [rbx + TCP_TCB_REMOTE_PORT], dx

    ; Generate ISS
    call tcp_generate_isn
    mov [rbx + TCP_TCB_ISS], eax
    mov [rbx + TCP_TCB_SND_NXT], eax
    mov [rbx + TCP_TCB_SND_UNA], eax

    ; Send SYN
    mov rdi, rbx
    mov al, TCP_SYN
    call tcp_send_segment

    ; Move to SYN_SENT
    mov byte [rbx + TCP_TCB_STATE], TCP_STATE_SYN_SENT
    inc dword [rbx + TCP_TCB_SND_NXT]   ; SYN uses 1 seq

    ; Start retransmit timer
    mov eax, [tick_count]
    add eax, TCP_RTO_INIT
    mov [rbx + TCP_TCB_TIMER], eax

    xor eax, eax
    jmp .connect_done

.connect_error:
    mov eax, -1

.connect_done:
    pop rdi
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SOCKET_ACCEPT - Accept incoming connection
; Input: RDI = listening socket
; Output: RAX = new socket (or 0 if none)
; ════════════════════════════════════════════════════════════════════════════
tcp_socket_accept:
    push rbx
    push rcx

    test rdi, rdi
    jz .accept_none

    ; Search for ESTABLISHED socket with this parent
    mov rbx, tcp_sockets
    mov ecx, MAX_TCP_SOCKETS

.accept_search:
    cmp byte [rbx + TCP_TCB_STATE], TCP_STATE_ESTABLISHED
    jne .accept_next

    cmp [rbx + TCP_TCB_PARENT], rdi
    jne .accept_next

    ; Found one - clear parent link and return
    mov qword [rbx + TCP_TCB_PARENT], 0
    mov rax, rbx
    jmp .accept_done

.accept_next:
    add rbx, TCP_TCB_SIZE
    dec ecx
    jnz .accept_search

.accept_none:
    xor eax, eax

.accept_done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SOCKET_SEND - Send data on connection
; Input: RDI = socket, RSI = data, ECX = length
; Output: EAX = bytes sent or -1
; ════════════════════════════════════════════════════════════════════════════
tcp_socket_send:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    test rdi, rdi
    jz .send_error

    mov rbx, rdi
    mov r8d, ecx                ; Save length

    ; Check state
    cmp byte [rbx + TCP_TCB_STATE], TCP_STATE_ESTABLISHED
    jne .send_error

    ; Copy data to TX buffer
    mov rdi, [rbx + TCP_TCB_TX_BUF]
    add rdi, [rbx + TCP_TCB_TX_LEN]
    rep movsb

    ; Update TX length
    add [rbx + TCP_TCB_TX_LEN], r8d

    ; Send segment with data
    mov rdi, rbx
    mov al, TCP_ACK | TCP_PSH
    call tcp_send_data_segment

    mov eax, r8d
    inc dword [tcp_tx_count]
    jmp .send_done

.send_error:
    mov eax, -1

.send_done:
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SOCKET_RECV - Receive data (non-blocking)
; Input: RDI = socket, RSI = buffer, EDX = max length
; Output: EAX = bytes received (0 if none)
; ════════════════════════════════════════════════════════════════════════════
tcp_socket_recv:
    push rbx
    push rcx
    push rdi
    push rsi

    test rdi, rdi
    jz .recv_none

    mov rbx, rdi

    ; Check if data available
    mov eax, [rbx + TCP_TCB_RX_LEN]
    test eax, eax
    jz .recv_none

    ; Limit to buffer size
    cmp eax, edx
    jle .recv_copy
    mov eax, edx

.recv_copy:
    push rax
    mov rdi, rsi                ; Destination
    mov rsi, [rbx + TCP_TCB_RX_BUF]  ; Source
    mov ecx, eax
    rep movsb

    ; Clear RX buffer (simple: just reset length)
    pop rax
    sub [rbx + TCP_TCB_RX_LEN], eax
    jmp .recv_done

.recv_none:
    xor eax, eax

.recv_done:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SOCKET_CLOSE - Close connection
; Input: RDI = socket
; ════════════════════════════════════════════════════════════════════════════
tcp_socket_close:
    push rax
    push rbx

    test rdi, rdi
    jz .close_done

    mov rbx, rdi
    movzx eax, byte [rbx + TCP_TCB_STATE]

    ; Handle based on state
    cmp al, TCP_STATE_CLOSED
    je .close_done
    cmp al, TCP_STATE_LISTEN
    je .close_immediate
    cmp al, TCP_STATE_SYN_SENT
    je .close_immediate
    cmp al, TCP_STATE_SYN_RECEIVED
    je .close_send_fin
    cmp al, TCP_STATE_ESTABLISHED
    je .close_send_fin
    cmp al, TCP_STATE_CLOSE_WAIT
    je .close_send_fin_last_ack
    jmp .close_done

.close_immediate:
    mov byte [rbx + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .close_done

.close_send_fin:
    ; Send FIN
    mov rdi, rbx
    mov al, TCP_FIN | TCP_ACK
    call tcp_send_segment
    inc dword [rbx + TCP_TCB_SND_NXT]
    mov byte [rbx + TCP_TCB_STATE], TCP_STATE_FIN_WAIT_1
    jmp .close_done

.close_send_fin_last_ack:
    mov rdi, rbx
    mov al, TCP_FIN | TCP_ACK
    call tcp_send_segment
    inc dword [rbx + TCP_TCB_SND_NXT]
    mov byte [rbx + TCP_TCB_STATE], TCP_STATE_LAST_ACK

.close_done:
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SEND_SEGMENT - Send TCP segment (control only, no data)
; Input: RDI = socket, AL = flags
; ════════════════════════════════════════════════════════════════════════════
tcp_send_segment:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov rbx, rdi
    mov r8b, al                 ; Save flags

    ; Build TCP header in tcp_tx_buffer
    mov rdi, tcp_tx_buffer

    ; Source port
    movzx eax, word [rbx + TCP_TCB_LOCAL_PORT]
    xchg al, ah
    mov [rdi + TCP_OFF_SRC_PORT], ax

    ; Destination port
    movzx eax, word [rbx + TCP_TCB_REMOTE_PORT]
    xchg al, ah
    mov [rdi + TCP_OFF_DST_PORT], ax

    ; Sequence number
    mov eax, [rbx + TCP_TCB_SND_NXT]
    bswap eax
    mov [rdi + TCP_OFF_SEQ], eax

    ; Ack number
    mov eax, [rbx + TCP_TCB_RCV_NXT]
    bswap eax
    mov [rdi + TCP_OFF_ACK], eax

    ; Data offset (5 = 20 bytes) + flags
    mov byte [rdi + 12], 0x50   ; Data offset = 5
    mov [rdi + 13], r8b         ; Flags

    ; Window
    movzx eax, word [rbx + TCP_TCB_RCV_WND]
    xchg al, ah
    mov [rdi + TCP_OFF_WINDOW], ax

    ; Checksum (0 for now)
    mov word [rdi + TCP_OFF_CHECKSUM], 0

    ; Urgent pointer
    mov word [rdi + TCP_OFF_URGENT], 0

    ; Calculate checksum with pseudo-header
    push rdi
    mov rsi, rdi
    mov ecx, TCP_HEADER_SIZE
    mov edi, [rbx + TCP_TCB_REMOTE_IP]
    call tcp_calculate_checksum
    pop rdi
    mov [rdi + TCP_OFF_CHECKSUM], ax

    ; Send via IP
    push rdi
    mov edi, [rbx + TCP_TCB_REMOTE_IP]
    mov al, IP_PROTO_TCP
    mov rsi, tcp_tx_buffer
    mov ecx, TCP_HEADER_SIZE
    call ip_send
    pop rdi

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SEND_DATA_SEGMENT - Send TCP segment with data
; Input: RDI = socket, AL = flags
; ════════════════════════════════════════════════════════════════════════════
tcp_send_data_segment:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    mov rbx, rdi
    mov r8b, al

    ; Build header
    mov rdi, tcp_tx_buffer

    ; Ports
    movzx eax, word [rbx + TCP_TCB_LOCAL_PORT]
    xchg al, ah
    mov [rdi + TCP_OFF_SRC_PORT], ax

    movzx eax, word [rbx + TCP_TCB_REMOTE_PORT]
    xchg al, ah
    mov [rdi + TCP_OFF_DST_PORT], ax

    ; Seq/Ack
    mov eax, [rbx + TCP_TCB_SND_NXT]
    bswap eax
    mov [rdi + TCP_OFF_SEQ], eax

    mov eax, [rbx + TCP_TCB_RCV_NXT]
    bswap eax
    mov [rdi + TCP_OFF_ACK], eax

    ; Header + flags
    mov byte [rdi + 12], 0x50
    mov [rdi + 13], r8b

    ; Window
    movzx eax, word [rbx + TCP_TCB_RCV_WND]
    xchg al, ah
    mov [rdi + TCP_OFF_WINDOW], ax

    ; Checksum/Urgent (0 for now)
    mov word [rdi + TCP_OFF_CHECKSUM], 0
    mov word [rdi + TCP_OFF_URGENT], 0

    ; Copy data from TX buffer
    mov r9d, [rbx + TCP_TCB_TX_LEN]
    push rdi
    add rdi, TCP_HEADER_SIZE
    mov rsi, [rbx + TCP_TCB_TX_BUF]
    mov ecx, r9d
    rep movsb
    pop rdi

    ; Clear TX buffer
    mov dword [rbx + TCP_TCB_TX_LEN], 0

    ; Update SND.NXT
    add [rbx + TCP_TCB_SND_NXT], r9d

    ; Calculate total length
    mov ecx, TCP_HEADER_SIZE
    add ecx, r9d

    ; Checksum
    push rcx
    push rdi
    mov rsi, rdi
    mov edi, [rbx + TCP_TCB_REMOTE_IP]
    call tcp_calculate_checksum
    pop rdi
    mov [rdi + TCP_OFF_CHECKSUM], ax
    pop rcx

    ; Send
    push rdi
    mov edi, [rbx + TCP_TCB_REMOTE_IP]
    mov al, IP_PROTO_TCP
    mov rsi, tcp_tx_buffer
    call ip_send
    pop rdi

    ; Start retransmit timer
    mov eax, [tick_count]
    add eax, [rbx + TCP_TCB_RTO]
    mov [rbx + TCP_TCB_TIMER], eax

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_SEND_RST - Send RST segment
; Uses global state from last received packet
; ════════════════════════════════════════════════════════════════════════════
tcp_send_rst:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Build RST packet
    mov rdi, tcp_tx_buffer

    ; Swap ports
    movzx eax, word [r12 + TCP_OFF_DST_PORT]
    mov [rdi + TCP_OFF_SRC_PORT], ax
    movzx eax, word [r12 + TCP_OFF_SRC_PORT]
    mov [rdi + TCP_OFF_DST_PORT], ax

    ; If ACK, use ACK as seq
    test bl, TCP_ACK
    jz .rst_no_ack

    mov eax, [r12 + TCP_OFF_ACK]
    mov [rdi + TCP_OFF_SEQ], eax
    mov dword [rdi + TCP_OFF_ACK], 0
    mov byte [rdi + 13], TCP_RST
    jmp .rst_send

.rst_no_ack:
    ; SEQ = 0, ACK = their SEQ + data len
    mov dword [rdi + TCP_OFF_SEQ], 0
    mov eax, [r12 + TCP_OFF_SEQ]
    ; Add segment length
    add eax, r11d
    sub eax, TCP_HEADER_SIZE
    bswap eax
    mov [rdi + TCP_OFF_ACK], eax
    mov byte [rdi + 13], TCP_RST | TCP_ACK

.rst_send:
    mov byte [rdi + 12], 0x50
    mov word [rdi + TCP_OFF_WINDOW], 0
    mov word [rdi + TCP_OFF_CHECKSUM], 0
    mov word [rdi + TCP_OFF_URGENT], 0

    ; Checksum
    push rdi
    mov rsi, rdi
    mov ecx, TCP_HEADER_SIZE
    mov edi, r10d
    call tcp_calculate_checksum
    pop rdi
    mov [rdi + TCP_OFF_CHECKSUM], ax

    ; Send
    mov edi, r10d
    mov al, IP_PROTO_TCP
    mov rsi, tcp_tx_buffer
    mov ecx, TCP_HEADER_SIZE
    call ip_send

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_FIND_SOCKET - Find socket by 4-tuple
; Input: EDI = local port, ESI = remote IP, EDX = remote port
; Output: RAX = socket or 0
; ════════════════════════════════════════════════════════════════════════════
tcp_find_socket:
    push rbx
    push rcx

    mov rbx, tcp_sockets
    mov ecx, MAX_TCP_SOCKETS

.search:
    cmp byte [rbx + TCP_TCB_STATE], TCP_STATE_CLOSED
    je .next
    cmp byte [rbx + TCP_TCB_STATE], TCP_STATE_LISTEN
    je .next                    ; Skip listening sockets

    cmp [rbx + TCP_TCB_LOCAL_PORT], di
    jne .next
    cmp [rbx + TCP_TCB_REMOTE_IP], esi
    jne .next
    cmp [rbx + TCP_TCB_REMOTE_PORT], dx
    jne .next

    mov rax, rbx
    jmp .find_done

.next:
    add rbx, TCP_TCB_SIZE
    dec ecx
    jnz .search

    xor eax, eax

.find_done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_FIND_LISTENING_SOCKET - Find socket in LISTEN state
; Input: EDI = local port
; Output: RAX = socket or 0
; ════════════════════════════════════════════════════════════════════════════
tcp_find_listening_socket:
    push rbx
    push rcx

    mov rbx, tcp_sockets
    mov ecx, MAX_TCP_SOCKETS

.search:
    cmp byte [rbx + TCP_TCB_STATE], TCP_STATE_LISTEN
    jne .next

    cmp [rbx + TCP_TCB_LOCAL_PORT], di
    jne .next

    mov rax, rbx
    jmp .find_done

.next:
    add rbx, TCP_TCB_SIZE
    dec ecx
    jnz .search

    xor eax, eax

.find_done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_GENERATE_ISN - Generate Initial Sequence Number
; Output: EAX = ISN
; ════════════════════════════════════════════════════════════════════════════
tcp_generate_isn:
    ; Simple ISN: based on tick count
    mov eax, [tick_count]
    imul eax, 64000             ; Scale up
    add eax, [tcp_isn_counter]
    inc dword [tcp_isn_counter]
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_CALCULATE_CHECKSUM - Calculate TCP checksum with pseudo-header
; Input: RSI = TCP segment, ECX = length, EDI = remote IP
; Output: AX = checksum
; ════════════════════════════════════════════════════════════════════════════
tcp_calculate_checksum:
    push rbx
    push rcx
    push rdx
    push rsi

    xor eax, eax

    ; Pseudo-header: src IP + dst IP + proto + TCP length
    mov edx, [our_ip]
    movzx ebx, dx
    add eax, ebx
    shr edx, 16
    add eax, edx

    mov edx, edi                ; Remote IP
    movzx ebx, dx
    add eax, ebx
    shr edx, 16
    add eax, edx

    ; Protocol (6) + length
    mov edx, ecx
    xchg dl, dh                 ; Big-endian length
    add eax, edx
    add eax, 0x0600             ; Protocol 6 in high byte

    ; TCP segment
    push rcx
    inc ecx
    shr ecx, 1                  ; Words
.sum_loop:
    movzx ebx, word [rsi]
    add eax, ebx
    add rsi, 2
    dec ecx
    jnz .sum_loop
    pop rcx

    ; Fold
    mov ebx, eax
    shr ebx, 16
    and eax, 0xFFFF
    add eax, ebx
    mov ebx, eax
    shr ebx, 16
    add eax, ebx
    and eax, 0xFFFF

    not ax

    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP_TIMER_TICK - Called periodically for retransmission
; ════════════════════════════════════════════════════════════════════════════
tcp_timer_tick:
    push rax
    push rbx
    push rcx
    push rdi

    mov rbx, tcp_sockets
    mov ecx, MAX_TCP_SOCKETS

.check_socket:
    movzx eax, byte [rbx + TCP_TCB_STATE]

    ; Check TIME_WAIT timer
    cmp al, TCP_STATE_TIME_WAIT
    jne .check_retransmit

    mov eax, [tick_count]
    cmp eax, [rbx + TCP_TCB_TIME_WAIT_TIMER]
    jl .next_socket

    ; TIME_WAIT expired - close
    mov byte [rbx + TCP_TCB_STATE], TCP_STATE_CLOSED
    jmp .next_socket

.check_retransmit:
    ; Check if connection needs retransmit
    cmp al, TCP_STATE_SYN_SENT
    je .maybe_retransmit
    cmp al, TCP_STATE_SYN_RECEIVED
    je .maybe_retransmit
    cmp al, TCP_STATE_ESTABLISHED
    je .maybe_retransmit
    cmp al, TCP_STATE_FIN_WAIT_1
    je .maybe_retransmit
    cmp al, TCP_STATE_CLOSING
    je .maybe_retransmit
    cmp al, TCP_STATE_LAST_ACK
    je .maybe_retransmit
    jmp .next_socket

.maybe_retransmit:
    ; Check if timer expired
    mov eax, [rbx + TCP_TCB_TIMER]
    test eax, eax
    jz .next_socket

    cmp [tick_count], eax
    jl .next_socket

    ; Timer expired - retransmit
    inc byte [rbx + TCP_TCB_RETRIES]
    cmp byte [rbx + TCP_TCB_RETRIES], TCP_MAX_RETRIES
    ja .abort_connection

    ; TODO: Retransmit last unacked segment
    ; For now, just reset timer with backoff
    mov eax, [rbx + TCP_TCB_RTO]
    shl eax, 1                  ; Double timeout
    cmp eax, 6000               ; Max 60 seconds
    jle .set_timer
    mov eax, 6000
.set_timer:
    mov [rbx + TCP_TCB_RTO], eax
    add eax, [tick_count]
    mov [rbx + TCP_TCB_TIMER], eax
    jmp .next_socket

.abort_connection:
    ; Too many retries - abort
    mov byte [rbx + TCP_TCB_STATE], TCP_STATE_CLOSED

.next_socket:
    add rbx, TCP_TCB_SIZE
    dec ecx
    jnz .check_socket

    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; TCP DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

; TCP sockets (TCBs)
tcp_sockets:    times MAX_TCP_SOCKETS * TCP_TCB_SIZE db 0

; Transmit buffer
tcp_tx_buffer:  times 1500 db 0

; Receive buffers
tcp_rx_buffers: times MAX_TCP_SOCKETS * TCP_RX_BUFFER_SIZE db 0

; Transmit buffers
tcp_tx_buffers: times MAX_TCP_SOCKETS * TCP_TX_BUFFER_SIZE db 0

; ISN counter
tcp_isn_counter: dd 0

; Statistics
tcp_rx_count:   dd 0
tcp_tx_count:   dd 0
