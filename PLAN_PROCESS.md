# Plan: Complétion du sous-système Processus

## Convention x86-64 System V
```
Arguments: RDI, RSI, RDX, RCX, R8, R9
Retour:    RAX (et RDX pour 128-bit)
Preserved: R12-R15, RBX, RBP
Scratch:   RAX, RCX, RDX, RSI, RDI, R8-R11
Stack:     Aligné 16 bytes avant call
```

---

## 1. Priority Scheduler (🔶 → ✅)

### État actuel
- `PCB_PRIORITY` existe à offset 0xA1 (1 byte)
- Non utilisé dans `scheduler_next()`

### Fichiers
- `boot/kernel/scheduler.asm`

### Implémentation

```asm
; ============================================================================
; PRIORITY LEVELS
; ============================================================================
PRIO_REALTIME   equ 0       ; Highest - system critical
PRIO_HIGH       equ 1       ; Interactive/UI
PRIO_NORMAL     equ 2       ; Default
PRIO_LOW        equ 3       ; Background tasks
PRIO_IDLE       equ 4       ; Only when nothing else

; ============================================================================
; SCHEDULER_NEXT - Priority-based selection
; ============================================================================
; Output: RAX = PCB pointer of next process (or 0)
; Algorithm: Scan all READY processes, pick highest priority (lowest number)
; ============================================================================
scheduler_next_priority:
    push rbx
    push rcx
    push rdx
    push r12
    push r13

    mov r12, -1                     ; Best candidate index
    mov r13d, 255                   ; Best priority (lower = better)

    lea rbx, [process_table]
    xor ecx, ecx                    ; Index

.scan:
    cmp ecx, MAX_PROCESSES
    jge .done_scan

    ; Check if READY
    mov al, [rbx + PCB_STATE]
    cmp al, PROC_STATE_READY
    jne .next

    ; Compare priority
    movzx eax, byte [rbx + PCB_PRIORITY]
    cmp eax, r13d
    jge .next                       ; Not better

    ; New best candidate
    mov r13d, eax
    mov r12, rcx

.next:
    add rbx, PCB_SIZE
    inc ecx
    jmp .scan

.done_scan:
    cmp r12, -1
    je .no_process

    ; Return PCB pointer
    mov rax, r12
    imul rax, PCB_SIZE
    lea rax, [process_table + rax]
    jmp .done

.no_process:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; SYS_SETPRIORITY (nouveau syscall)
; ============================================================================
; Input: RDI = pid (0 = self), RSI = priority (0-4)
; Output: RAX = 0 success, -1 error
; ============================================================================
sys_setpriority:
    ; Validate priority
    cmp rsi, PRIO_IDLE
    ja .error

    ; Get target PCB
    test rdi, rdi
    jz .use_current
    ; TODO: find PCB by PID
    jmp .error

.use_current:
    mov rax, [current_process]
    mov [rax + PCB_PRIORITY], sil
    xor eax, eax
    ret

.error:
    mov rax, -1
    ret
```

### Tests
1. Créer 3 processes avec priorités différentes
2. Vérifier que high-priority s'exécute en premier
3. Vérifier que low-priority ne starve pas (aging)

---

## 2. Shared Memory (🔶 → ✅)

### État actuel
- `sys_mmap` alloue mémoire mais pas partagée entre processes

### Fichiers
- `boot/kernel/syscalls.asm`
- `boot/kernel/mm/shm.asm` (nouveau)

### Structures

```asm
; ============================================================================
; SHM REGION STRUCTURE (64 bytes)
; ============================================================================
SHM_KEY         equ 0       ; 8 bytes - unique key
SHM_ADDR        equ 8       ; 8 bytes - physical address
SHM_SIZE        equ 16      ; 8 bytes - size in bytes
SHM_REFCOUNT    equ 24      ; 4 bytes - number of attached processes
SHM_FLAGS       equ 28      ; 4 bytes - permissions
SHM_OWNER       equ 32      ; 2 bytes - owner PID
SHM_RESERVED    equ 34      ; 30 bytes
SHM_STRUCT_SIZE equ 64

MAX_SHM_REGIONS equ 16

section .bss
shm_table:      resb (SHM_STRUCT_SIZE * MAX_SHM_REGIONS)
```

