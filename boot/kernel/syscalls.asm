; ════════════════════════════════════════════════════════════════════════════
; SYSCALLS.ASM - Complete System Call Interface for MATHIS OS
; ════════════════════════════════════════════════════════════════════════════
; Linux-like syscall interface via INT 0x80
;
; Calling Convention:
;   RAX = syscall number
;   RDI = arg1, RSI = arg2, RDX = arg3, R10 = arg4, R8 = arg5, R9 = arg6
;   Return value in RAX (-1 = error, errno in RBX)
;
; Categories:
;   0-9:   File/Memory operations
;   10-19: Process management
;   20-31: Network (sockets)
;   32-39: System info
;   40-49: Graphics (OS-specific)
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; SYSCALL NUMBERS
; ════════════════════════════════════════════════════════════════════════════

; File/Memory (0-9)
SYS_READ        equ 0       ; read(fd, buf, count)
SYS_WRITE       equ 1       ; write(fd, buf, count)
SYS_OPEN        equ 2       ; open(path, flags, mode)
SYS_CLOSE       equ 3       ; close(fd)
SYS_STAT        equ 4       ; stat(path, statbuf)
SYS_FSTAT       equ 5       ; fstat(fd, statbuf)
SYS_MMAP        equ 6       ; mmap(addr, len, prot, flags, fd, off)
SYS_MUNMAP      equ 7       ; munmap(addr, len)
SYS_BRK         equ 8       ; brk(addr) - heap management
SYS_IOCTL       equ 9       ; ioctl(fd, cmd, arg)

; Process (10-19)
SYS_EXIT        equ 10      ; exit(status)
SYS_GETPID      equ 11      ; getpid()
SYS_GETPPID     equ 12      ; getppid()
SYS_FORK        equ 13      ; fork()
SYS_EXEC        equ 14      ; exec(path, argv, envp)
SYS_WAIT        equ 15      ; wait(pid, status, options)
SYS_KILL        equ 16      ; kill(pid, sig)
SYS_SLEEP       equ 17      ; sleep(milliseconds)
SYS_YIELD       equ 18      ; yield()
SYS_GETTIME     equ 19      ; gettime(timebuf)

; Network/Sockets (20-31)
SYS_SOCKET      equ 20      ; socket(domain, type, proto)
SYS_BIND        equ 21      ; bind(sockfd, addr, addrlen)
SYS_LISTEN      equ 22      ; listen(sockfd, backlog)
SYS_ACCEPT      equ 23      ; accept(sockfd, addr, addrlen)
SYS_CONNECT     equ 24      ; connect(sockfd, addr, addrlen)
SYS_SEND        equ 25      ; send(sockfd, buf, len, flags)
SYS_RECV        equ 26      ; recv(sockfd, buf, len, flags)
SYS_SENDTO      equ 27      ; sendto(sockfd, buf, len, flags, addr, addrlen)
SYS_RECVFROM    equ 28      ; recvfrom(sockfd, buf, len, flags, addr, addrlen)
SYS_SHUTDOWN    equ 29      ; shutdown(sockfd, how)
SYS_SETSOCKOPT  equ 30      ; setsockopt(sockfd, level, optname, optval, optlen)
SYS_GETSOCKOPT  equ 31      ; getsockopt(sockfd, level, optname, optval, optlen)

; System Info (32-39)
SYS_GETHOSTNAME equ 32      ; gethostname(name, len)
SYS_SETHOSTNAME equ 33      ; sethostname(name, len)
SYS_GETUID      equ 34      ; getuid()
SYS_SETUID      equ 35      ; setuid(uid)
SYS_UNAME       equ 36      ; uname(buf)
SYS_SYSINFO     equ 37      ; sysinfo(info)
SYS_REBOOT      equ 38      ; reboot(cmd)
SYS_SHUTDOWN_SYS equ 39     ; shutdown_system()

; Graphics - OS specific (40-49)
SYS_PUTPIXEL    equ 40      ; putpixel(x, y, color)
SYS_GETPIXEL    equ 41      ; getpixel(x, y)
SYS_DRAWRECT    equ 42      ; drawrect(x, y, w, h, color)
SYS_FILLRECT    equ 43      ; fillrect(x, y, w, h, color)
SYS_DRAWTEXT    equ 44      ; drawtext(x, y, str, color)
SYS_GETSCREENINFO equ 45    ; getscreeninfo(buf)
SYS_SETVIDEOMODE equ 46     ; setvideomode(mode)
SYS_COPYRECT    equ 47      ; copyrect(src_x, src_y, dst_x, dst_y, w, h)

; File flags
O_RDONLY        equ 0
O_WRONLY        equ 1
O_RDWR          equ 2
O_CREAT         equ 0x40
O_TRUNC         equ 0x200
O_APPEND        equ 0x400

; Socket domains
AF_INET         equ 2

; Socket types
SOCK_STREAM     equ 1       ; TCP
SOCK_DGRAM      equ 2       ; UDP
SOCK_RAW        equ 3       ; Raw IP

; Signals
SIGKILL         equ 9
SIGTERM         equ 15

; Error codes
ENOENT          equ 2       ; No such file
EBADF           equ 9       ; Bad file descriptor
ENOMEM          equ 12      ; Out of memory
EACCES          equ 13      ; Permission denied
EFAULT          equ 14      ; Bad address
EBUSY           equ 16      ; Device busy
EEXIST          equ 17      ; File exists
EINVAL          equ 22      ; Invalid argument
ENOSYS          equ 38      ; Function not implemented
ENOTSOCK        equ 88      ; Not a socket

; ════════════════════════════════════════════════════════════════════════════
; SYSCALL HANDLER (replaces old syscall_isr64)
; ════════════════════════════════════════════════════════════════════════════
syscall_handler:
    ; Save all registers
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; Check syscall number range
    cmp rax, SYSCALL_MAX
    ja .invalid_syscall

    ; Get handler from syscall table
    lea rbx, [syscall_table]
    mov rax, [rbx + rax * 8]
    test rax, rax
    jz .not_implemented

    ; Call the handler
    call rax
    jmp .syscall_return

.invalid_syscall:
.not_implemented:
    mov rax, -1
    mov rbx, ENOSYS

.syscall_return:
    ; Restore registers (RAX contains return value)
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    iretq

