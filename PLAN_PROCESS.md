# PLAN: Process Subsystem Completion

## Rules (MUST FOLLOW)

### Code Style
- SOLID, modular, 1 file = 1 task
- Max 100 lines per file
- Max 50 lines per function
- No globals (use passed pointers)
- No magic numbers (use constants)
- Snake_case for all identifiers
- Comments in English

### x86-64 Assembly
- System V ABI: RDI, RSI, RDX, RCX, R8, R9
- Preserved: R12-R15, RBX, RBP
- Scratch: RAX, RCX, RDX, RSI, RDI, R8-R11
- Stack aligned 16 bytes before call
- Code in section .text, data in section .data

---

## Phase 1: Priority Scheduler (ACTIVATE)

**Goal:** Replace round-robin with priority-based scheduling

### Files to modify:

#### 1.1 `sched/scheduler_select.asm` (NEW - ~40 lines)
```asm
; Single responsibility: Scheduler selection logic
; Calls scheduler_select_priority instead of round-robin

scheduler_select_next:
    ; Returns: RAX = pointer to next PCB (or NULL)
    call scheduler_select_priority
    ret
```

#### 1.2 `scheduler.asm` - Modify scheduler_schedule (~10 lines change)
```asm
; BEFORE (round-robin):
.find_next:
    add rbx, PCB_SIZE
    ...

; AFTER (priority):
    call scheduler_select_next
    test rax, rax
    jz .no_switch
    mov rdi, rax
    call switch_to_process
```

### Test:
- Create 2 processes with different priorities
- Verify high priority runs first

---

## Phase 2: Kernel Threads (~200 lines total)

**Goal:** Lightweight threads sharing address space

### New files:

#### 2.1 `thread/thread_const.asm` (~20 lines)
```asm
; Thread constants
THREAD_STACK_SIZE   equ 4096
MAX_THREADS         equ 16
THREAD_STATE_FREE   equ 0
THREAD_STATE_READY  equ 1
THREAD_STATE_RUN    equ 2
THREAD_STATE_WAIT   equ 3

; TCB offsets (Thread Control Block - 64 bytes)
TCB_STATE           equ 0   ; 1 byte
TCB_PRIORITY        equ 1   ; 1 byte
TCB_OWNER_PID       equ 2   ; 2 bytes
TCB_RSP             equ 8   ; 8 bytes
TCB_RIP             equ 16  ; 8 bytes
TCB_STACK_BASE      equ 24  ; 8 bytes
TCB_SIZE            equ 64
```

#### 2.2 `thread/thread_table.asm` (~15 lines)
```asm
section .data
align 8
thread_table:
    times (TCB_SIZE * MAX_THREADS) db 0
current_thread: dq 0

section .text
```

#### 2.3 `thread/thread_create.asm` (~50 lines)
```asm
; Input: RDI = entry point, RSI = arg
; Output: RAX = thread ID (-1 on error)
thread_create:
    ; Find free slot in thread_table
    ; Allocate stack (THREAD_STACK_SIZE)
    ; Setup initial stack frame (RIP, arg)
    ; Set state = THREAD_STATE_READY
    ret
```

#### 2.4 `thread/thread_exit.asm` (~30 lines)
```asm
; Called when thread function returns
thread_exit:
    ; Mark slot as FREE
    ; Free stack memory
    ; Switch to next thread
    ret
```

#### 2.5 `thread/thread_yield.asm` (~25 lines)
```asm
; Voluntary context switch
thread_yield:
    ; Save current RSP
    ; Find next READY thread
    ; Switch RSP
    ret
```

#### 2.6 `thread/thread_switch.asm` (~40 lines)
```asm
; Input: RDI = new thread TCB pointer
thread_switch:
    ; Save callee-saved registers
    ; Save RSP to current TCB
    ; Load RSP from new TCB
    ; Restore callee-saved registers
    ret
```

### Include order in go64.asm:
```asm
%include "thread/thread_const.asm"
%include "thread/thread_table.asm"
%include "thread/thread_create.asm"
%include "thread/thread_exit.asm"
%include "thread/thread_yield.asm"
%include "thread/thread_switch.asm"
```