### Syscalls

```asm
; ============================================================================
; SYS_SHMGET - Create/get shared memory region
; ============================================================================
; Input: RDI = key, RSI = size, RDX = flags
; Output: RAX = shm_id (0-15), -1 on error
; ============================================================================
sys_shmget:
    push rbx
    push r12

    ; Search for existing key
    lea rbx, [shm_table]
    xor ecx, ecx

.search:
    cmp ecx, MAX_SHM_REGIONS
    jge .not_found

    cmp qword [rbx + SHM_KEY], rdi
    je .found

    add rbx, SHM_STRUCT_SIZE
    inc ecx
    jmp .search

.found:
    mov eax, ecx                    ; Return existing shm_id
    jmp .done

.not_found:
    ; Find free slot and create new
    lea rbx, [shm_table]
    xor ecx, ecx

.find_free:
    cmp ecx, MAX_SHM_REGIONS
    jge .error

    cmp qword [rbx + SHM_SIZE], 0
    je .create

    add rbx, SHM_STRUCT_SIZE
    inc ecx
    jmp .find_free

.create:
    ; Allocate physical pages
    mov r12, rsi                    ; Save size
    add rsi, 4095
    shr rsi, 12                     ; Pages needed
    mov rdi, rsi
    call pmm_alloc_pages
    test rax, rax
    jz .error

    ; Initialize structure
    mov [rbx + SHM_KEY], rdi
    mov [rbx + SHM_ADDR], rax
    mov [rbx + SHM_SIZE], r12
    mov dword [rbx + SHM_REFCOUNT], 0
    mov eax, ecx                    ; Return shm_id
    jmp .done

.error:
    mov rax, -1

.done:
    pop r12
    pop rbx
    ret

; ============================================================================
; SYS_SHMAT - Attach shared memory to process
; ============================================================================
; Input: RDI = shm_id, RSI = shmaddr (0 = auto), RDX = flags
; Output: RAX = virtual address, -1 on error
; ============================================================================
sys_shmat:
    ; Validate shm_id
    cmp rdi, MAX_SHM_REGIONS
    jae .error

    ; Get shm entry
    mov rax, rdi
    imul rax, SHM_STRUCT_SIZE
    lea rbx, [shm_table + rax]

    ; Check exists
    cmp qword [rbx + SHM_SIZE], 0
    je .error

    ; Map into current process address space
    mov rdi, [rbx + SHM_ADDR]       ; Physical address
    mov rsi, [rbx + SHM_SIZE]       ; Size
    ; TODO: vmm_map_range for current process

    ; Increment refcount
    inc dword [rbx + SHM_REFCOUNT]

    mov rax, [rbx + SHM_ADDR]       ; Return address (simplified)
    ret

.error:
    mov rax, -1
    ret

; ============================================================================
; SYS_SHMDT - Detach shared memory
; ============================================================================
; Input: RDI = shmaddr
; Output: RAX = 0 success, -1 error
; ============================================================================
sys_shmdt:
    ; Find region by address
    lea rbx, [shm_table]
    xor ecx, ecx

.search:
    cmp ecx, MAX_SHM_REGIONS
    jge .error

    cmp [rbx + SHM_ADDR], rdi
    je .found

    add rbx, SHM_STRUCT_SIZE
    inc ecx
    jmp .search

.found:
    ; Decrement refcount
    dec dword [rbx + SHM_REFCOUNT]

    ; Unmap from process (TODO)

    xor eax, eax
    ret

.error:
    mov rax, -1
    ret
```

---

## 3. Signals (🔶 → ✅)

### État actuel
- `sys_kill` existe
- Pas de signal handlers user-space

### Fichiers
- `boot/kernel/syscalls.asm`
- `boot/kernel/signal.asm` (nouveau)

### Structures

