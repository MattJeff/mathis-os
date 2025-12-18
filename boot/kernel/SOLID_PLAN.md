# MATHIS OS - Plan Architecture SOLID

## Objectif

Transformer MathisOS en un kernel modulaire suivant les principes SOLID:
- **S**ingle Responsibility: 1 fichier = 1 responsabilité
- **O**pen/Closed: Extensible sans modifier le code existant (V-Tables)
- **L**iskov Substitution: Widgets interchangeables (polymorphisme)
- **I**nterface Segregation: Interfaces minimales par service
- **D**ependency Inversion: Services abstraits, pas de dépendances directes

---

## Phase 0: Préparation (Actuel → Base stable)

### Statut: ✅ FAIT
- [x] Cleanup des fichiers inutiles (44 fichiers supprimés)
- [x] Extraction core/entry64.asm, core/main_loop.asm, core/isr.asm
- [x] Documentation CONVENTIONS.md et KERNEL_MAP.md
- [x] go64.asm réduit de 1203 → 539 lignes

---

## Phase 1: Heap Allocator (Fondation)

### Pourquoi d'abord?
Sans allocateur dynamique, impossible de créer des objets à la volée.
Les V-Tables et widgets nécessitent `kmalloc/kfree`.

### Fichiers à créer/modifier

| Fichier | Action | Description |
|---------|--------|-------------|
| `mm/heap.asm` | MODIFIER | Implémenter kmalloc/kfree réels |
| `mm/heap_test.asm` | CRÉER | Tests unitaires heap |

### API Heap (Interface)

```asm
; ═══════════════════════════════════════════════════════════════
; HEAP SERVICE INTERFACE
; ═══════════════════════════════════════════════════════════════

; kmalloc - Alloue size bytes
; Input:  rdi = size (bytes)
; Output: rax = pointer (or 0 if failed)
kmalloc:

; kfree - Libère un bloc
; Input:  rdi = pointer
kfree:

; krealloc - Redimensionne un bloc
; Input:  rdi = pointer, rsi = new_size
; Output: rax = new pointer (or 0 if failed)
krealloc:

; heap_stats - Retourne stats (debug)
; Output: rax = bytes used, rdx = bytes free
heap_stats:
```

### Implémentation: Free List Allocator

```
┌─────────────────────────────────────────────────────────────┐
│ HEAP MEMORY LAYOUT (4MB - 20MB = 16MB heap)                 │
├─────────────────────────────────────────────────────────────┤
│ 0x400000: [HDR][────────── BLOCK 1 ──────────]              │
│           [HDR][── BLOCK 2 ──][HDR][─ BLOCK 3 ─]            │
│           ...                                                │
│ 0x1400000: END                                              │
└─────────────────────────────────────────────────────────────┘

Block Header (16 bytes):
  Offset 0:  size (8 bytes) - Taille du bloc (data seulement)
  Offset 8:  flags (4 bytes) - Bit 0 = used/free
  Offset 12: padding (4 bytes)
```

### Tests Phase 1

```
[ ] kmalloc(64) retourne pointeur valide
[ ] kfree() libère correctement
[ ] kmalloc après kfree réutilise l'espace
[ ] kmalloc(0) retourne 0
[ ] kfree(0) ne crash pas
[ ] Pas de fragmentation excessive après 100 alloc/free
```

---

## Phase 2: Service Registry (Dependency Inversion)

### Pourquoi?
Permet de découpler les modules. Le kernel ne dépend plus de drivers spécifiques.

### Fichiers à créer

| Fichier | Description |
|---------|-------------|
| `services/registry.asm` | Service locator central |
| `services/video_svc.asm` | Interface service vidéo |
| `services/input_svc.asm` | Interface service input |
| `services/alloc_svc.asm` | Interface service allocateur |
| `services/fs_svc.asm` | Interface service filesystem |

### API Registry