---

## Phase 3: IPC Signals (COMPLETE)

**Goal:** Finish signal delivery and handlers

### Existing:
- `signal/const.asm` - Signal constants (SIGKILL, SIGTERM, etc.)
- `signal_table_data` in data_all.asm (256 bytes)

### New files:

#### 3.1 `signal/signal_send.asm` (~40 lines)
```asm
; Input: RDI = target PID, RSI = signal number
; Output: RAX = 0 success, -1 error
signal_send:
    ; Validate PID and signal
    ; Set bit in target's pending signals
    ; If target is WAITING, wake it
    ret
```

#### 3.2 `signal/signal_pending.asm` (~30 lines)
```asm
; Check and return pending signals for current process
; Output: RAX = pending signal mask
signal_pending:
    ret
```

#### 3.3 `signal/signal_handle.asm` (~50 lines)
```asm
; Input: RDI = signal number
; Dispatch to appropriate handler
signal_handle:
    ; Check if custom handler registered
    ; If yes, call handler
    ; If no, use default action (ignore/terminate)
    ret
```

#### 3.4 `signal/signal_register.asm` (~35 lines)
```asm
; Input: RDI = signal number, RSI = handler address
; Output: RAX = old handler (or -1 error)
signal_register:
    ; Validate signal number
    ; Store handler in signal_table_data
    ret
```

#### 3.5 `signal/signal_check.asm` (~30 lines)
```asm
; Called before returning to userspace
; Checks and delivers pending signals
signal_check_pending:
    ; Get pending mask
    ; For each pending signal, call signal_handle
    ret
```

### PCB extension needed:
```asm
PCB_SIGNAL_PENDING  equ 200  ; 8 bytes - bitmask of pending signals
PCB_SIGNAL_MASK     equ 208  ; 8 bytes - blocked signals
```

---

## Implementation Order

1. **Phase 1: Priority Scheduler** (30 min)
   - Modify scheduler.asm to call scheduler_select_priority
   - Test with 2 processes

2. **Phase 2: Kernel Threads** (2 hours)
   - Create const + table files
   - Implement thread_create
   - Implement thread_switch
   - Implement thread_yield
   - Test with simple thread

3. **Phase 3: IPC Signals** (1.5 hours)
   - Add PCB fields
   - Implement signal_send
   - Implement signal_handle
   - Implement signal_register
   - Test SIGTERM delivery

---

## File Count Summary

| Phase | New Files | Modified Files |
|-------|-----------|----------------|
| 1 | 1 | 1 |
| 2 | 6 | 1 (go64.asm) |
| 3 | 5 | 1 (PCB struct) |
| **Total** | **12** | **3** |

---

## Success Criteria

- [ ] Priority scheduler: High priority process runs before low priority
- [ ] Kernel threads: Can create and switch between 2 threads
- [ ] Signals: Can send SIGTERM and have it handled


 PLAN_PROCESS.md créé (258 lignes).

  Résumé du plan:

  Phase 1: Priority Scheduler (30 min)

  - 1 nouveau fichier: sched/scheduler_select.asm
  - Modifier scheduler.asm pour utiliser le priority scheduler existant

  Phase 2: Kernel Threads (2h)

  - 6 nouveaux fichiers dans thread/:
    - thread_const.asm - Constantes TCB
    - thread_table.asm - Table des threads
    - thread_create.asm - Créer un thread
    - thread_exit.asm - Terminer un thread
    - thread_yield.asm - Céder le CPU
    - thread_switch.asm - Context switch

  Phase 3: IPC Signals (1.5h)

  - 5 nouveaux fichiers dans signal/:
    - signal_send.asm - Envoyer un signal
    - signal_pending.asm - Signaux en attente
    - signal_handle.asm - Dispatcher
    - signal_register.asm - Enregistrer handler
    - signal_check.asm - Vérifier avant retour userspace

  Total: 12 nouveaux fichiers, 3 modifiés