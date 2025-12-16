; ════════════════════════════════════════════════════════════════════════════
; ARP.ASM - Address Resolution Protocol
; Maps IP addresses to MAC addresses
; ════════════════════════════════════════════════════════════════════════════
; ARP Packet Structure (28 bytes):
;   +0:  Hardware Type     (2 bytes) - 0x0001 = Ethernet
;   +2:  Protocol Type     (2 bytes) - 0x0800 = IPv4
;   +4:  Hardware Addr Len (1 byte)  - 6 for MAC
;   +5:  Protocol Addr Len (1 byte)  - 4 for IPv4
;   +6:  Operation         (2 bytes) - 1=Request, 2=Reply
;   +8:  Sender MAC        (6 bytes)
;   +14: Sender IP         (4 bytes)
;   +18: Target MAC        (6 bytes)
;   +24: Target IP         (4 bytes)
; ════════════════════════════════════════════════════════════════════════════

; ARP Constants
ARP_HARDWARE_ETHERNET   equ 0x0001
ARP_PROTOCOL_IPV4       equ 0x0800
ARP_OP_REQUEST          equ 1
ARP_OP_REPLY            equ 2

; EtherType for ARP
ETHERTYPE_ARP           equ 0x0806
ETHERTYPE_IPV4          equ 0x0800

; ARP Cache constants
ARP_CACHE_SIZE          equ 16          ; Max entries in ARP cache
ARP_ENTRY_SIZE          equ 16          ; 4 bytes IP + 6 bytes MAC + 2 bytes flags + 4 bytes timeout
ARP_ENTRY_VALID         equ 0x01
ARP_ENTRY_STATIC        equ 0x02

; Timeouts (in ticks, 100Hz = 10ms per tick)
ARP_CACHE_TIMEOUT       equ 30000       ; 5 minutes
ARP_REQUEST_TIMEOUT     equ 100         ; 1 second

; ════════════════════════════════════════════════════════════════════════════
; ARP_INIT - Initialize ARP subsystem
; ════════════════════════════════════════════════════════════════════════════
arp_init:
    push rax
    push rcx
    push rdi

    ; Clear ARP cache
    mov rdi, arp_cache
    mov rcx, ARP_CACHE_SIZE * ARP_ENTRY_SIZE
    xor al, al
    rep stosb

    ; Set our IP address (default: 10.0.2.15 - QEMU user mode)
    mov dword [our_ip], 0x0F02000A      ; 10.0.2.15 in little-endian

    ; Set gateway IP (default: 10.0.2.2 - QEMU gateway)
    mov dword [gateway_ip], 0x0202000A  ; 10.0.2.2

    ; Set subnet mask (default: 255.255.255.0)
    mov dword [subnet_mask], 0x00FFFFFF ; 255.255.255.0

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ARP_LOOKUP - Look up MAC address for an IP
; Input: EDI = IP address (network byte order)
; Output: RAX = pointer to MAC (6 bytes) or 0 if not found
; ════════════════════════════════════════════════════════════════════════════
arp_lookup:
    push rbx
    push rcx
    push rdx

    ; Search ARP cache
    mov rbx, arp_cache
    mov ecx, ARP_CACHE_SIZE

.search_loop:
    ; Check if entry is valid
    test byte [rbx + 10], ARP_ENTRY_VALID
    jz .next_entry

    ; Compare IP address
    cmp [rbx], edi
    je .found

.next_entry:
    add rbx, ARP_ENTRY_SIZE
    dec ecx
    jnz .search_loop

    ; Not found
    xor eax, eax
    jmp .lookup_done

.found:
    ; Return pointer to MAC address (offset +4 in entry)
    lea rax, [rbx + 4]

.lookup_done:
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ARP_ADD_ENTRY - Add entry to ARP cache
; Input: EDI = IP address, RSI = pointer to MAC address (6 bytes)
; ════════════════════════════════════════════════════════════════════════════
arp_add_entry:
    push rax
    push rbx
    push rcx
    push rdx

    ; First check if entry already exists
    push rdi
    call arp_lookup
    pop rdi
    test rax, rax
    jnz .update_existing

    ; Find free slot or oldest entry
    mov rbx, arp_cache
    mov rcx, ARP_CACHE_SIZE
    xor rdx, rdx                ; Best slot pointer
    mov r8d, 0xFFFFFFFF         ; Oldest timeout

.find_slot:
    ; Check if slot is free
    test byte [rbx + 10], ARP_ENTRY_VALID
    jz .use_slot

    ; Check if this entry is older
    mov eax, [rbx + 12]         ; Timeout field
    cmp eax, r8d
    jae .not_older

    ; This is older
    mov r8d, eax
    mov rdx, rbx