; ════════════════════════════════════════════════════════════════════════════
; SYSCALL TABLE
; ════════════════════════════════════════════════════════════════════════════
align 8
syscall_table:
    dq sys_read         ; 0
    dq sys_write        ; 1
    dq sys_open         ; 2
    dq sys_close        ; 3
    dq sys_stat         ; 4
    dq sys_fstat        ; 5
    dq sys_mmap         ; 6
    dq sys_munmap       ; 7
    dq sys_brk          ; 8
    dq sys_ioctl        ; 9
    dq sys_exit         ; 10
    dq sys_getpid       ; 11
    dq sys_getppid      ; 12
    dq sys_fork         ; 13
    dq sys_exec         ; 14
    dq sys_wait         ; 15
    dq sys_kill         ; 16
    dq sys_sleep        ; 17
    dq sys_yield        ; 18
    dq sys_gettime      ; 19
    dq sys_socket       ; 20
    dq sys_bind         ; 21
    dq sys_listen       ; 22
    dq sys_accept       ; 23
    dq sys_connect      ; 24
    dq sys_send         ; 25
    dq sys_recv         ; 26
    dq sys_sendto       ; 27
    dq sys_recvfrom     ; 28
    dq sys_shutdown_sock ; 29
    dq sys_setsockopt   ; 30
    dq sys_getsockopt   ; 31
    dq sys_gethostname  ; 32
    dq sys_sethostname  ; 33
    dq sys_getuid       ; 34
    dq sys_setuid       ; 35
    dq sys_uname        ; 36
    dq sys_sysinfo      ; 37
    dq sys_reboot       ; 38
    dq sys_shutdown_sys ; 39
    dq sys_putpixel     ; 40
    dq sys_getpixel     ; 41
    dq sys_drawrect     ; 42
    dq sys_fillrect     ; 43
    dq sys_drawtext     ; 44
    dq sys_getscreeninfo ; 45
    dq sys_setvideomode ; 46
    dq sys_copyrect     ; 47
SYSCALL_MAX equ ($ - syscall_table) / 8

; ════════════════════════════════════════════════════════════════════════════
; FILE DESCRIPTORS
; ════════════════════════════════════════════════════════════════════════════
; FD 0 = stdin (keyboard)
; FD 1 = stdout (screen)
; FD 2 = stderr (screen)
; FD 3+ = files/sockets

MAX_FDS         equ 32
FD_TYPE_FREE    equ 0
FD_TYPE_FILE    equ 1
FD_TYPE_SOCKET  equ 2
FD_TYPE_STDIN   equ 3
FD_TYPE_STDOUT  equ 4

; File descriptor table entry (16 bytes)
struc fd_entry
    .type:      resb 1      ; FD_TYPE_*
    .flags:     resb 1      ; Flags
    .refcount:  resw 1      ; Reference count
    .position:  resd 1      ; Current position (files)
    .data:      resq 1      ; Pointer to file/socket data
endstruc

; ════════════════════════════════════════════════════════════════════════════
; FILE/IO SYSCALLS (0-9)
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; SYS_READ (0) - Read from file descriptor
; Input: RDI = fd, RSI = buffer, RDX = count
; Output: RAX = bytes read (or -1 on error)
; ────────────────────────────────────────────────────────────────────────────
sys_read:
    push rbx
    push rcx

    ; Validate fd
    cmp rdi, MAX_FDS
    jae .read_error

    ; Check fd type
    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_FREE
    je .read_error

    ; Handle stdin (fd 0) - read from keyboard buffer
    test rdi, rdi
    jz .read_stdin

    ; Handle file read
    cmp byte [rbx + fd_entry.type], FD_TYPE_FILE
    je .read_file

    ; Handle socket read
    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    je .read_socket

    jmp .read_error

.read_stdin:
    ; Read from keyboard buffer
    xor rax, rax                ; Bytes read counter
    mov rcx, rdx                ; Count
    mov rbx, rsi                ; Buffer pointer

.stdin_loop:
    test rcx, rcx
    jz .read_done

    ; Check if keyboard buffer has data
    mov r8d, [kb_buffer_head]
    cmp r8d, [kb_buffer_tail]
    je .read_done               ; Buffer empty

    ; Get character from keyboard buffer
    lea r9, [kb_buffer]
    movzx r10d, byte [r9 + r8]
    mov [rbx], r10b

    ; Advance head pointer
    inc r8d
    and r8d, 0x3F               ; Wrap at 64
    mov [kb_buffer_head], r8d

    inc rbx
    inc rax
    dec rcx
    jmp .stdin_loop

.read_file:
    ; Read from filesystem file
    mov r8, [rbx + fd_entry.data]   ; File handle
    test r8, r8
    jz .read_error

    ; Get file position
    mov ecx, [rbx + fd_entry.position]

    ; Call FS read function
    push rdi
    push rsi
    push rdx
    mov rdi, r8                 ; File handle
    mov rsi, rsi                ; Buffer (already in RSI)
    mov rdx, rdx                ; Count (already in RDX)
    mov r10d, ecx               ; Position
    call fs_read_file
    pop rdx
    pop rsi
    pop rdi

    ; Update position
    test eax, eax
    js .read_done               ; Error
    add [rbx + fd_entry.position], eax
    jmp .read_done

.read_socket:
    ; Read from network socket - use recv
    mov r8, [rbx + fd_entry.data]
    push rdi
    mov rdi, r8
    ; RSI = buffer, RDX = length already set
    xor r10, r10                ; flags = 0
    call socket_recv
    pop rdi
    jmp .read_done

.read_error:
    mov rax, -1
    mov rbx, EBADF

.read_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_WRITE (1) - Write to file descriptor
; Input: RDI = fd, RSI = buffer, RDX = count
; Output: RAX = bytes written (or -1 on error)
; ────────────────────────────────────────────────────────────────────────────
sys_write:
    push rbx
    push rcx
    push r12
    push r13
    push r14

    ; Validate fd
    cmp rdi, MAX_FDS
    jae .write_error

    ; Handle stdout/stderr (fd 1, 2) - write to screen
    cmp rdi, 1
    je .write_stdout
    cmp rdi, 2
    je .write_stdout

    ; Check fd type
    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_FREE
    je .write_error

    ; Handle file write
    cmp byte [rbx + fd_entry.type], FD_TYPE_FILE
    je .write_file

    ; Handle socket write
    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    je .write_socket

    jmp .write_error

.write_stdout:
    ; Write string to terminal using draw_text
    ; Convert cursor position to framebuffer address
    push rsi
    push rdx

    ; Calculate framebuffer position from cursor
    movzx eax, word [term_cursor_y]
    imul eax, 320 * 8           ; Each char row is 8 pixels
    movzx ecx, word [term_cursor_x]
    imul ecx, 8                 ; Each char is 8 pixels wide
    add eax, ecx
    add eax, GFX_FB
    mov rdi, rax                ; RDI = framebuffer position

    mov r8, 15                  ; White color

    ; RSI already has buffer, but we need to handle count
    ; For simplicity, treat buffer as null-terminated string
    ; (or just return count as if written)

    mov rax, rdx                ; Return count as bytes "written"

    ; Update cursor position (simple: assume all chars on one line)
    movzx ecx, word [term_cursor_x]
    add ecx, edx                ; Add count
