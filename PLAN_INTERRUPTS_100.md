# Plan Interrupts 100% - Exception Handlers

## Analyse État Actuel

### ✅ Déjà Fait
| Feature | Fichier | Description |
|---------|---------|-------------|
| IRQ0 Timer | `sys/timer.asm` | PIT 100Hz, tick_count |
| IRQ1 Keyboard | `input/keyboard.asm` | PS/2 scancode handler |
| IRQ12 Mouse | `core/isr.asm` | PS/2 3-byte packets |
| PIC setup | `sys/setup.asm` | IRQ remappé 0x20-0x2F |
| IDT setup | `sys/setup.asm` | 256 entrées, 64-bit |

### 🔶 Partiel
| Feature | Fichier | Problème |
|---------|---------|----------|
| Exceptions | `sys/exc_handlers.asm` | Stubs créés mais NON connectés à l'IDT |
| BSOD | `sys/exc_bsod.asm` | Affichage prêt mais pas utilisé |

### ❌ À Faire
| Feature | Priorité | Pourquoi |
|---------|----------|----------|
| Connecter exceptions à IDT | 🟡 | Les 32 handlers existent mais IDT utilise `default_exception_handler` |
| Double fault handler (IST) | 🟡 | Stack séparée pour éviter triple fault |
| Page fault handler | 🔴 | Requis pour mémoire virtuelle |

---

## Architecture Actuelle

