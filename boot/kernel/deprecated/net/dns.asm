; ════════════════════════════════════════════════════════════════════════════
; DNS.ASM - Domain Name System Resolver
; Converts hostnames to IP addresses
; ════════════════════════════════════════════════════════════════════════════
; DNS Query Structure:
;   Header (12 bytes) + Question + Answer
;
; Header:
;   +0:  Transaction ID (2 bytes)
;   +2:  Flags (2 bytes) - QR|Opcode|AA|TC|RD|RA|Z|RCODE
;   +4:  Questions (2 bytes)
;   +6:  Answers (2 bytes)
;   +8:  Authority RRs (2 bytes)
;   +10: Additional RRs (2 bytes)
;
; Question:
;   QNAME: labels (length-prefixed strings, null terminated)
;   QTYPE: 2 bytes (A=1, AAAA=28, CNAME=5, MX=15)
;   QCLASS: 2 bytes (IN=1)
; ════════════════════════════════════════════════════════════════════════════

; DNS Port
DNS_PORT            equ 53

; DNS Header offsets
DNS_OFF_ID          equ 0
DNS_OFF_FLAGS       equ 2
DNS_OFF_QDCOUNT     equ 4
DNS_OFF_ANCOUNT     equ 6
DNS_OFF_NSCOUNT     equ 8
DNS_OFF_ARCOUNT     equ 10
DNS_HEADER_SIZE     equ 12

; DNS Flags
DNS_FLAG_QR         equ 0x8000      ; Query/Response (1=response)
DNS_FLAG_RD         equ 0x0100      ; Recursion Desired
DNS_FLAG_RA         equ 0x0080      ; Recursion Available
DNS_FLAG_RCODE_MASK equ 0x000F      ; Response code

; DNS Record Types
DNS_TYPE_A          equ 1           ; IPv4 address
DNS_TYPE_NS         equ 2           ; Name server
DNS_TYPE_CNAME      equ 5           ; Canonical name
DNS_TYPE_SOA        equ 6           ; Start of authority
DNS_TYPE_MX         equ 15          ; Mail exchange
DNS_TYPE_TXT        equ 16          ; Text record
DNS_TYPE_AAAA       equ 28          ; IPv6 address

; DNS Class
DNS_CLASS_IN        equ 1           ; Internet

; DNS Cache
DNS_CACHE_ENTRIES   equ 8
DNS_CACHE_ENTRY_SIZE equ 72         ; 64 bytes name + 4 bytes IP + 4 bytes TTL
DNS_MAX_NAME_LEN    equ 64

; Timeouts
DNS_TIMEOUT_MS      equ 3000        ; 3 seconds
DNS_MAX_RETRIES     equ 3

; ════════════════════════════════════════════════════════════════════════════
; DNS_INIT - Initialize DNS resolver
; ════════════════════════════════════════════════════════════════════════════
dns_init:
    push rax
    push rcx
    push rdi

    ; Clear DNS cache
    mov rdi, dns_cache
    mov ecx, DNS_CACHE_ENTRIES * DNS_CACHE_ENTRY_SIZE
    xor al, al
    rep stosb

    ; Initialize transaction ID
    mov word [dns_txid], 0x1234

    ; Set default DNS server (will be updated by DHCP)
    mov dword [dns_server], 0x08080808  ; 8.8.8.8 default

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DNS_RESOLVE - Resolve hostname to IP address
; Input: RSI = hostname (null-terminated string, e.g., "google.com")
; Output: EAX = IP address (0 on failure)
; ════════════════════════════════════════════════════════════════════════════
dns_resolve:
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

    mov r12, rsi                    ; Save hostname

    ; Check cache first
    call dns_cache_lookup
    test eax, eax
    jnz .resolve_done               ; Cache hit

    ; Create UDP socket
    call udp_socket_create
    test rax, rax
    jz .resolve_failed
    mov r10, rax                    ; R10 = socket

    ; Bind to ephemeral port
    mov rdi, r10
    mov esi, 5353                   ; Local port
    call udp_socket_bind

    ; Retry loop
    mov r11d, DNS_MAX_RETRIES