.not_older:
    add rbx, ARP_ENTRY_SIZE
    dec ecx
    jnz .find_slot

    ; Use oldest slot if no free slot found
    test rdx, rdx
    jz .add_done                ; Cache full, no old entries (shouldn't happen)
    mov rbx, rdx

.use_slot:
    ; Store IP address
    mov [rbx], edi

    ; Copy MAC address
    push rdi
    push rsi
    lea rdi, [rbx + 4]
    mov rcx, 6
    rep movsb
    pop rsi
    pop rdi

    ; Set flags and timeout
    mov byte [rbx + 10], ARP_ENTRY_VALID
    mov byte [rbx + 11], 0
    mov eax, [tick_count]
    add eax, ARP_CACHE_TIMEOUT
    mov [rbx + 12], eax

    jmp .add_done

.update_existing:
    ; RAX points to MAC in existing entry
    ; Update MAC address
    mov rdi, rax
    mov rcx, 6
    rep movsb

    ; Update timeout
    sub rax, 4                  ; Point to start of entry
    mov ecx, [tick_count]
    add ecx, ARP_CACHE_TIMEOUT
    mov [rax + 12], ecx

.add_done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ARP_SEND_REQUEST - Send ARP request for an IP address
; Input: EDI = target IP address
; ════════════════════════════════════════════════════════════════════════════
arp_send_request:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9

    mov r9d, edi                ; Save target IP

    ; Build ARP packet in arp_packet_buffer
    mov rdi, arp_packet_buffer

    ; Hardware type = Ethernet (0x0001) - big endian
    mov word [rdi], 0x0100
    add rdi, 2

    ; Protocol type = IPv4 (0x0800) - big endian
    mov word [rdi], 0x0008
    add rdi, 2

    ; Hardware address length = 6
    mov byte [rdi], 6
    inc rdi

    ; Protocol address length = 4
    mov byte [rdi], 4
    inc rdi

    ; Operation = Request (1) - big endian
    mov word [rdi], 0x0100
    add rdi, 2

    ; Sender MAC (our MAC)
    push rdi
    call e1000_get_mac          ; Gets MAC into RDI
    pop rdi
    mov rsi, e1000_mac
    mov rcx, 6
    rep movsb

    ; Sender IP (our IP) - already in network byte order
    mov eax, [our_ip]
    mov [rdi], eax
    add rdi, 4

    ; Target MAC (zeros for request)
    xor eax, eax
    mov [rdi], eax
    mov [rdi + 4], ax
    add rdi, 6

    ; Target IP
    mov [rdi], r9d
    add rdi, 4

    ; Calculate packet length (28 bytes ARP)
    mov r9, 28

    ; Send via E1000
    ; e1000_send_raw: RSI=src MAC, RDI=dst MAC, DX=EtherType, R8=payload, R9=len
    mov rsi, e1000_mac          ; Source MAC (our MAC)
    mov rdi, broadcast_mac      ; Destination MAC (broadcast)
    mov dx, ETHERTYPE_ARP       ; EtherType
    mov r8, arp_packet_buffer   ; Payload
    ; R9 already has length
    call e1000_send_raw

    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ARP_SEND_REPLY - Send ARP reply
; Input: EDI = target IP, RSI = target MAC (6 bytes)
; ════════════════════════════════════════════════════════════════════════════
arp_send_reply:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10

    mov r9d, edi                ; Save target IP
    mov r10, rsi                ; Save target MAC pointer

    ; Build ARP packet
    mov rdi, arp_packet_buffer

    ; Hardware type = Ethernet
    mov word [rdi], 0x0100
    add rdi, 2

    ; Protocol type = IPv4
    mov word [rdi], 0x0008
    add rdi, 2

    ; Hardware/Protocol address lengths
    mov byte [rdi], 6
    mov byte [rdi + 1], 4
    add rdi, 2

    ; Operation = Reply (2) - big endian
    mov word [rdi], 0x0200
    add rdi, 2

    ; Sender MAC (our MAC)
    mov rsi, e1000_mac
    mov rcx, 6
    rep movsb

    ; Sender IP (our IP)
    mov eax, [our_ip]
    mov [rdi], eax
    add rdi, 4

    ; Target MAC
    mov rsi, r10
    mov rcx, 6
    rep movsb

    ; Target IP
    mov [rdi], r9d

    ; Send via E1000
    mov rsi, e1000_mac          ; Source MAC
    mov rdi, r10                ; Destination MAC
    mov dx, ETHERTYPE_ARP
    mov r8, arp_packet_buffer
    mov r9, 28
    call e1000_send_raw

    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ARP_HANDLE_PACKET - Process received ARP packet
; Input: RSI = pointer to ARP packet (after Ethernet header), RCX = length
; ════════════════════════════════════════════════════════════════════════════
arp_handle_packet:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Verify minimum length
    cmp rcx, 28
    jl .arp_done

    ; Check hardware type (Ethernet)
    mov ax, [rsi]
    cmp ax, 0x0100              ; Big-endian 0x0001
    jne .arp_done

    ; Check protocol type (IPv4)
    mov ax, [rsi + 2]
    cmp ax, 0x0008              ; Big-endian 0x0800
    jne .arp_done

    ; Check address lengths
    cmp byte [rsi + 4], 6       ; MAC length
    jne .arp_done
    cmp byte [rsi + 5], 4       ; IP length
    jne .arp_done

    ; Get operation
    mov ax, [rsi + 6]

    ; Always add sender to our cache
    mov edi, [rsi + 14]         ; Sender IP
    lea rbx, [rsi + 8]          ; Sender MAC
    push rsi
    mov rsi, rbx
    call arp_add_entry
    pop rsi

    ; Check operation
    cmp ax, 0x0100              ; Request (big-endian 1)
    je .arp_request
    cmp ax, 0x0200              ; Reply (big-endian 2)
    je .arp_reply
    jmp .arp_done

.arp_request:
    ; Check if target IP is ours
    mov eax, [rsi + 24]         ; Target IP
    cmp eax, [our_ip]
    jne .arp_done

    ; Send reply
    mov edi, [rsi + 14]         ; Requester's IP
    lea rsi, [rsi + 8]          ; Requester's MAC
    call arp_send_reply

    inc dword [arp_requests_received]
    jmp .arp_done

.arp_reply:
    ; Reply already added to cache above
    inc dword [arp_replies_received]

.arp_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ARP_RESOLVE - Resolve IP to MAC (blocking, with retry)
; Input: EDI = IP address
; Output: RAX = pointer to MAC or 0 if failed
; ════════════════════════════════════════════════════════════════════════════
arp_resolve:
    push rbx
    push rcx
    push rdx
    push rdi

    mov ebx, edi                ; Save IP

    ; First check cache
    call arp_lookup
    test rax, rax
    jnz .resolve_done           ; Found in cache

    ; Not in cache - send ARP request
    mov edi, ebx
    call arp_send_request

    ; Wait for reply (poll with timeout)
    mov ecx, 300                ; 3 second timeout (300 * 10ms)

.wait_reply:
    push rcx

    ; Small delay
    mov rcx, 10000
.delay:
    pause
    dec rcx
    jnz .delay

    ; Poll for received packets
    call net_poll

    ; Check cache again
    mov edi, ebx
    call arp_lookup

    pop rcx
    test rax, rax
    jnz .resolve_done           ; Got reply

    dec ecx
    jnz .wait_reply

    ; Timeout - return failure
    xor eax, eax

.resolve_done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ARP_GET_GATEWAY_MAC - Get MAC address of default gateway
; Output: RAX = pointer to gateway MAC or 0
; ════════════════════════════════════════════════════════════════════════════
arp_get_gateway_mac:
    mov edi, [gateway_ip]
    call arp_resolve
    ret

; ════════════════════════════════════════════════════════════════════════════
; NET_POLL - Poll network for received packets and dispatch
; Called from main loop or when waiting for ARP
; ════════════════════════════════════════════════════════════════════════════
net_poll:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

.poll_loop:
    ; Check for received packet
    call e1000_rx_poll
    test eax, eax
    jz .poll_done               ; No packet

    ; RAX = length, RDI = buffer
    mov rcx, rax                ; Save length
    mov rsi, rdi                ; RSI = packet buffer

    ; Parse Ethernet header
    ; +0: Destination MAC (6 bytes)
    ; +6: Source MAC (6 bytes)
    ; +12: EtherType (2 bytes, big-endian)

    cmp rcx, 14
    jl .poll_loop               ; Too short

    ; Get EtherType
    movzx eax, word [rsi + 12]
    xchg al, ah                 ; Convert to little-endian

    ; Dispatch based on EtherType
    cmp ax, ETHERTYPE_ARP
    je .handle_arp
    cmp ax, ETHERTYPE_IPV4
    je .handle_ip
    jmp .poll_loop              ; Unknown, get next packet

.handle_arp:
    ; Skip Ethernet header
    add rsi, 14
    sub rcx, 14
    call arp_handle_packet
    jmp .poll_loop

.handle_ip:
    ; Skip Ethernet header
    add rsi, 14
    sub rcx, 14
    call ip_handle_packet       ; Will be implemented later
    jmp .poll_loop

.poll_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ARP DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

; Our network configuration
our_ip:         dd 0x0F02000A   ; 10.0.2.15 (QEMU default)
gateway_ip:     dd 0x0202000A   ; 10.0.2.2 (QEMU gateway)
subnet_mask:    dd 0x00FFFFFF   ; 255.255.255.0

; ARP packet buffer (28 bytes)
arp_packet_buffer: times 32 db 0

; ARP cache: 16 entries x 16 bytes each
; Entry format: IP(4) + MAC(6) + flags(1) + reserved(1) + timeout(4)
arp_cache:      times ARP_CACHE_SIZE * ARP_ENTRY_SIZE db 0

; Statistics
arp_requests_sent:      dd 0
arp_requests_received:  dd 0
arp_replies_sent:       dd 0
arp_replies_received:   dd 0