```asm
; Service IDs
SVC_VIDEO       equ 0   ; Dessin écran
SVC_INPUT       equ 1   ; Clavier/souris
SVC_ALLOC       equ 2   ; Heap allocator
SVC_FS          equ 3   ; Filesystem
SVC_NET         equ 4   ; Network
SVC_TIMER       equ 5   ; Timer/scheduler
SVC_MAX         equ 6

; register_service(id, vtable) - Enregistre un service
; get_service(id) -> vtable    - Récupère un service
```

### Service V-Table Format

```asm
; VIDEO SERVICE V-TABLE
video_svc_vtable:
    dq video_init           ; Offset 0:  init()
    dq video_clear          ; Offset 8:  clear(color)
    dq video_pixel          ; Offset 16: pixel(x, y, color)
    dq video_rect           ; Offset 24: rect(x, y, w, h, color)
    dq video_text           ; Offset 32: text(x, y, str, color)
    dq video_blit           ; Offset 40: blit(x, y, w, h, buffer)

; INPUT SERVICE V-TABLE
input_svc_vtable:
    dq input_init           ; Offset 0:  init()
    dq input_poll           ; Offset 8:  poll() -> event
    dq input_key_state      ; Offset 16: key_state(scancode) -> bool
    dq input_mouse_pos      ; Offset 24: mouse_pos() -> x, y
    dq input_mouse_btn      ; Offset 32: mouse_btn() -> buttons
```

### Tests Phase 2

```
[ ] register_service() fonctionne
[ ] get_service() retourne le bon vtable
[ ] get_service() sur ID invalide retourne 0
[ ] Services appelables via vtable
```

---

## Phase 3: Widget System (V-Tables OOP)

### Pourquoi?
Permet de créer des UI complexes avec polymorphisme.
Tous les widgets partagent la même interface.

### Fichiers à créer

| Fichier | Description |
|---------|-------------|
| `widgets/widget.asm` | Base widget + helpers |
| `widgets/button.asm` | Bouton cliquable |
| `widgets/label.asm` | Texte statique |
| `widgets/window.asm` | Fenêtre draggable |
| `widgets/textbox.asm` | Input texte |
| `widgets/list.asm` | Liste scrollable |
| `widgets/icon.asm` | Icône desktop |

### Widget Base Structure

```asm
; ═══════════════════════════════════════════════════════════════
; WIDGET BASE STRUCTURE (tous les widgets héritent)
; ═══════════════════════════════════════════════════════════════
struc Widget
    .vtable     resq 1      ; Offset 0:  Pointeur V-Table
    .x          resd 1      ; Offset 8:  Position X
    .y          resd 1      ; Offset 12: Position Y
    .width      resd 1      ; Offset 16: Largeur
    .height     resd 1      ; Offset 20: Hauteur
    .flags      resd 1      ; Offset 24: Flags (visible, enabled, focused)
    .parent     resq 1      ; Offset 28: Parent widget (or 0)
    .children   resq 1      ; Offset 36: Liste enfants (or 0)
    .userdata   resq 1      ; Offset 44: Data utilisateur
endstruc
WIDGET_SIZE equ 52

; Widget Flags
WIDGET_VISIBLE  equ 0x01
WIDGET_ENABLED  equ 0x02
WIDGET_FOCUSED  equ 0x04
WIDGET_DIRTY    equ 0x08    ; Needs redraw
```

### Widget V-Table

```asm
; ═══════════════════════════════════════════════════════════════
; WIDGET V-TABLE (chaque type implémente ces méthodes)
; ═══════════════════════════════════════════════════════════════
; Offset 0:  draw(self)           - Dessine le widget
; Offset 8:  on_click(self, x, y) - Gère le clic
; Offset 16: on_key(self, key)    - Gère touche clavier
; Offset 24: on_focus(self, focused) - Gagne/perd focus
; Offset 32: destroy(self)        - Libère ressources
; Offset 40: get_min_size(self)   - Retourne taille min (eax=w, edx=h)

VT_DRAW         equ 0
VT_ON_CLICK     equ 8
VT_ON_KEY       equ 16
VT_ON_FOCUS     equ 24
VT_DESTROY      equ 32
VT_GET_MIN_SIZE equ 40
```