.retry_loop:
    ; Build DNS query
    mov rsi, r12                    ; Hostname
    call dns_build_query            ; RAX = query length

    ; Send query
    mov rdi, r10                    ; Socket
    mov esi, [dns_server]           ; DNS server IP
    mov edx, DNS_PORT               ; DNS port
    mov r8, dns_query_buffer
    mov r9, rax                     ; Query length
    call udp_send

    cmp eax, -1
    je .retry_next

    ; Wait for response
    mov ecx, DNS_TIMEOUT_MS / 10    ; Number of poll iterations

.wait_response:
    push rcx

    ; Poll network
    call e1000_rx_poll
    test rax, rax
    jz .no_packet

    ; Process any received packets
    mov rsi, rdi                    ; RSI = packet buffer
    mov ecx, eax                    ; ECX = length
    call net_process_packet

.no_packet:
    ; Try to receive from UDP socket
    mov rdi, r10
    mov rsi, dns_response_buffer
    mov edx, 512
    call udp_recv

    pop rcx
    test eax, eax
    jnz .got_response

    ; Small delay
    push rcx
    mov ecx, 10000
.delay:
    pause
    dec ecx
    jnz .delay
    pop rcx

    dec ecx
    jnz .wait_response

.retry_next:
    dec r11d
    jnz .retry_loop
    jmp .resolve_cleanup_fail

.got_response:
    ; Parse DNS response
    mov rsi, dns_response_buffer
    mov ecx, eax                    ; Response length
    call dns_parse_response

    ; EAX = resolved IP (or 0)
    test eax, eax
    jz .resolve_cleanup_fail

    ; Add to cache
    push rax
    mov rdi, r12                    ; Hostname
    mov esi, eax                    ; IP
    mov edx, 300                    ; TTL (5 minutes default)
    call dns_cache_add
    pop rax

    ; Close socket
    mov rdi, r10
    push rax
    call udp_socket_close
    pop rax

    jmp .resolve_done

.resolve_cleanup_fail:
    mov rdi, r10
    call udp_socket_close

.resolve_failed:
    xor eax, eax

.resolve_done:
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
; DNS_BUILD_QUERY - Build DNS query packet
; Input: RSI = hostname
; Output: RAX = query length
; ════════════════════════════════════════════════════════════════════════════
dns_build_query:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    mov rbx, dns_query_buffer

    ; Transaction ID (increment)
    mov ax, [dns_txid]
    inc word [dns_txid]
    xchg al, ah                     ; Big-endian
    mov [rbx + DNS_OFF_ID], ax

    ; Flags: standard query, recursion desired
    mov word [rbx + DNS_OFF_FLAGS], 0x0001  ; RD=1 (big-endian: 0x0100)

    ; Question count = 1
    mov word [rbx + DNS_OFF_QDCOUNT], 0x0100

    ; Answer/Authority/Additional = 0
    mov word [rbx + DNS_OFF_ANCOUNT], 0
    mov word [rbx + DNS_OFF_NSCOUNT], 0
    mov word [rbx + DNS_OFF_ARCOUNT], 0

    ; Build QNAME (convert "google.com" to 6google3com0)
    lea rdi, [rbx + DNS_HEADER_SIZE]

    ; RSI = hostname
.encode_label:
    ; Find next dot or end
    mov rcx, rsi
    xor edx, edx                    ; Label length

.find_dot:
    mov al, [rcx]
    test al, al
    jz .end_of_name
    cmp al, '.'
    je .found_dot
    inc rcx
    inc edx
    jmp .find_dot

.found_dot:
    ; Write label length
    mov [rdi], dl
    inc rdi

    ; Copy label
    mov ecx, edx
    rep movsb

    ; Skip dot
    inc rsi
    jmp .encode_label

.end_of_name:
    ; Write last label
    test edx, edx
    jz .name_done

    mov [rdi], dl
    inc rdi
    mov ecx, edx
    rep movsb