```asm
; ============================================================================
; SIGNAL NUMBERS (POSIX-like)
; ============================================================================
SIGHUP      equ 1       ; Hangup
SIGINT      equ 2       ; Interrupt (Ctrl+C)
SIGQUIT     equ 3       ; Quit
SIGILL      equ 4       ; Illegal instruction
SIGTRAP     equ 5       ; Trace trap
SIGABRT     equ 6       ; Abort
SIGBUS      equ 7       ; Bus error
SIGFPE      equ 8       ; Floating point exception
SIGKILL     equ 9       ; Kill (cannot be caught)
SIGUSR1     equ 10      ; User defined 1
SIGSEGV     equ 11      ; Segmentation fault
SIGUSR2     equ 12      ; User defined 2
SIGPIPE     equ 13      ; Broken pipe
SIGALRM     equ 14      ; Alarm clock
SIGTERM     equ 15      ; Termination
SIGCHLD     equ 17      ; Child status changed
SIGCONT     equ 18      ; Continue
SIGSTOP     equ 19      ; Stop (cannot be caught)
SIGTSTP     equ 20      ; Terminal stop

SIG_DFL     equ 0       ; Default action
SIG_IGN     equ 1       ; Ignore signal
MAX_SIGNALS equ 32

; ============================================================================
; SIGNAL MASK IN PCB (add to PCB structure)
; ============================================================================
PCB_SIG_PENDING equ 0xE0    ; 4 bytes - pending signal bitmap
PCB_SIG_MASK    equ 0xE4    ; 4 bytes - blocked signals
PCB_SIG_HANDLER equ 0xE8    ; 8 bytes * 32 = 256 bytes - handler table
; Note: Requires expanding PCB or separate table
```

### Syscalls

```asm
; ============================================================================
; SYS_SIGNAL - Set signal handler
; ============================================================================
; Input: RDI = signum, RSI = handler (address or SIG_DFL/SIG_IGN)
; Output: RAX = previous handler, -1 on error
; ============================================================================
sys_signal:
    ; Validate signal number
    cmp rdi, MAX_SIGNALS
    jae .error
    cmp rdi, SIGKILL
    je .error                       ; Cannot catch SIGKILL
    cmp rdi, SIGSTOP
    je .error                       ; Cannot catch SIGSTOP

    ; Get current process signal table
    mov rax, [current_process]
    lea rbx, [rax + PCB_SIG_HANDLER]

    ; Get old handler
    mov rcx, [rbx + rdi * 8]

    ; Set new handler
    mov [rbx + rdi * 8], rsi

    mov rax, rcx                    ; Return old handler
    ret

.error:
    mov rax, -1
    ret

; ============================================================================
; SIGNAL_DELIVER - Called before returning to user mode
; ============================================================================
; Checks pending signals and delivers them
; ============================================================================
signal_deliver:
    push rbx
    push r12

    mov rax, [current_process]
    mov ebx, [rax + PCB_SIG_PENDING]
    test ebx, ebx
    jz .done                        ; No pending signals

    ; Find first pending signal
    bsf ecx, ebx                    ; ecx = signal number
    jz .done

    ; Clear pending bit
    btr dword [rax + PCB_SIG_PENDING], ecx

    ; Get handler
    lea r12, [rax + PCB_SIG_HANDLER]
    mov rdi, [r12 + rcx * 8]

    cmp rdi, SIG_IGN
    je .done                        ; Ignored

    cmp rdi, SIG_DFL
    je .default_action

    ; User handler - setup stack frame and call
    ; TODO: Push signal frame, modify return address
    jmp .done

.default_action:
    ; Default actions
    cmp ecx, SIGKILL
    je .terminate
    cmp ecx, SIGTERM
    je .terminate
    cmp ecx, SIGSEGV
    je .terminate
    ; ... other defaults
    jmp .done

.terminate:
    mov rdi, [current_process]
    movzx esi, word [rdi + PCB_PID]
    call process_terminate

.done:
    pop r12
    pop rbx
    ret
```

---

## 4. Kernel Threads (❌ → ✅)

### Concept
- Thread = process léger partageant l'espace d'adressage
- Même PML4 (page tables) que le process parent
- Stack séparée

### Fichiers
- `boot/kernel/thread.asm` (nouveau)

### Structures

