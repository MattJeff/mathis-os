# MathisOS - Instructions de Refactoring

## Regles Importantes

1. **Step by step** - Chaque modification = 1 commit
2. **Validation utilisateur** - C'est l'utilisateur qui dit "commit" et "push"
3. **Sous-etapes** - Chaque step est decompose en sous-steps
4. **Test avant commit** - On verifie que ca marche avant de commiter

---

## Probleme Actuel : keyboard_isr64 monolithique

Le keyboard_isr64 fait TOUT dans un seul bloc de ~270 lignes :
- Gestion des modes (FILES, 3D, GUI, Terminal)
- Gestion shift/ctrl/alt
- Navigation arrows
- Commandes speciales (Tab, F9, ESC, Enter)
- Conversion scancode → ASCII
- Buffer de commande terminal

**Resultat** : Chaque nouvelle fonctionnalite = modifier ce bloc geant = bugs

---

## Solution : Architecture Event-Driven

### Principe
```
[IRQ1] → keyboard_isr64 (simple)
              ↓
         key_event (scancode + flags)
              ↓
         dispatcher
              ↓
    ┌─────────┼─────────┐
    ↓         ↓         ↓
 files    terminal    gui
handler    handler   handler
```

L'ISR devient SIMPLE : il lit le scancode, met a jour shift/ctrl, et stocke l'event.
Le dispatcher route vers le bon handler selon le mode actif.
Chaque handler gere SES touches, independamment.

---

## Architecture Cible

```
boot/kernel/
│
├── input/
│   ├── keyboard.asm      ; ISR simple : lit scancode → key_event
│   ├── mouse.asm         ; ISR simple : lit packet → mouse_event
│   ├── dispatcher.asm    ; Route events vers handlers selon mode
│   ├── scancode.asm      ; Tables scancode → ASCII
│   └── state.asm         ; Variables (shift_state, ctrl_state, key_event, etc.)
│
├── handlers/
│   ├── files_keys.asm    ; Touches pour file manager (W/S/Enter/Esc)
│   ├── terminal_keys.asm ; Touches pour terminal (typing, backspace, enter)
│   ├── gui_keys.asm      ; Touches pour GUI (arrows, Tab, space click)
│   └── global_keys.asm   ; Touches globales (ESC reboot, F9, etc.)
│
├── ui/
│   ├── desktop.asm       ; Desktop, icones, taskbar
│   ├── window.asm        ; Window management
│   ├── files.asm         ; File manager UI
│   ├── terminal.asm      ; Terminal UI
│   ├── dialog.asm        ; Popups/dialogs
│   └── draw.asm          ; Primitives graphiques
│
├── gfx/
│   ├── framebuffer.asm   ; Operations framebuffer
│   ├── font.asm          ; Font rendering
│   └── cursor.asm        ; Mouse cursor
│
├── fs/
│   └── fat32.asm         ; FAT32 (deja separe)
│
├── core/
│   ├── init.asm          ; Initialisation systeme
│   ├── irq.asm           ; Setup IDT/IRQ
│   └── memory.asm        ; Gestion memoire
│
└── deprecated/
    └── 3d/               ; Backup moteur 3D
```

---

## Nouveau keyboard_isr64 (simplifie)

```asm
keyboard_isr64:
    push rax
    push rbx

    in al, 0x60                     ; Lire scancode
    mov [last_scancode], al         ; Stocker

    ; Gerer shift/ctrl release
    test al, 0x80
    jnz .handle_release

    ; Gerer shift/ctrl press
    cmp al, 0x2A
    je .shift_on
    cmp al, 0x36
    je .shift_on
    cmp al, 0x1D
    je .ctrl_on

    ; Stocker key event pour dispatcher
    mov [key_pressed], al
    mov byte [key_ready], 1         ; Flag : nouvelle touche
    jmp .done

.shift_on:
    mov byte [shift_state], 1
    jmp .done
.ctrl_on:
    mov byte [ctrl_state], 1
    jmp .done
.handle_release:
    and al, 0x7F
    cmp al, 0x2A
    je .shift_off
    cmp al, 0x36
    je .shift_off
    cmp al, 0x1D
    je .ctrl_off
    jmp .done
.shift_off:
    mov byte [shift_state], 0
    jmp .done
.ctrl_off:
    mov byte [ctrl_state], 0

.done:
    mov al, 0x20
    out 0x20, al
    pop rbx
    pop rax
    iretq
```

---

## Dispatcher (dans main loop)

```asm
process_input:
    cmp byte [key_ready], 0
    je .no_key

    mov byte [key_ready], 0         ; Clear flag
    mov al, [key_pressed]

    ; Touches globales d'abord (ESC, F9, Tab)
    call handle_global_keys
    test al, al                     ; Si handled, skip
    jnz .no_key

    ; Router selon mode
    cmp byte [mode_flag], 4
    je .files_mode
    cmp byte [mode_flag], 3
    je .3d_mode
    cmp byte [mode_flag], 2
    je .gui_mode
    jmp .no_key

.files_mode:
    call handle_files_keys
    jmp .no_key
.3d_mode:
    call handle_3d_keys
    jmp .no_key
.gui_mode:
    call handle_gui_keys

.no_key:
    ret
```

---

## Plan de Migration

### Phase 1 : Preparation
- [ ] Step 1.1 - Creer input/state.asm avec variables
- [ ] Step 1.2 - Creer input/keyboard.asm (ISR simplifie)
- [ ] Step 1.3 - Creer input/dispatcher.asm

### Phase 2 : Handlers
- [ ] Step 2.1 - Creer handlers/global_keys.asm (ESC, Tab, F9)
- [ ] Step 2.2 - Creer handlers/gui_keys.asm (arrows, space, enter)
- [ ] Step 2.3 - Creer handlers/files_keys.asm (W/S/Enter/Esc)
- [ ] Step 2.4 - Creer handlers/terminal_keys.asm (typing)

### Phase 3 : Integration
- [ ] Step 3.1 - Remplacer keyboard_isr64 dans go64.asm
- [ ] Step 3.2 - Ajouter appel dispatcher dans main loop
- [ ] Step 3.3 - Tester chaque mode

### Phase 4 : Cleanup
- [ ] Step 4.1 - Supprimer ancien code du go64.asm
- [ ] Step 4.2 - Organiser ui/ et gfx/

---

## Comment Ajouter une Nouvelle Commande

AVANT (galere) :
1. Trouver le bon endroit dans keyboard_isr64 (270 lignes)
2. Ajouter cmp/je sans casser les autres
3. Prier

APRES (simple) :
1. Ouvrir le handler concerne (ex: handlers/terminal_keys.asm)
2. Ajouter :
```asm
    cmp al, 0xXX        ; Mon nouveau scancode
    je .ma_fonction
```
3. Done. Les autres handlers ne sont pas touches.

---

## Workflow

1. Lire le code source
2. Identifier ce qu'on deplace
3. Creer le nouveau fichier
4. **ATTENDRE validation utilisateur**
5. Commit
6. **ATTENDRE "push" de l'utilisateur**
7. Push
8. Passer au step suivant