### Exemple: Button Widget

```asm
; ═══════════════════════════════════════════════════════════════
; BUTTON WIDGET
; ═══════════════════════════════════════════════════════════════
struc Button
    .base       resb WIDGET_SIZE    ; Hérite de Widget
    .label      resq 1              ; Pointeur texte label
    .callback   resq 1              ; Fonction appelée au clic
    .bg_color   resd 1              ; Couleur fond
    .fg_color   resd 1              ; Couleur texte
endstruc
BUTTON_SIZE equ Button_size

button_vtable:
    dq button_draw
    dq button_click
    dq button_key
    dq button_focus
    dq button_destroy
    dq button_min_size

; button_create(label, callback) -> Button*
button_create:
    push rbx
    push r12
    push r13

    mov r12, rdi            ; label
    mov r13, rsi            ; callback

    ; Allocate via service
    mov edi, SVC_ALLOC
    call get_service
    mov rdi, rax
    mov esi, BUTTON_SIZE
    call [rdi + ALLOC_MALLOC]
    test rax, rax
    jz .fail
    mov rbx, rax

    ; Initialize
    lea rax, [button_vtable]
    mov [rbx + Widget.vtable], rax
    mov dword [rbx + Widget.flags], WIDGET_VISIBLE | WIDGET_ENABLED
    mov [rbx + Button.label], r12
    mov [rbx + Button.callback], r13
    mov dword [rbx + Button.bg_color], 0x00404040
    mov dword [rbx + Button.fg_color], 0x00FFFFFF

    mov rax, rbx
.fail:
    pop r13
    pop r12
    pop rbx
    ret
```

### Tests Phase 3

```
[ ] button_create() alloue et initialise
[ ] widget_draw() appelle la bonne méthode via vtable
[ ] button_click() exécute le callback
[ ] widget_destroy() libère la mémoire
[ ] Widgets enfants dessinés récursivement
```

---

## Phase 4: Refactoring Desktop avec Widgets

### Fichiers à modifier

| Fichier | Modification |
|---------|--------------|
| `modes/desktop.asm` | Utiliser widget system |
| `ui/desktop.asm` | Remplacer par widgets |
| `ui/taskbar.asm` | Convertir en widget |
| `ui/window.asm` | Convertir en widget |

### Nouveau Desktop Flow

```
desktop_init:
    1. Get services (video, input, alloc)
    2. Create root container widget
    3. Create taskbar widget (child of root)
    4. Create desktop icons (children of root)
    5. Register click/key handlers

desktop_loop:
    1. Poll input events
    2. Dispatch events to focused widget
    3. If any widget dirty: redraw tree
    4. Repeat
```

---

## Phase 5: Event System

### Fichiers à créer

| Fichier | Description |
|---------|-------------|
| `events/event.asm` | Event structures |
| `events/queue.asm` | Event queue (ring buffer) |
| `events/dispatch.asm` | Event dispatcher |

### Event Types

```asm
; Event Structure
struc Event
    .type       resd 1      ; Event type
    .timestamp  resq 1      ; Tick count
    .data       resb 24     ; Event-specific data
endstruc
EVENT_SIZE equ 36

; Event Types
EVT_NONE        equ 0
EVT_KEY_DOWN    equ 1
EVT_KEY_UP      equ 2
EVT_MOUSE_MOVE  equ 3
EVT_MOUSE_DOWN  equ 4
EVT_MOUSE_UP    equ 5
EVT_TIMER       equ 6
EVT_RESIZE      equ 7
EVT_FOCUS       equ 8
EVT_CUSTOM      equ 100
```

---

## Ordre d'Implémentation