.name_done:
    ; Null terminator
    mov byte [rdi], 0
    inc rdi

    ; QTYPE = A (1)
    mov word [rdi], 0x0100          ; Big-endian
    add rdi, 2

    ; QCLASS = IN (1)
    mov word [rdi], 0x0100          ; Big-endian
    add rdi, 2

    ; Calculate length
    mov rax, rdi
    sub rax, rbx

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DNS_PARSE_RESPONSE - Parse DNS response
; Input: RSI = response buffer, ECX = length
; Output: EAX = IP address (0 on error)
; ════════════════════════════════════════════════════════════════════════════
dns_parse_response:
    push rbx
    push rcx
    push rdx
    push rdi

    ; Verify minimum length
    cmp ecx, DNS_HEADER_SIZE
    jl .parse_error

    mov rbx, rsi

    ; Check QR bit (must be response)
    mov ax, [rbx + DNS_OFF_FLAGS]
    xchg al, ah
    test ax, DNS_FLAG_QR
    jz .parse_error

    ; Check RCODE (must be 0 = no error)
    and ax, DNS_FLAG_RCODE_MASK
    jnz .parse_error

    ; Get answer count
    movzx ecx, word [rbx + DNS_OFF_ANCOUNT]
    xchg cl, ch                     ; Little-endian
    test ecx, ecx
    jz .parse_error                 ; No answers

    ; Skip header
    lea rsi, [rbx + DNS_HEADER_SIZE]

    ; Skip question section
    call dns_skip_name
    add rsi, 4                      ; Skip QTYPE + QCLASS

    ; Parse answers
.parse_answer:
    ; Skip/decompress name
    call dns_skip_name

    ; Get TYPE
    movzx eax, word [rsi]
    xchg al, ah
    add rsi, 2

    ; Get CLASS
    movzx edx, word [rsi]
    xchg dl, dh
    add rsi, 2

    ; Skip TTL
    add rsi, 4

    ; Get RDLENGTH
    movzx edx, word [rsi]
    xchg dl, dh
    add rsi, 2

    ; Check if A record
    cmp eax, DNS_TYPE_A
    jne .skip_rdata

    ; Check length (must be 4 for IPv4)
    cmp edx, 4
    jne .skip_rdata

    ; Get IP address
    mov eax, [rsi]
    jmp .parse_done

.skip_rdata:
    add rsi, rdx
    dec ecx
    jnz .parse_answer

.parse_error:
    xor eax, eax

.parse_done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DNS_SKIP_NAME - Skip DNS name (handles compression)
; Input: RSI = pointer to name
; Output: RSI = pointer after name
; ════════════════════════════════════════════════════════════════════════════
dns_skip_name:
    push rax
    push rcx

.skip_loop:
    movzx eax, byte [rsi]
    test al, al
    jz .skip_end

    ; Check for compression pointer (top 2 bits = 11)
    test al, 0xC0
    jnz .skip_pointer

    ; Regular label - skip length + data
    inc rsi
    add rsi, rax
    jmp .skip_loop

.skip_pointer:
    ; Compression pointer - 2 bytes
    add rsi, 2
    jmp .skip_done

.skip_end:
    inc rsi                         ; Skip null terminator

.skip_done:
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DNS_CACHE_LOOKUP - Look up hostname in cache
; Input: RSI = hostname
; Output: EAX = IP address (0 if not found)
; ════════════════════════════════════════════════════════════════════════════
dns_cache_lookup:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov r8, rsi                     ; Save hostname
    mov rbx, dns_cache
    mov ecx, DNS_CACHE_ENTRIES

.cache_search:
    ; Check if entry is valid (first byte non-zero)
    cmp byte [rbx], 0
    je .cache_next

    ; Compare hostname
    mov rsi, r8
    mov rdi, rbx
    call dns_strcmp
    test eax, eax
    jz .cache_found

.cache_next:
    add rbx, DNS_CACHE_ENTRY_SIZE
    dec ecx
    jnz .cache_search

    ; Not found
    xor eax, eax
    jmp .cache_lookup_done

.cache_found:
    ; Return IP address
    mov eax, [rbx + DNS_MAX_NAME_LEN]

.cache_lookup_done:
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DNS_CACHE_ADD - Add entry to DNS cache
; Input: RDI = hostname, ESI = IP address, EDX = TTL
; ════════════════════════════════════════════════════════════════════════════
dns_cache_add:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    mov r8, rdi                     ; Hostname
    mov r9d, esi                    ; IP

    ; Find free slot or oldest entry
    mov rbx, dns_cache
    mov rcx, DNS_CACHE_ENTRIES
    mov rax, rbx                    ; Default to first entry