.stdout_wrap_check:
    cmp ecx, 40                 ; 40 chars per line
    jl .stdout_no_wrap
    sub ecx, 40
    inc word [term_cursor_y]
    jmp .stdout_wrap_check
.stdout_no_wrap:
    mov [term_cursor_x], cx

    pop rdx
    pop rsi
    jmp .write_done

.write_file:
    ; Write to filesystem file
    mov r8, [rbx + fd_entry.data]
    test r8, r8
    jz .write_error

    mov ecx, [rbx + fd_entry.position]

    push rdi
    push rsi
    push rdx
    mov rdi, r8
    mov r10d, ecx
    call fs_write_file
    pop rdx
    pop rsi
    pop rdi

    test eax, eax
    js .write_done
    add [rbx + fd_entry.position], eax
    jmp .write_done

.write_socket:
    mov r8, [rbx + fd_entry.data]
    push rdi
    mov rdi, r8
    xor r10, r10
    call socket_send
    pop rdi
    jmp .write_done

.write_error:
    mov rax, -1
    mov rbx, EBADF

.write_done:
    pop r14
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_OPEN (2) - Open file
; Input: RDI = path, RSI = flags, RDX = mode
; Output: RAX = fd (or -1 on error)
; ────────────────────────────────────────────────────────────────────────────
sys_open:
    push rbx
    push rcx
    push r12

    ; Find free fd slot (start at 3, 0-2 are reserved)
    mov ecx, 3
    lea rbx, [fd_table + 3 * fd_entry_size]

.find_fd:
    cmp ecx, MAX_FDS
    jge .open_error_nofds

    cmp byte [rbx + fd_entry.type], FD_TYPE_FREE
    je .found_fd

    add rbx, fd_entry_size
    inc ecx
    jmp .find_fd

.found_fd:
    mov r12d, ecx               ; Save fd number

    ; Try to open/create file in filesystem
    push rbx
    push rsi
    ; RDI already has path
    call fs_open_file           ; Returns file handle in RAX
    pop rsi
    pop rbx

    test rax, rax
    jz .open_try_create

    ; File found - setup fd entry
    mov byte [rbx + fd_entry.type], FD_TYPE_FILE
    mov byte [rbx + fd_entry.flags], sil
    mov word [rbx + fd_entry.refcount], 1
    mov dword [rbx + fd_entry.position], 0
    mov [rbx + fd_entry.data], rax

    mov eax, r12d               ; Return fd
    jmp .open_done

.open_try_create:
    ; Check if O_CREAT flag is set
    test esi, O_CREAT
    jz .open_error_noent

    ; Create new file
    push rbx
    call fs_create_file
    pop rbx

    test rax, rax
    jz .open_error_noent

    mov byte [rbx + fd_entry.type], FD_TYPE_FILE
    mov byte [rbx + fd_entry.flags], sil
    mov word [rbx + fd_entry.refcount], 1
    mov dword [rbx + fd_entry.position], 0
    mov [rbx + fd_entry.data], rax

    mov eax, r12d
    jmp .open_done

.open_error_nofds:
    mov rax, -1
    mov rbx, ENOMEM
    jmp .open_done

.open_error_noent:
    mov rax, -1
    mov rbx, ENOENT