```
Phase 1: Heap ──────────────────────────────► [2-3 heures]
    │
    ▼
Phase 2: Services ──────────────────────────► [2-3 heures]
    │
    ▼
Phase 3: Widgets ───────────────────────────► [4-5 heures]
    │
    ▼
Phase 4: Desktop Refactor ──────────────────► [3-4 heures]
    │
    ▼
Phase 5: Events ────────────────────────────► [2-3 heures]
```

**Total estimé: 13-18 heures de travail**

---

## Structure Finale Cible

```
kernel/
├── core/                   # Boot + Main loop
│   ├── entry64.asm
│   ├── main_loop.asm
│   └── isr.asm
│
├── mm/                     # Memory Management
│   ├── heap.asm            # kmalloc/kfree
│   └── paging.asm          # (futur)
│
├── services/               # Service Abstractions (D)
│   ├── registry.asm
│   ├── video_svc.asm
│   ├── input_svc.asm
│   ├── alloc_svc.asm
│   └── fs_svc.asm
│
├── drivers/                # Service Implementations (O)
│   ├── vesa.asm            # Implements video_svc
│   ├── ps2.asm             # Implements input_svc
│   └── fat32.asm           # Implements fs_svc
│
├── widgets/                # UI Components (L, I)
│   ├── widget.asm          # Base class
│   ├── container.asm
│   ├── button.asm
│   ├── label.asm
│   ├── textbox.asm
│   ├── window.asm
│   ├── list.asm
│   └── icon.asm
│
├── events/                 # Event System
│   ├── event.asm
│   ├── queue.asm
│   └── dispatch.asm
│
├── apps/                   # Applications (S)
│   ├── desktop.asm
│   ├── terminal.asm
│   ├── files.asm
│   └── settings.asm
│
└── sys/                    # System services
    ├── setup.asm
    ├── timer.asm
    └── scheduler.asm
```

---

## Checklist Globale

### Phase 1: Heap
- [ ] Implémenter free list dans mm/heap.asm
- [ ] kmalloc fonctionne
- [ ] kfree fonctionne
- [ ] Tests passent

### Phase 2: Services
- [ ] Créer services/registry.asm
- [ ] Créer services/video_svc.asm
- [ ] Créer services/input_svc.asm
- [ ] Créer services/alloc_svc.asm
- [ ] Adapter ui/draw.asm pour video_svc
- [ ] Tests passent

### Phase 3: Widgets
- [ ] Créer widgets/widget.asm (base)
- [ ] Créer widgets/button.asm
- [ ] Créer widgets/label.asm
- [ ] Créer widgets/window.asm
- [ ] Polymorphisme fonctionne via vtables
- [ ] Tests passent

### Phase 4: Desktop
- [ ] Refactorer modes/desktop.asm
- [ ] Desktop utilise widget system
- [ ] Taskbar est un widget
- [ ] Icônes sont des widgets
- [ ] Build + Boot OK

### Phase 5: Events
- [ ] Créer events/queue.asm
- [ ] Créer events/dispatch.asm
- [ ] Input ISR pousse dans queue
- [ ] Widgets reçoivent events

---

## Conventions à Ajouter

Ajouter dans CONVENTIONS.md:

```markdown
## V-Table Calling Convention

When calling a method via vtable:
1. rdi = self (object pointer)
2. Other args in rsi, rdx, rcx, r8, r9
3. Get vtable: mov rax, [rdi]
4. Call method: call [rax + METHOD_OFFSET]

## Object Ownership

- Creator is responsible for destruction
- Parent widgets own their children
- Use reference counting for shared objects (future)

## Service Usage

Always check service availability:
    mov edi, SVC_VIDEO
    call get_service
    test rax, rax
    jz .handle_missing_service
```

---

## Prochaine Action

**Commencer par Phase 1: Heap Allocator**

Le heap est la fondation de tout le reste. Sans lui, impossible de créer des objets dynamiques.