```
┌─────────────────────────────────────────────────────────────────┐
│                         IDT (256 entrées)                       │
├─────────────────────────────────────────────────────────────────┤
│ INT 0x00-0x1F : default_exception_handler (halt simple)         │
│ INT 0x20      : timer_isr64 ✅                                  │
│ INT 0x21      : keyboard_isr64 ✅                               │
│ INT 0x2C      : mouse_isr64 ✅                                  │
│ INT 0x80      : syscall_isr64 ✅                                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│           exc_handlers.asm (NON UTILISÉ)                        │
├─────────────────────────────────────────────────────────────────┤
│ exc_handler_00 (#DE) → exc_common → bsod_draw                  │
│ exc_handler_08 (#DF) → exc_common → bsod_draw                  │
│ exc_handler_0e (#PF) → exc_common → bsod_draw                  │
│ ...                                                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Architecture Cible

```
┌─────────────────────────────────────────────────────────────────┐
│                         IDT (256 entrées)                       │
├─────────────────────────────────────────────────────────────────┤
│ INT 0x00 (#DE) : exc_handler_00 → BSOD "Divide Error"          │
│ INT 0x06 (#UD) : exc_handler_06 → BSOD "Invalid Opcode"        │
│ INT 0x08 (#DF) : exc_handler_08 → BSOD + IST1 (stack séparée)  │
│ INT 0x0D (#GP) : exc_handler_0d → BSOD "General Protection"    │
│ INT 0x0E (#PF) : page_fault_handler → Recovery OU BSOD         │
│ INT 0x20      : timer_isr64 ✅                                  │
│ INT 0x21      : keyboard_isr64 ✅                               │
│ INT 0x2C      : mouse_isr64 ✅                                  │
│ INT 0x80      : syscall_isr64 ✅                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Étapes d'Implémentation

### Étape 1: Connecter Exceptions à l'IDT
**Fichier**: `sys/setup.asm`

Remplacer le handler générique par les vrais handlers :

```nasm
; AVANT (actuel)
.fill_exceptions:
    mov rax, default_exception_handler
    ; ...

; APRÈS
setup_idt64:
    ; Exception 0: Divide Error
    mov rdi, idt64 + 0x00 * 16
    mov rax, exc_handler_00
    call set_idt_entry

    ; Exception 6: Invalid Opcode
    mov rdi, idt64 + 0x06 * 16
    mov rax, exc_handler_06
    call set_idt_entry

    ; Exception 8: Double Fault (avec IST1)
    mov rdi, idt64 + 0x08 * 16
    mov rax, exc_handler_08
    call set_idt_entry_ist1

    ; Exception 13: General Protection
    mov rdi, idt64 + 0x0D * 16
    mov rax, exc_handler_0d
    call set_idt_entry

    ; Exception 14: Page Fault
    mov rdi, idt64 + 0x0E * 16
    mov rax, page_fault_handler
    call set_idt_entry
```

**Tâches**:
- [ ] Modifier `setup_idt64` pour utiliser les vrais handlers
- [ ] Garder `default_exception_handler` pour les exceptions non critiques

---

### Étape 2: Double Fault Handler avec IST
**Fichier**: `sys/exc_double_fault.asm`

Le double fault est critique car il signifie que le handler d'exception a lui-même causé une exception. Sans stack séparée, c'est triple fault → reboot.

```nasm
; ============================================================================
; EXC_DOUBLE_FAULT.ASM - Double Fault Handler with IST
; ============================================================================
; Uses IST1 (Interrupt Stack Table entry 1) for a separate stack
; This prevents triple fault when stack is corrupted
; ============================================================================

; IST1 Stack (4KB)
IST1_STACK_SIZE     equ 4096
IST1_STACK_TOP      equ 0x9F000     ; Below main stack at 0x90000

section .text

exc_handler_08_ist:
    ; Already on IST1 stack - safe to proceed
    cli

    ; Save minimal state
    push rax
    push rbx
    push rdi

    ; Display BSOD with "DOUBLE FAULT" message
    call bsod_double_fault

    ; Halt forever - no recovery possible
.halt:
    hlt
    jmp .halt

bsod_double_fault:
    ; Fill screen red (double fault = critical)
    mov edi, [screen_fb]
    mov ecx, [screen_width]
    imul ecx, [screen_height]
    mov eax, 0x00800000         ; Dark red
.fill:
    mov [rdi], eax
    add rdi, 4
    dec ecx
    jnz .fill

    ; Print "DOUBLE FAULT" message
    ; ... (use bsod_print from exc_bsod.asm)
    ret
```

**Tâches**:
- [ ] Créer `sys/exc_double_fault.asm`
- [ ] Réserver stack IST1 (4KB à 0x9F000)
- [ ] Configurer TSS avec IST1 pointer
- [ ] Créer `set_idt_entry_ist1` dans setup.asm

---

### Étape 3: Configurer TSS pour IST
**Fichier**: `sys/setup.asm`

```nasm
; TSS structure (104 bytes minimum for 64-bit)
tss64:
    dd 0                    ; Reserved
    dq 0x90000              ; RSP0 (kernel stack)
    dq 0                    ; RSP1
    dq 0                    ; RSP2
    dq 0                    ; Reserved
    dq IST1_STACK_TOP       ; IST1 (double fault stack)  ← AJOUTER
    dq 0                    ; IST2
    dq 0                    ; IST3
    dq 0                    ; IST4
    dq 0                    ; IST5
    dq 0                    ; IST6
    dq 0                    ; IST7
    dq 0                    ; Reserved
    dw 0                    ; Reserved
    dw tss64_end - tss64    ; IO Map Base
tss64_end:
```

**Tâches**:
- [ ] Ajouter IST1 pointer dans TSS
- [ ] Vérifier TSS correctement chargé

---

### Étape 4: Page Fault Handler
**Fichier**: `sys/exc_page_fault.asm`

```nasm
; ============================================================================
; EXC_PAGE_FAULT.ASM - Page Fault Handler (#PF, INT 0x0E)
; ============================================================================
; CR2 contains the faulting address
; Error code on stack:
;   Bit 0: P (0 = non-present page, 1 = protection violation)
;   Bit 1: W (0 = read, 1 = write)
;   Bit 2: U (0 = supervisor, 1 = user)
;   Bit 3: RSVD (reserved bit set in page table)
;   Bit 4: I (instruction fetch)
; ============================================================================

PF_ERR_PRESENT      equ (1 << 0)
PF_ERR_WRITE        equ (1 << 1)
PF_ERR_USER         equ (1 << 2)
PF_ERR_RSVD         equ (1 << 3)
PF_ERR_IFETCH       equ (1 << 4)

section .text

page_fault_handler:
    ; Stack: [error_code] [RIP] [CS] [RFLAGS] [RSP] [SS]
    push rax
    push rbx
    push rcx
    push rdx

    ; Get faulting address from CR2
    mov rax, cr2
    mov [pf_address], rax

    ; Get error code
    mov rbx, [rsp + 32]     ; error code (after 4 pushes)
    mov [pf_error], rbx

    ; Check if recoverable (e.g., demand paging)
    ; For now, just show BSOD - no virtual memory yet

    ; Option 1: Demand paging (future)
    ; test rbx, PF_ERR_PRESENT
    ; jz .demand_page          ; Page not present = maybe allocate

    ; Option 2: Copy-on-write (future)
    ; test rbx, PF_ERR_WRITE
    ; jnz .cow_fault

    ; For now: Just BSOD
    jmp .fatal

.fatal:
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ; Jump to generic exception handler for BSOD
    push qword 0            ; Fake error code position
    push qword 14           ; Exception number
    jmp exc_common

section .data
pf_address: dq 0
pf_error:   dq 0
```

**Tâches**:
- [ ] Créer `sys/exc_page_fault.asm`
- [ ] Parser error code (P/W/U bits)
- [ ] Afficher adresse fautive dans BSOD
- [ ] Préparer hooks pour demand paging (future)

---

### Étape 5: Améliorer BSOD
**Fichier**: `sys/exc_bsod.asm`

Ajouter plus d'infos utiles :

```nasm
; Afficher:
; - Exception name
; - RIP (instruction pointer)
; - CR2 (page fault address)
; - Error code décodé
; - Stack trace (premiers 5 frames)
; - Tous les registres
```

**Tâches**:
- [ ] Ajouter stack trace basique
- [ ] Décoder error code en texte lisible
- [ ] Afficher CS/SS pour contexte (kernel vs user)

---

### Étape 6: Tester les Handlers
**Fichier**: `test/test_exceptions.asm`

```nasm
; Test division par zéro
test_div_zero:
    xor eax, eax
    div eax             ; #DE - Divide Error
    ret

; Test invalid opcode
test_invalid_opcode:
    ud2                 ; #UD - Invalid Opcode
    ret

; Test page fault
test_page_fault:
    mov rax, 0xDEADBEEF0000
    mov byte [rax], 0   ; #PF - Page Fault
    ret
```

**Tâches**:
- [ ] Créer tests pour chaque exception
- [ ] Vérifier BSOD s'affiche correctement
- [ ] Vérifier double fault ne cause pas triple fault

---

## Fichiers à Créer

| Fichier | Lignes | Description |
|---------|--------|-------------|
| `sys/exc_double_fault.asm` | ~50 | Handler double fault + IST |
| `sys/exc_page_fault.asm` | ~80 | Handler page fault |

---

## Fichiers à Modifier

| Fichier | Modification |
|---------|--------------|
| `sys/setup.asm` | Connecter exceptions, ajouter `set_idt_entry_ist1` |
| `data_all.asm` | Ajouter IST1 stack, TSS avec IST |
| `sys/exc_bsod.asm` | Améliorer affichage (stack trace) |

---

## Ordre d'Exécution Recommandé

```
1. [✅] Connecter exc_handlers.asm à l'IDT
2. [✅] Configurer TSS avec IST1
3. [✅] Activer exception handlers dans go64.asm
4. [✅] Tester boot normal
5. [✅] Page fault handler intégré (BSOD + CR2)
```

---

## Estimation Complexité

| Tâche | Difficulté | Lignes de code |
|-------|------------|----------------|
| Connecter IDT | 🟢 Facile | ~30 lignes |
| Double fault + IST | 🟡 Moyen | ~80 lignes |
| Page fault handler | 🟡 Moyen | ~80 lignes |
| Améliorer BSOD | 🟢 Facile | ~50 lignes |
| **TOTAL** | | **~240 lignes** |

---

## Ressources

- [OSDev Exceptions](https://wiki.osdev.org/Exceptions)
- [Intel SDM Vol 3 - Exception Handling](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- [OSDev IDT](https://wiki.osdev.org/Interrupt_Descriptor_Table)
- [OSDev TSS](https://wiki.osdev.org/Task_State_Segment)

---

## Résultat Final

Après implémentation :

| Feature | Status |
|---------|--------|
| IRQ0 Timer | ✅ |
| IRQ1 Keyboard | ✅ |
| IRQ12 Mouse | ✅ |
| Exceptions (div0, etc) | ✅ |
| Double fault handler | ✅ |
| Page fault handler | ✅ |

**Section 1.2 Interrupts : 100% ✅**

---

*Plan généré pour MathisOS - Décembre 2024*