```asm
; ============================================================================
; THREAD CONTROL BLOCK (TCB) - 128 bytes
; ============================================================================
TCB_TID         equ 0       ; 2 bytes - thread ID
TCB_PID         equ 2       ; 2 bytes - parent process ID
TCB_STATE       equ 4       ; 1 byte - state
TCB_PRIORITY    equ 5       ; 1 byte - priority
TCB_FLAGS       equ 6       ; 2 bytes - flags

TCB_RSP         equ 8       ; 8 bytes - stack pointer
TCB_RIP         equ 16      ; 8 bytes - instruction pointer
TCB_RFLAGS      equ 24      ; 8 bytes - flags

TCB_STACK_BASE  equ 32      ; 8 bytes - stack base address
TCB_STACK_SIZE  equ 40      ; 4 bytes - stack size
TCB_ENTRY       equ 48      ; 8 bytes - entry point
TCB_ARG         equ 56      ; 8 bytes - thread argument

TCB_REGS        equ 64      ; 64 bytes - saved registers (R12-R15, RBX, RBP, etc.)

TCB_SIZE        equ 128
MAX_THREADS     equ 64

section .bss
thread_table:   resb (TCB_SIZE * MAX_THREADS)
next_tid:       resw 1
```

### Implémentation

```asm
; ============================================================================
; THREAD_CREATE - Create new kernel thread
; ============================================================================
; Input: RDI = entry point, RSI = argument, RDX = stack size (0 = default)
; Output: RAX = TID, -1 on error
; ============================================================================
thread_create:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi                    ; Entry point
    mov r13, rsi                    ; Argument
    mov r14, rdx                    ; Stack size
    test r14, r14
    jnz .has_size
    mov r14, 4096                   ; Default 4KB stack

.has_size:
    ; Find free TCB slot
    lea rbx, [thread_table]
    xor ecx, ecx

.find_slot:
    cmp ecx, MAX_THREADS
    jge .error

    cmp byte [rbx + TCB_STATE], 0   ; Free?
    je .found_slot

    add rbx, TCB_SIZE
    inc ecx
    jmp .find_slot

.found_slot:
    ; Allocate stack
    mov rdi, r14
    add rdi, 4095
    shr rdi, 12                     ; Pages
    call pmm_alloc_pages
    test rax, rax
    jz .error

    ; Initialize TCB
    mov word [rbx + TCB_TID], cx
    mov rax, [current_process]
    mov ax, [rax + PCB_PID]
    mov [rbx + TCB_PID], ax
    mov byte [rbx + TCB_STATE], PROC_STATE_READY
    mov byte [rbx + TCB_PRIORITY], PRIO_NORMAL

    mov [rbx + TCB_STACK_BASE], rax
    mov [rbx + TCB_STACK_SIZE], r14d
    mov [rbx + TCB_ENTRY], r12
    mov [rbx + TCB_ARG], r13

    ; Setup initial stack (entry point will pop arg from RDI)
    add rax, r14                    ; Top of stack
    sub rax, 8                      ; Alignment
    mov [rbx + TCB_RSP], rax
    mov [rbx + TCB_RIP], r12
    mov qword [rbx + TCB_RFLAGS], 0x202  ; IF set

    ; Return TID
    movzx eax, cx
    jmp .done

.error:
    mov rax, -1

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; THREAD_EXIT - Terminate current thread
; ============================================================================
; Input: RDI = exit code
; ============================================================================
thread_exit:
    ; Mark thread as zombie
    mov rax, [current_thread]
    mov byte [rax + TCB_STATE], PROC_STATE_ZOMBIE

    ; Free stack
    mov rdi, [rax + TCB_STACK_BASE]
    mov esi, [rax + TCB_STACK_SIZE]
    add rsi, 4095
    shr rsi, 12
    call pmm_free_pages

    ; Clear TCB
    mov byte [rax + TCB_STATE], PROC_STATE_FREE

    ; Switch to another thread
    call scheduler_yield
    ; Should not return
    jmp $

; ============================================================================
; THREAD_JOIN - Wait for thread to terminate
; ============================================================================
; Input: RDI = TID
; Output: RAX = 0 success, -1 error
; ============================================================================
thread_join:
    ; Validate TID
    cmp rdi, MAX_THREADS
    jae .error

    ; Get TCB
    mov rax, rdi
    imul rax, TCB_SIZE
    lea rbx, [thread_table + rax]

.wait:
    cmp byte [rbx + TCB_STATE], PROC_STATE_FREE
    je .done                        ; Thread finished
    cmp byte [rbx + TCB_STATE], PROC_STATE_ZOMBIE
    je .cleanup

    ; Yield and retry
    call scheduler_yield
    jmp .wait

.cleanup:
    mov byte [rbx + TCB_STATE], PROC_STATE_FREE

.done:
    xor eax, eax
    ret

.error:
    mov rax, -1
    ret
```