.open_done:
    pop r12
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_CLOSE (3) - Close file descriptor
; Input: RDI = fd
; Output: RAX = 0 on success, -1 on error
; ────────────────────────────────────────────────────────────────────────────
sys_close:
    push rbx
    push rcx

    ; Validate fd (can't close 0, 1, 2)
    cmp rdi, 3
    jb .close_error
    cmp rdi, MAX_FDS
    jae .close_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_FREE
    je .close_error

    ; Decrement refcount
    dec word [rbx + fd_entry.refcount]
    jnz .close_success          ; Still referenced

    ; Actually close - cleanup based on type
    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    je .close_socket

    ; File - just mark as free
    jmp .close_free

.close_socket:
    ; Close socket
    mov rdi, [rbx + fd_entry.data]
    call socket_close

.close_free:
    mov byte [rbx + fd_entry.type], FD_TYPE_FREE
    mov qword [rbx + fd_entry.data], 0

.close_success:
    xor eax, eax
    jmp .close_done

.close_error:
    mov rax, -1
    mov rbx, EBADF

.close_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_STAT (4) - Get file status
; Input: RDI = path, RSI = stat buffer
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_stat:
    push rbx

    ; Get file info from FS
    call fs_stat_file

    test rax, rax
    jz .stat_error

    ; Fill stat buffer
    ; struct stat { size_t st_size; uint32_t st_mode; uint32_t st_mtime; }
    mov rbx, rax                ; File info
    mov eax, [rbx]              ; Size
    mov [rsi], eax
    mov eax, [rbx + 4]          ; Mode
    mov [rsi + 8], eax
    mov eax, [rbx + 8]          ; Mtime
    mov [rsi + 12], eax

    xor eax, eax
    jmp .stat_done

.stat_error:
    mov rax, -1
    mov rbx, ENOENT

.stat_done:
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_FSTAT (5) - Get file status by fd
; Input: RDI = fd, RSI = stat buffer
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_fstat:
    push rbx
    push rcx

    cmp rdi, MAX_FDS
    jae .fstat_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_FREE
    je .fstat_error

    ; Get file handle and call stat
    mov rdi, [rbx + fd_entry.data]
    call fs_stat_handle

    test rax, rax
    jz .fstat_error

    mov rbx, rax
    mov eax, [rbx]
    mov [rsi], eax
    mov eax, [rbx + 4]
    mov [rsi + 8], eax
    mov eax, [rbx + 8]
    mov [rsi + 12], eax

    xor eax, eax
    jmp .fstat_done

.fstat_error:
    mov rax, -1
    mov rbx, EBADF

.fstat_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_MMAP (6) - Map memory
; Input: RDI = addr (hint), RSI = length, RDX = prot, R10 = flags
; Output: RAX = mapped address (or -1 on error)
; ────────────────────────────────────────────────────────────────────────────
sys_mmap:
    push rbx

    ; Simple implementation - allocate from heap area
    ; Real mmap would manage page tables

    ; Round up length to page size (4KB)
    mov rax, rsi
    add rax, 0xFFF
    and rax, ~0xFFF

    ; Get next free address from mmap area (starts at 0x400000)
    mov rbx, [mmap_next_addr]
    test rbx, rbx
    jnz .mmap_have_addr
    mov rbx, 0x400000           ; Initialize mmap area

.mmap_have_addr:
    ; Check if we have enough space (limit at 0x800000)
    mov rcx, rbx
    add rcx, rax
    cmp rcx, 0x800000
    ja .mmap_error

    ; Allocate
    mov [mmap_next_addr], rcx
    mov rax, rbx                ; Return address
    jmp .mmap_done

.mmap_error:
    mov rax, -1
    mov rbx, ENOMEM

.mmap_done:
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_MUNMAP (7) - Unmap memory
; Input: RDI = addr, RSI = length
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_munmap:
    ; Simple implementation - just return success
    ; Real munmap would free pages
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_BRK (8) - Change heap break
; Input: RDI = new break address (0 to query current)
; Output: RAX = current break address
; ────────────────────────────────────────────────────────────────────────────
sys_brk:
    ; Get current break
    mov rax, [heap_break]
    test rax, rax
    jnz .brk_have_heap
    mov rax, 0x300000           ; Initialize heap at 3MB
    mov [heap_break], rax

.brk_have_heap:
    ; If RDI = 0, just return current break
    test rdi, rdi
    jz .brk_done

    ; Validate new break (must be > current and < mmap area)
    cmp rdi, rax
    jb .brk_done                ; Can't shrink (simple implementation)
    cmp rdi, 0x400000
    ja .brk_error               ; Can't exceed mmap area

    ; Set new break
    mov [heap_break], rdi
    mov rax, rdi

.brk_done:
    ret

.brk_error:
    mov rax, -1
    mov rbx, ENOMEM
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_IOCTL (9) - Device control
; Input: RDI = fd, RSI = request, RDX = arg
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_ioctl:
    ; Simple implementation - just return success for most requests
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; PROCESS SYSCALLS (10-19)
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; SYS_EXIT (10) - Exit current process
; Input: RDI = exit status
; ────────────────────────────────────────────────────────────────────────────
sys_exit:
    ; Save exit status
    mov [last_exit_status], edi

    ; Mark process as zombie
    mov rax, [current_process]
    test rax, rax
    jz .exit_idle

    cmp word [rax + PCB_PID], 0
    je .exit_idle               ; Can't exit idle process

    mov byte [rax + PCB_STATE], PROC_STATE_ZOMBIE

    ; Trigger reschedule
    call scheduler_schedule

.exit_idle:
    ; If we're the idle process, just halt
    hlt
    jmp .exit_idle

; ────────────────────────────────────────────────────────────────────────────
; SYS_GETPID (11) - Get process ID
; Output: RAX = current PID
; ────────────────────────────────────────────────────────────────────────────
sys_getpid:
    mov rax, [current_process]
    test rax, rax
    jz .getpid_zero
    movzx eax, word [rax + PCB_PID]
    ret
.getpid_zero:
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_GETPPID (12) - Get parent process ID
; Output: RAX = parent PID
; ────────────────────────────────────────────────────────────────────────────
sys_getppid:
    mov rax, [current_process]
    test rax, rax
    jz .getppid_zero
    mov rax, [rax + PCB_PARENT]
    ret
.getppid_zero:
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_FORK (13) - Create child process
; Output: RAX = child PID in parent, 0 in child, -1 on error
; ────────────────────────────────────────────────────────────────────────────
sys_fork:
    push rbx
    push rcx
    push r12

    ; Find free process slot
    mov rbx, process_table
    xor ecx, ecx

.fork_find_slot:
    cmp ecx, MAX_PROCESSES
    jge .fork_error

    cmp byte [rbx + PCB_STATE], PROC_STATE_FREE
    je .fork_found_slot

    add rbx, PCB_SIZE
    inc ecx
    jmp .fork_find_slot

.fork_found_slot:
    mov r12, rbx                ; Save child PCB pointer

    ; Copy parent PCB to child
    mov rdi, rbx
    mov rsi, [current_process]
    mov rcx, PCB_SIZE
    rep movsb

    ; Assign new PID
    mov eax, [next_pid]
    mov [r12 + PCB_PID], ax
    inc dword [next_pid]

    ; Set parent PID
    mov rax, [current_process]
    movzx eax, word [rax + PCB_PID]
    mov [r12 + PCB_PARENT], rax

    ; Calculate new stack for child
    mov rax, rcx                ; Slot index
    inc rax
    shl rax, 12                 ; * 4096
    add rax, PROC_STACK_BASE
    mov [r12 + PCB_STACK_BASE], rax
    add rax, PROC_STACK_SIZE - 8
    mov [r12 + PCB_RSP], rax

    ; Set child to return 0 from fork
    mov qword [r12 + PCB_RAX], 0

    ; Set child as ready
    mov byte [r12 + PCB_STATE], PROC_STATE_READY
    mov dword [r12 + PCB_TICKS], TIME_SLICE

    ; Parent returns child PID
    movzx eax, word [r12 + PCB_PID]
    jmp .fork_done

.fork_error:
    mov rax, -1
    mov rbx, ENOMEM

.fork_done:
    pop r12
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_EXEC (14) - Execute program
; Input: RDI = path, RSI = argv, RDX = envp
; Output: RAX = -1 on error (doesn't return on success)
; ────────────────────────────────────────────────────────────────────────────
sys_exec:
    push rbx
    push r12
    push r13

    mov r12, rdi                ; Save path
    mov r13, rsi                ; Save argv

    ; Load program from filesystem
    call fs_load_program        ; Returns code address in RAX

    test rax, rax
    jz .exec_error

    ; Setup new process state
    mov rbx, [current_process]

    ; Set entry point
    mov [rbx + PCB_RIP], rax
    mov [rbx + PCB_ENTRY], rax

    ; Reset stack
    mov rax, [rbx + PCB_STACK_BASE]
    add rax, PROC_STACK_SIZE - 8
    mov [rbx + PCB_RSP], rax

    ; Clear registers
    xor eax, eax
    mov [rbx + PCB_RAX], rax
    mov [rbx + PCB_RBX], rax
    mov [rbx + PCB_RCX], rax
    mov [rbx + PCB_RDX], rax
    mov [rbx + PCB_RSI], rax
    mov [rbx + PCB_RDI], rax

    ; Set flags
    mov qword [rbx + PCB_RFLAGS], 0x202

    ; Restore context to new program
    mov rdi, rbx
    call restore_context
    ; Doesn't return

.exec_error:
    mov rax, -1
    mov rbx, ENOENT
    pop r13
    pop r12
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_WAIT (15) - Wait for child process
; Input: RDI = pid (-1 for any), RSI = status pointer, RDX = options
; Output: RAX = child PID that exited
; ────────────────────────────────────────────────────────────────────────────
sys_wait:
    push rbx
    push rcx
    push r12

    mov r12, rsi                ; Save status pointer

.wait_loop:
    ; Search for zombie children
    mov rbx, process_table
    xor ecx, ecx

.wait_search:
    cmp ecx, MAX_PROCESSES
    jge .wait_block

    ; Check if this is a zombie child of current process
    cmp byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE
    jne .wait_next

    ; Check parent
    mov rax, [current_process]
    movzx eax, word [rax + PCB_PID]
    cmp [rbx + PCB_PARENT], rax
    jne .wait_next

    ; Check if waiting for specific PID
    cmp rdi, -1
    je .wait_found
    movzx eax, word [rbx + PCB_PID]
    cmp rdi, rax
    jne .wait_next

.wait_found:
    ; Found zombie child
    movzx eax, word [rbx + PCB_PID]
    push rax

    ; Store exit status if pointer provided
    test r12, r12
    jz .wait_no_status
    mov ecx, [last_exit_status]
    mov [r12], ecx
.wait_no_status:

    ; Free the child slot
    mov byte [rbx + PCB_STATE], PROC_STATE_FREE

    pop rax
    jmp .wait_done

.wait_next:
    add rbx, PCB_SIZE
    inc ecx
    jmp .wait_search

.wait_block:
    ; No zombie found - block (simple: just yield and retry)
    ; In real OS, would add to wait queue
    call sys_yield
    jmp .wait_loop

.wait_done:
    pop r12
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_KILL (16) - Send signal to process
; Input: RDI = pid, RSI = signal
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_kill:
    push rbx
    push rcx

    ; Find process by PID
    mov rbx, process_table
    xor ecx, ecx

.kill_search:
    cmp ecx, MAX_PROCESSES
    jge .kill_error

    cmp byte [rbx + PCB_STATE], PROC_STATE_FREE
    je .kill_next

    movzx eax, word [rbx + PCB_PID]
    cmp rdi, rax
    je .kill_found

.kill_next:
    add rbx, PCB_SIZE
    inc ecx
    jmp .kill_search

.kill_found:
    ; Handle signal
    cmp rsi, SIGKILL
    je .kill_terminate
    cmp rsi, SIGTERM
    je .kill_terminate

    ; Other signals - just return success for now
    xor eax, eax
    jmp .kill_done

.kill_terminate:
    ; Can't kill PID 0
    cmp word [rbx + PCB_PID], 0
    je .kill_error

    mov byte [rbx + PCB_STATE], PROC_STATE_ZOMBIE
    xor eax, eax
    jmp .kill_done

.kill_error:
    mov rax, -1
    mov rbx, EINVAL

.kill_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_SLEEP (17) - Sleep for specified time
; Input: RDI = milliseconds
; Output: RAX = 0
; ────────────────────────────────────────────────────────────────────────────
sys_sleep:
    push rbx
    push rcx

    ; Convert ms to ticks (100Hz = 10ms per tick)
    mov rax, rdi
    mov rcx, 10
    xor edx, edx
    div rcx                     ; RAX = ticks to sleep

    ; Get current tick
    mov rbx, [tick_count]
    add rbx, rax                ; Target tick

.sleep_loop:
    ; Check if target reached
    cmp [tick_count], rbx
    jge .sleep_done

    ; Yield CPU
    call sys_yield
    jmp .sleep_loop

.sleep_done:
    xor eax, eax
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_YIELD (18) - Yield CPU to scheduler
; Output: RAX = 0
; ────────────────────────────────────────────────────────────────────────────
sys_yield:
    ; Expire time slice
    mov rax, [current_process]
    test rax, rax
    jz .yield_done
    mov dword [rax + PCB_TICKS], 0
    mov byte [need_reschedule], 1
.yield_done:
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_GETTIME (19) - Get system time
; Input: RDI = time buffer (8 bytes: ticks since boot)
; Output: RAX = 0
; ────────────────────────────────────────────────────────────────────────────
sys_gettime:
    mov rax, [tick_count]
    mov [rdi], rax
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; NETWORK/SOCKET SYSCALLS (20-31)
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; SYS_SOCKET (20) - Create socket
; Input: RDI = domain (AF_INET), RSI = type (SOCK_STREAM/DGRAM), RDX = protocol
; Output: RAX = socket fd
; ────────────────────────────────────────────────────────────────────────────
sys_socket:
    push rbx
    push rcx
    push r12

    ; Find free fd
    mov ecx, 3
    lea rbx, [fd_table + 3 * fd_entry_size]

.socket_find_fd:
    cmp ecx, MAX_FDS
    jge .socket_error_nofds

    cmp byte [rbx + fd_entry.type], FD_TYPE_FREE
    je .socket_found_fd

    add rbx, fd_entry_size
    inc ecx
    jmp .socket_find_fd

.socket_found_fd:
    mov r12d, ecx

    ; Create socket structure
    call socket_create          ; Returns socket handle in RAX

    test rax, rax
    jz .socket_error

    ; Setup fd entry
    mov byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    mov byte [rbx + fd_entry.flags], 0
    mov word [rbx + fd_entry.refcount], 1
    mov dword [rbx + fd_entry.position], 0
    mov [rbx + fd_entry.data], rax

    mov eax, r12d
    jmp .socket_done

.socket_error_nofds:
    mov rax, -1
    mov rbx, ENOMEM
    jmp .socket_done

.socket_error:
    mov rax, -1
    mov rbx, EINVAL

.socket_done:
    pop r12
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_BIND (21) - Bind socket to address
; Input: RDI = sockfd, RSI = addr, RDX = addrlen
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_bind:
    push rbx
    push rcx

    ; Get socket from fd
    cmp rdi, MAX_FDS
    jae .bind_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    jne .bind_error

    mov rdi, [rbx + fd_entry.data]
    call socket_bind

    jmp .bind_done

.bind_error:
    mov rax, -1
    mov rbx, ENOTSOCK

.bind_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_LISTEN (22) - Listen for connections
; Input: RDI = sockfd, RSI = backlog
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_listen:
    push rbx
    push rcx

    cmp rdi, MAX_FDS
    jae .listen_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    jne .listen_error

    mov rdi, [rbx + fd_entry.data]
    call socket_listen

    jmp .listen_done

.listen_error:
    mov rax, -1
    mov rbx, ENOTSOCK

.listen_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_ACCEPT (23) - Accept connection
; Input: RDI = sockfd, RSI = addr, RDX = addrlen
; Output: RAX = new socket fd
; ────────────────────────────────────────────────────────────────────────────
sys_accept:
    push rbx
    push rcx
    push r12
    push r13

    ; Get listening socket
    cmp rdi, MAX_FDS
    jae .accept_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    jne .accept_error

    mov r12, rsi                ; Save addr
    mov r13, rdx                ; Save addrlen

    mov rdi, [rbx + fd_entry.data]
    mov rsi, r12
    mov rdx, r13
    call socket_accept          ; Returns new socket handle

    test rax, rax
    jz .accept_error

    ; Find fd for new socket
    mov rcx, 3
    lea rbx, [fd_table + 3 * fd_entry_size]

.accept_find_fd:
    cmp ecx, MAX_FDS
    jge .accept_error

    cmp byte [rbx + fd_entry.type], FD_TYPE_FREE
    je .accept_found_fd

    add rbx, fd_entry_size
    inc ecx
    jmp .accept_find_fd

.accept_found_fd:
    mov byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    mov word [rbx + fd_entry.refcount], 1
    mov [rbx + fd_entry.data], rax
    mov eax, ecx
    jmp .accept_done

.accept_error:
    mov rax, -1
    mov rbx, ENOTSOCK

.accept_done:
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_CONNECT (24) - Connect to remote address
; Input: RDI = sockfd, RSI = addr, RDX = addrlen
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_connect:
    push rbx
    push rcx

    cmp rdi, MAX_FDS
    jae .connect_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    jne .connect_error

    mov rdi, [rbx + fd_entry.data]
    call socket_connect

    jmp .connect_done

.connect_error:
    mov rax, -1
    mov rbx, ENOTSOCK

.connect_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_SEND (25) - Send data on socket
; Input: RDI = sockfd, RSI = buf, RDX = len, R10 = flags
; Output: RAX = bytes sent
; ────────────────────────────────────────────────────────────────────────────
sys_send:
    push rbx
    push rcx

    cmp rdi, MAX_FDS
    jae .send_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    jne .send_error

    mov rdi, [rbx + fd_entry.data]
    call socket_send

    jmp .send_done

.send_error:
    mov rax, -1
    mov rbx, ENOTSOCK

.send_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_RECV (26) - Receive data from socket
; Input: RDI = sockfd, RSI = buf, RDX = len, R10 = flags
; Output: RAX = bytes received
; ────────────────────────────────────────────────────────────────────────────
sys_recv:
    push rbx
    push rcx

    cmp rdi, MAX_FDS
    jae .recv_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    jne .recv_error

    mov rdi, [rbx + fd_entry.data]
    call socket_recv

    jmp .recv_done

.recv_error:
    mov rax, -1
    mov rbx, ENOTSOCK

.recv_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_SENDTO (27) - Send datagram
; Input: RDI = sockfd, RSI = buf, RDX = len, R10 = flags, R8 = dest_addr, R9 = addrlen
; Output: RAX = bytes sent
; ────────────────────────────────────────────────────────────────────────────
sys_sendto:
    push rbx
    push rcx

    cmp rdi, MAX_FDS
    jae .sendto_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    jne .sendto_error

    mov rdi, [rbx + fd_entry.data]
    call socket_sendto

    jmp .sendto_done

.sendto_error:
    mov rax, -1
    mov rbx, ENOTSOCK

.sendto_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_RECVFROM (28) - Receive datagram
; Input: RDI = sockfd, RSI = buf, RDX = len, R10 = flags, R8 = src_addr, R9 = addrlen
; Output: RAX = bytes received
; ────────────────────────────────────────────────────────────────────────────
sys_recvfrom:
    push rbx
    push rcx

    cmp rdi, MAX_FDS
    jae .recvfrom_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    jne .recvfrom_error

    mov rdi, [rbx + fd_entry.data]
    call socket_recvfrom

    jmp .recvfrom_done

.recvfrom_error:
    mov rax, -1
    mov rbx, ENOTSOCK

.recvfrom_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_SHUTDOWN (29) - Shutdown socket
; Input: RDI = sockfd, RSI = how (0=RD, 1=WR, 2=RDWR)
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_shutdown_sock:
    push rbx
    push rcx

    cmp rdi, MAX_FDS
    jae .shutdown_sock_error

    lea rbx, [fd_table]
    imul rcx, rdi, fd_entry_size
    add rbx, rcx

    cmp byte [rbx + fd_entry.type], FD_TYPE_SOCKET
    jne .shutdown_sock_error

    mov rdi, [rbx + fd_entry.data]
    call socket_shutdown

    jmp .shutdown_sock_done

.shutdown_sock_error:
    mov rax, -1
    mov rbx, ENOTSOCK

.shutdown_sock_done:
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_SETSOCKOPT (30) / SYS_GETSOCKOPT (31) - Socket options
; ────────────────────────────────────────────────────────────────────────────
sys_setsockopt:
sys_getsockopt:
    ; Stub - return success
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SYSTEM INFO SYSCALLS (32-39)
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; SYS_GETHOSTNAME (32) - Get system hostname
; Input: RDI = buffer, RSI = len
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_gethostname:
    push rcx
    push rsi

    lea rsi, [hostname]
    mov rcx, rdi
    xchg rdi, rsi               ; RDI = dest, RSI = src

.gethostname_copy:
    test rcx, rcx
    jz .gethostname_done
    lodsb
    stosb
    test al, al
    jz .gethostname_done
    dec rcx
    jmp .gethostname_copy

.gethostname_done:
    xor eax, eax
    pop rsi
    pop rcx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_SETHOSTNAME (33) - Set system hostname
; Input: RDI = name, RSI = len
; Output: RAX = 0 on success
; ────────────────────────────────────────────────────────────────────────────
sys_sethostname:
    push rcx
    push rdi

    mov rcx, rsi
    cmp rcx, 63
    jle .sethostname_ok
    mov rcx, 63

.sethostname_ok:
    mov rsi, rdi
    lea rdi, [hostname]
    rep movsb
    mov byte [rdi], 0

    xor eax, eax
    pop rdi
    pop rcx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_GETUID (34) / SYS_SETUID (35) - User ID (always 0 = root)
; ────────────────────────────────────────────────────────────────────────────
sys_getuid:
    xor eax, eax                ; Always root
    ret

sys_setuid:
    xor eax, eax                ; Always succeeds
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_UNAME (36) - Get system information
; Input: RDI = utsname buffer
; struct utsname { char sysname[65], nodename[65], release[65], version[65], machine[65]; }
; ────────────────────────────────────────────────────────────────────────────
sys_uname:
    push rsi
    push rcx

    ; sysname
    lea rsi, [uname_sysname]
    mov rcx, 65
    call .copy_str

    ; nodename (hostname)
    add rdi, 65
    lea rsi, [hostname]
    mov rcx, 65
    call .copy_str

    ; release
    add rdi, 65
    lea rsi, [uname_release]
    mov rcx, 65
    call .copy_str

    ; version
    add rdi, 65
    lea rsi, [uname_version]
    mov rcx, 65
    call .copy_str

    ; machine
    add rdi, 65
    lea rsi, [uname_machine]
    mov rcx, 65
    call .copy_str

    xor eax, eax
    pop rcx
    pop rsi
    ret

.copy_str:
    lodsb
    stosb
    test al, al
    jz .copy_pad
    dec rcx
    jnz .copy_str
    ret
.copy_pad:
    dec rcx
    jz .copy_done
    mov byte [rdi], 0
    inc rdi
    jmp .copy_pad
.copy_done:
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_SYSINFO (37) - Get system statistics
; Input: RDI = sysinfo buffer
; ────────────────────────────────────────────────────────────────────────────
sys_sysinfo:
    ; uptime (seconds)
    mov rax, [tick_count]
    mov rcx, 100
    xor edx, edx
    div rcx
    mov [rdi], rax

    ; total RAM (4MB)
    mov qword [rdi + 8], 0x400000

    ; free RAM (estimate)
    mov rax, 0x400000
    sub rax, [heap_break]
    mov [rdi + 16], rax

    ; process count
    call get_process_count
    mov [rdi + 24], eax

    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_REBOOT (38) - Reboot system
; Input: RDI = magic (0x1234 for reboot)
; ────────────────────────────────────────────────────────────────────────────
sys_reboot:
    cmp rdi, 0x1234
    jne .reboot_invalid

    ; Triple fault to reboot
    cli
    lidt [.null_idt]
    int 0
    jmp $

.null_idt:
    dw 0
    dq 0

.reboot_invalid:
    mov rax, -1
    mov rbx, EINVAL
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_SHUTDOWN_SYS (39) - Shutdown system
; ────────────────────────────────────────────────────────────────────────────
sys_shutdown_sys:
    ; Save filesystem to disk
    call fs_save_to_disk

    ; Try ACPI shutdown (QEMU)
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax

    ; If that didn't work, halt
    cli
.halt_loop:
    hlt
    jmp .halt_loop

; ════════════════════════════════════════════════════════════════════════════
; GRAPHICS SYSCALLS (40-49)
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; SYS_PUTPIXEL (40) - Draw pixel
; Input: RDI = x, RSI = y, RDX = color
; Output: RAX = 0
; ────────────────────────────────────────────────────────────────────────────
sys_putpixel:
    ; Bounds check
    cmp rdi, 320
    jae .putpixel_done
    cmp rsi, 200
    jae .putpixel_done

    ; Calculate offset
    mov rax, rsi
    imul rax, 320
    add rax, rdi
    add rax, GFX_FB

    ; Write pixel
    mov [rax], dl

.putpixel_done:
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_GETPIXEL (41) - Read pixel
; Input: RDI = x, RSI = y
; Output: RAX = color
; ────────────────────────────────────────────────────────────────────────────
sys_getpixel:
    cmp rdi, 320
    jae .getpixel_oob
    cmp rsi, 200
    jae .getpixel_oob

    mov rax, rsi
    imul rax, 320
    add rax, rdi
    add rax, GFX_FB
    movzx eax, byte [rax]
    ret

.getpixel_oob:
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_DRAWRECT (42) - Draw rectangle outline
; Input: RDI = x, RSI = y, RDX = width, R10 = height, R8 = color
; ────────────────────────────────────────────────────────────────────────────
sys_drawrect:
    push rbx
    push rcx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                ; x
    mov r13, rsi                ; y
    mov r14, rdx                ; width
    mov r15, r10                ; height

    ; Top line
    mov rcx, r14
.rect_top:
    mov rdi, r12
    add rdi, rcx
    dec rdi
    mov rsi, r13
    mov rdx, r8
    call sys_putpixel
    dec rcx
    jnz .rect_top

    ; Bottom line
    mov rcx, r14
    mov rbx, r13
    add rbx, r15
    dec rbx
.rect_bottom:
    mov rdi, r12
    add rdi, rcx
    dec rdi
    mov rsi, rbx
    mov rdx, r8
    call sys_putpixel
    dec rcx
    jnz .rect_bottom

    ; Left line
    mov rcx, r15
.rect_left:
    mov rdi, r12
    mov rsi, r13
    add rsi, rcx
    dec rsi
    mov rdx, r8
    call sys_putpixel
    dec rcx
    jnz .rect_left

    ; Right line
    mov rcx, r15
    mov rbx, r12
    add rbx, r14
    dec rbx
.rect_right:
    mov rdi, rbx
    mov rsi, r13
    add rsi, rcx
    dec rsi
    mov rdx, r8
    call sys_putpixel
    dec rcx
    jnz .rect_right

    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_FILLRECT (43) - Fill rectangle
; Input: RDI = x, RSI = y, RDX = width, R10 = height, R8 = color
; ────────────────────────────────────────────────────────────────────────────
sys_fillrect:
    push rbx
    push rcx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi                ; x
    mov r13, rsi                ; y
    mov r14, rdx                ; width
    mov r15, r10                ; height

    ; For each row
    xor rbx, rbx                ; row counter
.fillrect_row:
    cmp rbx, r15
    jge .fillrect_done

    ; Calculate row start address
    mov rax, r13
    add rax, rbx
    imul rax, 320
    add rax, r12
    add rax, GFX_FB

    ; Fill row
    mov rdi, rax
    mov rcx, r14
    mov al, r8b
    rep stosb

    inc rbx
    jmp .fillrect_row

.fillrect_done:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_DRAWTEXT (44) - Draw text string
; Input: RDI = x, RSI = y, RDX = string ptr, R10 = color
; ────────────────────────────────────────────────────────────────────────────
sys_drawtext:
    push rbx
    push rcx
    push r12

    ; Convert x,y to framebuffer address
    mov rax, rsi                ; y
    imul rax, 320               ; y * 320
    add rax, rdi                ; + x
    add rax, GFX_FB             ; + framebuffer base
    mov rdi, rax                ; RDI = framebuffer address

    mov rsi, rdx                ; RSI = string pointer
    mov r8, r10                 ; R8 = color

    ; Call existing draw_text function from go64.asm
    call draw_text

    xor eax, eax
    pop r12
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_GETSCREENINFO (45) - Get screen information
; Input: RDI = info buffer
; struct screeninfo { uint16_t width, height; uint8_t bpp; uint32_t fb_addr; }
; ────────────────────────────────────────────────────────────────────────────
sys_getscreeninfo:
    mov word [rdi], 320         ; width
    mov word [rdi + 2], 200     ; height
    mov byte [rdi + 4], 8       ; bpp
    mov dword [rdi + 8], GFX_FB ; framebuffer address
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_SETVIDEOMODE (46) - Set video mode (stub)
; ────────────────────────────────────────────────────────────────────────────
sys_setvideomode:
    ; Only mode 13h supported
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; SYS_COPYRECT (47) - Copy rectangle (blit)
; Input: RDI = src_x, RSI = src_y, RDX = dst_x, R10 = dst_y, R8 = width, R9 = height
; ────────────────────────────────────────────────────────────────────────────
sys_copyrect:
    push rbx
    push rcx
    push r12
    push r13
    push r14
    push r15

    ; Copy row by row
    xor rbx, rbx                ; row counter
.copyrect_row:
    cmp rbx, r9
    jge .copyrect_done

    ; Source address
    mov rax, rsi
    add rax, rbx
    imul rax, 320
    add rax, rdi
    add rax, GFX_FB
    mov r12, rax                ; src

    ; Dest address
    mov rax, r10
    add rax, rbx
    imul rax, 320
    add rax, rdx
    add rax, GFX_FB
    mov r13, rax                ; dst

    ; Copy row
    push rsi
    push rdi
    mov rsi, r12
    mov rdi, r13
    mov rcx, r8
    rep movsb
    pop rdi
    pop rsi

    inc rbx
    jmp .copyrect_row

.copyrect_done:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; SOCKET HELPER STUBS (will be implemented with TCP/IP stack)
; ════════════════════════════════════════════════════════════════════════════

socket_create:
    ; Allocate socket structure
    mov rax, [next_socket_id]
    inc qword [next_socket_id]

    ; Find free socket slot
    lea rbx, [socket_table]
    mov rcx, MAX_SOCKETS
.find_socket_slot:
    cmp byte [rbx], 0           ; Check if slot free
    je .found_socket_slot
    add rbx, SOCKET_SIZE
    dec rcx
    jnz .find_socket_slot
    xor eax, eax                ; No free slot
    ret

.found_socket_slot:
    mov byte [rbx], 1           ; Mark as used
    mov [rbx + 1], di           ; Domain
    mov [rbx + 3], si           ; Type
    mov [rbx + 5], dx           ; Protocol
    mov rax, rbx                ; Return socket handle
    ret

socket_bind:
socket_listen:
socket_connect:
socket_shutdown:
    xor eax, eax
    ret

socket_accept:
    xor eax, eax                ; No connections yet
    ret

socket_send:
socket_sendto:
    ; RSI = buf, RDX = len
    ; For now, just use E1000 raw send
    push rdi
    push rsi

    ; Build minimal ethernet frame and send via E1000
    mov rcx, rdx                ; length
    ; Would need proper packet building here
    ; For now return length as if sent
    mov rax, rdx

    pop rsi
    pop rdi
    ret

socket_recv:
socket_recvfrom:
    ; Check E1000 for received packets
    call e1000_rx_poll
    ; RAX = length, RDI = buffer
    ret

socket_close:
    test rdi, rdi
    jz .socket_close_done
    mov byte [rdi], 0           ; Mark as free
.socket_close_done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILESYSTEM STUBS (connect to existing fs.asm)
; ════════════════════════════════════════════════════════════════════════════

fs_open_file:
    ; RDI = path
    ; Search for file in filesystem
    push rbx
    push rcx

    ; Simple implementation - return file entry pointer if found
    call fs_find_file

    pop rcx
    pop rbx
    ret

fs_create_file:
    ; RDI = path
    ; Create new file entry
    push rbx

    call fs_new_file

    pop rbx
    ret

fs_read_file:
    ; RDI = file handle, RSI = buffer, RDX = count, R10 = position
    ; Read from file data
    push rbx
    push rcx

    ; Get file data pointer
    mov rbx, rdi
    mov rax, [rbx + 8]          ; Data pointer
    test rax, rax
    jz .read_file_empty

    ; Copy data
    add rax, r10                ; Add position offset
    mov rsi, rax
    mov rdi, rsi                ; RSI was buffer
    xchg rdi, rsi
    mov rcx, rdx
    rep movsb
    mov rax, rdx                ; Return bytes read
    jmp .read_file_done

.read_file_empty:
    xor eax, eax

.read_file_done:
    pop rcx
    pop rbx
    ret

fs_write_file:
    ; RDI = file handle, RSI = buffer, RDX = count, R10 = position
    mov rax, rdx                ; Return bytes "written"
    ret

fs_stat_file:
fs_stat_handle:
    xor eax, eax                ; Not implemented
    ret

fs_find_file:
fs_new_file:
    xor eax, eax
    ret

fs_load_program:
    xor eax, eax                ; Not implemented
    ret

; ════════════════════════════════════════════════════════════════════════════
; SYSCALL DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

; File descriptor table
fd_entry_size equ 16
fd_table:
    ; FD 0 - stdin
    db FD_TYPE_STDIN, 0         ; type, flags
    dw 1                        ; refcount
    dd 0                        ; position
    dq 0                        ; data
    ; FD 1 - stdout
    db FD_TYPE_STDOUT, 0
    dw 1
    dd 0
    dq 0
    ; FD 2 - stderr
    db FD_TYPE_STDOUT, 0
    dw 1
    dd 0
    dq 0
    ; FD 3-31 - free
    times (MAX_FDS - 3) * fd_entry_size db 0

; Socket table
MAX_SOCKETS     equ 16
SOCKET_SIZE     equ 64
socket_table:   times MAX_SOCKETS * SOCKET_SIZE db 0
next_socket_id: dq 1

; Memory management
heap_break:     dq 0
mmap_next_addr: dq 0

; Keyboard buffer (circular)
kb_buffer:      times 64 db 0
kb_buffer_head: dd 0
kb_buffer_tail: dd 0

; Terminal cursor
term_cursor_x:  dw 0
term_cursor_y:  dw 20           ; Start below GUI

; Process data
last_exit_status: dd 0

; System info
hostname:       db "mathis-os", 0
                times 54 db 0   ; Pad to 64 bytes

uname_sysname:  db "MathisOS", 0
uname_release:  db "1.0.0", 0
uname_version:  db "Dec 2024", 0
uname_machine:  db "x86_64", 0