.find_slot:
    cmp byte [rbx], 0
    je .slot_found
    add rbx, DNS_CACHE_ENTRY_SIZE
    dec ecx
    jnz .find_slot

    ; Use LRU slot (just use next in round-robin for simplicity)
    movzx eax, byte [dns_cache_index]
    inc byte [dns_cache_index]
    and byte [dns_cache_index], DNS_CACHE_ENTRIES - 1

    imul eax, DNS_CACHE_ENTRY_SIZE
    lea rbx, [dns_cache + rax]

.slot_found:
    ; Copy hostname
    mov rdi, rbx
    mov rsi, r8
    mov ecx, DNS_MAX_NAME_LEN - 1

.copy_name:
    lodsb
    stosb
    test al, al
    jz .name_copied
    dec ecx
    jnz .copy_name
    mov byte [rdi], 0               ; Null terminate

.name_copied:
    ; Store IP
    mov [rbx + DNS_MAX_NAME_LEN], r9d

    ; Store TTL (simplified - just store as is)
    mov [rbx + DNS_MAX_NAME_LEN + 4], edx

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
; DNS_STRCMP - Compare two strings (case-insensitive)
; Input: RSI = string1, RDI = string2
; Output: EAX = 0 if equal, non-zero if different
; ════════════════════════════════════════════════════════════════════════════
dns_strcmp:
    push rbx
    push rcx
    push rsi
    push rdi

.cmp_loop:
    mov al, [rsi]
    mov bl, [rdi]

    ; Convert to lowercase
    cmp al, 'A'
    jb .no_lower1
    cmp al, 'Z'
    ja .no_lower1
    add al, 32

.no_lower1:
    cmp bl, 'A'
    jb .no_lower2
    cmp bl, 'Z'
    ja .no_lower2
    add bl, 32

.no_lower2:
    cmp al, bl
    jne .not_equal

    test al, al
    jz .equal

    inc rsi
    inc rdi
    jmp .cmp_loop

.equal:
    xor eax, eax
    jmp .cmp_done

.not_equal:
    mov eax, 1

.cmp_done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DNS_SET_SERVER - Set DNS server address
; Input: EDI = DNS server IP
; ════════════════════════════════════════════════════════════════════════════
dns_set_server:
    mov [dns_server], edi
    ret

; ════════════════════════════════════════════════════════════════════════════
; DNS_GET_SERVER - Get current DNS server
; Output: EAX = DNS server IP
; ════════════════════════════════════════════════════════════════════════════
dns_get_server:
    mov eax, [dns_server]
    ret

; ════════════════════════════════════════════════════════════════════════════
; Helper: NET_PROCESS_PACKET - Process a received network packet
; (Wrapper to trigger protocol handling)
; Input: RSI = packet, ECX = length
; ════════════════════════════════════════════════════════════════════════════
net_process_packet:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Check minimum ethernet frame
    cmp ecx, 14
    jl .process_done

    ; Get EtherType
    movzx eax, word [rsi + 12]
    xchg al, ah                     ; Big-endian to little

    ; Skip ethernet header
    add rsi, 14
    sub ecx, 14

    ; Check protocol
    cmp eax, 0x0800                 ; IPv4
    je .process_ip
    cmp eax, 0x0806                 ; ARP
    je .process_arp
    jmp .process_done

.process_arp:
    call arp_handle_packet
    jmp .process_done

.process_ip:
    call ip_handle_packet

.process_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DNS DATA SECTION
; ════════════════════════════════════════════════════════════════════════════
align 8

; DNS server IP (default: 8.8.8.8)
dns_server:         dd 0x08080808

; Transaction ID
dns_txid:           dw 0x1234

; Cache index (for round-robin replacement)
dns_cache_index:    db 0

; Query and response buffers
dns_query_buffer:   times 512 db 0
dns_response_buffer: times 512 db 0

; DNS Cache
; Each entry: 64 bytes name + 4 bytes IP + 4 bytes TTL
dns_cache:          times DNS_CACHE_ENTRIES * DNS_CACHE_ENTRY_SIZE db 0