---

## 5. IPC Pipes (❌ → ✅)

### Concept
- Buffer circulaire en mémoire
- read() bloque si vide
- write() bloque si plein

### Fichiers
- `boot/kernel/pipe.asm` (nouveau)

### Structures

```asm
; ============================================================================
; PIPE STRUCTURE (128 bytes + buffer)
; ============================================================================
PIPE_READ_FD    equ 0       ; 4 bytes - read file descriptor
PIPE_WRITE_FD   equ 4       ; 4 bytes - write file descriptor
PIPE_BUFFER     equ 8       ; 8 bytes - buffer address
PIPE_SIZE       equ 16      ; 4 bytes - buffer size
PIPE_HEAD       equ 20      ; 4 bytes - write position
PIPE_TAIL       equ 24      ; 4 bytes - read position
PIPE_COUNT      equ 28      ; 4 bytes - bytes in buffer
PIPE_READERS    equ 32      ; 4 bytes - reader count
PIPE_WRITERS    equ 36      ; 4 bytes - writer count
PIPE_FLAGS      equ 40      ; 4 bytes - flags
PIPE_WAIT_READ  equ 44      ; 8 bytes - blocked reader queue
PIPE_WAIT_WRITE equ 52      ; 8 bytes - blocked writer queue

PIPE_STRUCT_SIZE equ 64
PIPE_BUFFER_SIZE equ 4096   ; Default 4KB buffer

MAX_PIPES       equ 32

section .bss
pipe_table:     resb (PIPE_STRUCT_SIZE * MAX_PIPES)
```

### Syscalls

