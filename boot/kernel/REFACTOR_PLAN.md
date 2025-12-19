# MATHIS OS - Plan de Refactoring SOLID

## État actuel (après simplification)

### Modules actifs
```
core/entry64.asm     - Boot 32→64-bit
core/main_loop.asm   - Mode dispatcher
core/isr.asm         - ISRs (timer, keyboard, mouse)
scheduler.asm        - Multitasking (8 processes)
mm/heap.asm          - Allocateur mémoire (kmalloc/kfree)
fs/fat32.asm         - Filesystem FAT32
exec/elf.asm         - ELF loader
ui/draw.asm          - Primitives graphiques
ui/files.asm         - Widget fichiers
ui/input.asm         - Input helpers
input/*              - Keyboard/mouse state & handlers
handlers/global_keys.asm  - TAB, ESC
handlers/files_keys.asm   - Navigation fichiers
modes/files/*        - File manager (files_main, files_data, files_draw, files_view)
sys/timer.asm        - Timer IRQ0
sys/setup.asm        - IDT, TSS, PIC, PIT setup
sys/ring3.asm        - User mode support
services/registry.asm    - Service registry (INCLUS mais pas appelé)
services/alloc_svc.asm   - Alloc service (INCLUS mais pas appelé)
```

### Modules désactivés (stubs)
```
e1000/*         → net_init stub
usb/*           → usb_init stub
acpi.asm        → acpi_init stub
syscalls.asm    → syscall_handler stub
gfx3d/*         → ui3d_init, ui3d_main, camera_x/y/z stubs
modes/desktop.asm, graphics.asm, shell.asm → gui_mode, graphics_mode, shell_mode stubs
handlers/gui_keys, terminal_keys, shell_keys, 3d_keys → stubs
```

---

## Analyse de compatibilité ELF → Binary

### Chaîne de compilation actuelle
```
1. nasm -f elf64 core.asm -o core.o
2. x86_64-elf-ld -T kernel.ld -o kernel.elf core.o
3. x86_64-elf-objcopy -O binary --pad-to=0x90000 kernel.elf kernel.bin
```

### Sections dans le kernel
```
.entry  (0x10000)  - Tout le code (32-bit + 64-bit mélangés)
.fixed  (0x8F000)  - Variables à adresse fixe (4KB)
```

### Problème: Types de relocations
```
Type utilisé: R_X86_64_32 (adresses 32-bit absolues)

Exemples:
  mov dword [cursor_offset], 4    → relocation vers .fixed
  mov esi, banner_line1           → relocation vers .entry
  lea rdi, [service_table]        → relocation 32-bit (PROBLÈME en 64-bit!)
```

### Incompatibilités identifiées

1. **Adresses 32-bit en code 64-bit**
   - Le code 64-bit utilise des instructions avec adresses 32-bit
   - Fonctionne si toutes les adresses < 4GB (notre cas: 0x10000-0x90000)
   - MAIS: certaines instructions 64-bit nécessitent des adresses 64-bit

2. **Section .fixed à adresse fixe**
   - Crée un "trou" dans le binaire (de .entry à 0x8F000)
   - Empêche le code de grandir au-delà de ~500KB
   - Cause des crashs si on ajoute du code (décalage des offsets)

3. **Pas de vraies sections .text/.data/.bss**
   - Tout est dans .entry
   - Le linker ne peut pas optimiser le layout
   - Impossible de séparer code exécutable et données

---

## Plan de Refactoring

### Phase 1: Éliminer les adresses fixes

**Objectif:** Supprimer .fixed, tout rendre dynamique

**Étapes:**
1. Supprimer `section .fixed` de data_all.asm
2. Déplacer les variables vers go64.asm (section implicite)
3. Supprimer FIXED_ADDR du linker script
4. Tester le build et boot

**Fichiers modifiés:**
- kernel.ld
- data_all.asm
- go64.asm

**Risque:** Faible - les variables seront juste à une autre adresse

---

### Phase 2: Service Registry fonctionnel

**Objectif:** Activer registry_init sans crash

**Prérequis:** Phase 1 complète

**Étapes:**
1. Décommenter `call registry_init` dans entry64.asm
2. Décommenter `call alloc_svc_init`
3. Tester le boot
4. Vérifier que registry_initialized == 1

**Fichiers modifiés:**
- core/entry64.asm

**Test de validation:**
```asm
; Après boot, vérifier:
mov edi, SVC_ALLOC
call get_service
test rax, rax      ; doit être != 0
```

---

### Phase 3: Video Service

**Objectif:** Abstraire le dessin derrière une interface

**Fichiers à créer:**
```
services/video_svc.asm   - Interface + vtable
```

**V-Table Video:**
```asm
video_vtable:
    dq fill_rect        ; VIDEO_CLEAR (0)
    dq put_pixel        ; VIDEO_PIXEL (8)
    dq draw_rect        ; VIDEO_RECT (16)
    dq fill_rect        ; VIDEO_FILL (24)
    dq draw_text        ; VIDEO_TEXT (32)
```

**Étapes:**
1. Créer video_svc.asm avec vtable pointant vers ui/draw.asm
2. Ajouter video_svc_init qui enregistre SVC_VIDEO
3. Appeler video_svc_init dans entry64.asm
4. Modifier files_mode pour utiliser get_service(SVC_VIDEO)