```asm
; ============================================================================
; SYS_PIPE - Create pipe
; ============================================================================
; Input: RDI = int pipefd[2] (pointer to array)
; Output: RAX = 0 success, -1 error
;         pipefd[0] = read end, pipefd[1] = write end
; ============================================================================
sys_pipe:
    push rbx
    push r12

    mov r12, rdi                    ; Save pipefd pointer

    ; Find free pipe slot
    lea rbx, [pipe_table]
    xor ecx, ecx

.find:
    cmp ecx, MAX_PIPES
    jge .error

    cmp dword [rbx + PIPE_SIZE], 0
    je .found

    add rbx, PIPE_STRUCT_SIZE
    inc ecx
    jmp .find

.found:
    ; Allocate buffer
    mov rdi, 1                      ; 1 page
    call pmm_alloc_frame
    test rax, rax
    jz .error

    ; Initialize pipe
    mov [rbx + PIPE_BUFFER], rax
    mov dword [rbx + PIPE_SIZE], PIPE_BUFFER_SIZE
    mov dword [rbx + PIPE_HEAD], 0
    mov dword [rbx + PIPE_TAIL], 0
    mov dword [rbx + PIPE_COUNT], 0
    mov dword [rbx + PIPE_READERS], 1
    mov dword [rbx + PIPE_WRITERS], 1

    ; Allocate file descriptors
    ; TODO: proper FD allocation
    mov eax, ecx
    shl eax, 1
    add eax, 100                    ; Base FD for pipes
    mov [rbx + PIPE_READ_FD], eax
    inc eax
    mov [rbx + PIPE_WRITE_FD], eax

    ; Store in user array
    mov eax, [rbx + PIPE_READ_FD]
    mov [r12], eax
    mov eax, [rbx + PIPE_WRITE_FD]
    mov [r12 + 4], eax

    xor eax, eax
    jmp .done

.error:
    mov rax, -1

.done:
    pop r12
    pop rbx
    ret

; ============================================================================
; PIPE_READ - Read from pipe
; ============================================================================
; Input: RDI = pipe pointer, RSI = buffer, RDX = count
; Output: RAX = bytes read, 0 = EOF, -1 = error
; ============================================================================
pipe_read:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi                    ; Pipe
    mov r12, rsi                    ; Buffer
    mov r13, rdx                    ; Count
    xor r14d, r14d                  ; Bytes read

.read_loop:
    ; Check if data available
    mov eax, [rbx + PIPE_COUNT]
    test eax, eax
    jz .check_writers

    ; Read one byte
    mov rdi, [rbx + PIPE_BUFFER]
    mov eax, [rbx + PIPE_TAIL]
    movzx ecx, byte [rdi + rax]
    mov [r12], cl

    ; Advance tail
    inc eax
    cmp eax, [rbx + PIPE_SIZE]
    jl .no_wrap
    xor eax, eax
.no_wrap:
    mov [rbx + PIPE_TAIL], eax
    dec dword [rbx + PIPE_COUNT]

    inc r12
    inc r14d
    dec r13
    jnz .read_loop

    mov rax, r14
    jmp .done

.check_writers:
    ; No data - check if any writers exist
    cmp dword [rbx + PIPE_WRITERS], 0
    je .eof                         ; No writers = EOF

    ; Block and wait for data
    ; TODO: add to wait queue, yield, retry
    call scheduler_yield
    jmp .read_loop

.eof:
    mov rax, r14                    ; Return bytes read (may be 0)
    jmp .done

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; PIPE_WRITE - Write to pipe
; ============================================================================
; Input: RDI = pipe pointer, RSI = buffer, RDX = count
; Output: RAX = bytes written, -1 = error
; ============================================================================
pipe_write:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor r14d, r14d

.write_loop:
    ; Check if any readers
    cmp dword [rbx + PIPE_READERS], 0
    je .broken_pipe

    ; Check if space available
    mov eax, [rbx + PIPE_COUNT]
    cmp eax, [rbx + PIPE_SIZE]
    jge .wait_space

    ; Write one byte
    mov rdi, [rbx + PIPE_BUFFER]
    mov eax, [rbx + PIPE_HEAD]
    mov cl, [r12]
    mov [rdi + rax], cl

    ; Advance head
    inc eax
    cmp eax, [rbx + PIPE_SIZE]
    jl .no_wrap_w
    xor eax, eax
.no_wrap_w:
    mov [rbx + PIPE_HEAD], eax
    inc dword [rbx + PIPE_COUNT]

    inc r12
    inc r14d
    dec r13
    jnz .write_loop

    mov rax, r14
    jmp .done

.wait_space:
    ; Buffer full - yield and retry
    call scheduler_yield
    jmp .write_loop

.broken_pipe:
    ; TODO: send SIGPIPE to process
    mov rax, -1
    jmp .done

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
```

---

## Ordre d'implémentation

1. **Priority Scheduler** (simple, modifie scheduler_next)
2. **Signals** (nécessaire pour les autres features)
3. **Kernel Threads** (utilise scheduler existant)
4. **Pipes** (IPC simple)
5. **Shared Memory** (IPC avancé)

## Nouveaux fichiers à créer

```
boot/kernel/
├── signal.asm          ; Signal handling
├── thread.asm          ; Kernel threads
├── pipe.asm            ; IPC pipes
└── mm/
    └── shm.asm         ; Shared memory
```

## Nouveaux syscalls à ajouter

| Num | Name | Description |
|-----|------|-------------|
| 50 | sys_signal | Set signal handler |
| 51 | sys_sigreturn | Return from signal |
| 52 | sys_shmget | Create/get shared memory |
| 53 | sys_shmat | Attach shared memory |
| 54 | sys_shmdt | Detach shared memory |
| 55 | sys_pipe | Create pipe |
| 56 | sys_thread_create | Create thread |
| 57 | sys_thread_exit | Exit thread |
| 58 | sys_thread_join | Wait for thread |
| 59 | sys_setpriority | Set process priority |