---

### Phase 4: Input Service

**Objectif:** Abstraire input derrière une interface

**Fichiers à créer:**
```
services/input_svc.asm   - Interface + vtable
```

**V-Table Input:**
```asm
input_vtable:
    dq input_poll       ; INPUT_POLL (0)
    dq input_get_key    ; INPUT_KEY (8)
    dq input_mouse_x    ; INPUT_MOUSE_X (16)
    dq input_mouse_y    ; INPUT_MOUSE_Y (24)
    dq input_mouse_btn  ; INPUT_MOUSE_BTN (32)
```

**Étapes:**
1. Créer input_svc.asm avec vtable
2. Créer wrappers pour les fonctions existantes
3. Enregistrer SVC_INPUT au boot
4. Modifier handlers pour utiliser le service

---

### Phase 5: Widget Base Class

**Objectif:** Créer le système de widgets OOP

**Fichiers à créer:**
```
widgets/widget.asm      - Structure de base + helpers
widgets/file_list.asm   - Premier widget concret
```

**Structure Widget (48 bytes):**
```asm
struc Widget
    .vtable     resq 1      ; 0: pointeur V-Table
    .x          resd 1      ; 8: position X
    .y          resd 1      ; 12: position Y
    .w          resd 1      ; 16: largeur
    .h          resd 1      ; 20: hauteur
    .flags      resd 1      ; 24: VISIBLE, ENABLED, FOCUSED
    .parent     resq 1      ; 28: parent widget (ou 0)
    .userdata   resq 1      ; 36: données utilisateur
endstruc
```

**V-Table Widget:**
```asm
; Offset 0:  draw(self)
; Offset 8:  on_click(self, x, y) -> bool
; Offset 16: on_key(self, scancode) -> bool
; Offset 24: destroy(self)
```

**Étapes:**
1. Créer widget.asm avec macros helper
2. Créer file_list.asm héritant de Widget
3. Utiliser kmalloc pour l'allocation
4. Implémenter draw, on_click, on_key pour file_list

---

### Phase 6: Refactorer Files Mode avec Widgets

**Objectif:** files_mode utilise le système de widgets

**Étapes:**
1. files_mode_init crée un file_list widget
2. files_mode_loop appelle widget->draw()
3. Les événements clavier passent par widget->on_key()
4. Utiliser SVC_VIDEO pour le dessin

**Code cible:**
```asm
files_mode:
    ; Créer le widget si pas déjà fait
    cmp qword [files_widget], 0
    jnz .has_widget
    call file_list_create       ; kmalloc + init
    mov [files_widget], rax
.has_widget:
    ; Dessiner via vtable
    mov rdi, [files_widget]
    mov rax, [rdi]              ; vtable
    call [rax + VT_DRAW]        ; widget->draw()
    ret
```

---

## Ordre d'exécution

```
Phase 1 ─────────────────────────► Éliminer .fixed
    │
    ▼
Phase 2 ─────────────────────────► Registry fonctionnel
    │
    ▼
Phase 3 ─────────────────────────► Video Service
    │
    ▼
Phase 4 ─────────────────────────► Input Service
    │
    ▼
Phase 5 ─────────────────────────► Widget Base
    │
    ▼
Phase 6 ─────────────────────────► Files Mode refactoré
```

---

## Checklist finale SOLID

- [ ] **S** - Single Responsibility
  - [ ] 1 fichier = 1 responsabilité claire
  - [ ] services/ contient uniquement les interfaces
  - [ ] widgets/ contient uniquement les widgets

- [ ] **O** - Open/Closed
  - [ ] Nouveau widget = nouveau fichier (pas de modification)
  - [ ] Nouveau service = enregistrement dans registry
  - [ ] V-Tables pour extension

- [ ] **L** - Liskov Substitution
  - [ ] Tous les widgets implémentent la même interface
  - [ ] file_list peut être remplacé par n'importe quel widget

- [ ] **I** - Interface Segregation
  - [ ] VIDEO_* séparé de INPUT_*
  - [ ] Widget interface minimale (draw, on_click, on_key, destroy)

- [ ] **D** - Dependency Inversion
  - [ ] files_mode dépend de SVC_VIDEO, pas de ui/draw.asm directement
  - [ ] Pas d'adresses hardcodées
  - [ ] Tout passe par get_service()

---

## Notes techniques

### Adressage en 64-bit
```asm
; ÉVITER (adresse 32-bit, peut causer des problèmes):
mov eax, [some_variable]

; PRÉFÉRER (RIP-relative, toujours safe):
mov eax, [rel some_variable]

; OU utiliser un registre 64-bit:
lea rax, [rel some_variable]
mov eax, [rax]
```

### Allocation dynamique
```asm
; Créer un widget
mov rdi, WIDGET_SIZE
call kmalloc
test rax, rax
jz .alloc_failed
; rax = pointeur vers nouveau widget
```

### Appel via V-Table
```asm
; rdi = self (objet)
mov rax, [rdi]              ; rax = vtable
call [rax + METHOD_OFFSET]  ; appel méthode
```
