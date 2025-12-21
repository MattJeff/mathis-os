# MATHIS OS - Plan de Conversion Modulaire Complet

## Vue d'ensemble

**Total**: ~130 composants, ~25,000 lignes
**Objectif**: Architecture 100% modulaire (1 fichier = 1 tâche, max 100 lignes)

---

## Phase 1: CORE (Semaine 1)
**Priorité: CRITIQUE** - Sans ça, rien ne marche

### 1.1 Entry & Boot (FAIT ✅)
- [x] `core_entry.asm` - Point d'entrée 64-bit
- [x] `core/tables.asm` - GDT, IDT, TSS, PIC, PIT

### 1.2 Memory Management (FAIT ✅)
- [x] `mm/heap_mod.asm` - Allocateur heap
- [x] `mm/pmm_mod.asm` - Pages physiques

### 1.3 Main Loop (FAIT ✅)
- [x] `core/main_loop_mod.asm` - Boucle principale
  - Exports: `kernel_main_loop`, `main_loop_running`
  - ~50 lignes

### 1.4 Timer (FAIT ✅)
- [x] `sys/timer_mod.asm` - Gestion du temps
  - Exports: `get_ticks`, `sleep_ms`, `sleep_ticks`
  - ~100 lignes

### 1.5 Double Buffering (FAIT ✅)
- [x] `ui/video_mod.asm` - Double buffering intégré
  - Exports: `video_init`, `video_flip`, `back_buffer`
  - Élimine le clignotement

---

## Phase 2: INPUT (Semaine 1-2)
**Priorité: HAUTE** - Interaction utilisateur

### 2.1 State (FAIT ✅)
- [x] `input/state_mod.asm` - Variables d'état
- [x] `input/keyboard_mod.asm` - ISR clavier + scancodes
- [x] `input/mouse_mod.asm` - ISR souris + init

### 2.2 Dispatcher (FAIT ✅)
- [x] `input/dispatcher_mod.asm` - Routage des événements

### 2.3 Cursor (À FAIRE)
- [ ] `input/cursor_mod.asm` - Curseur souris graphique
  - Exports: `cursor_draw`, `cursor_set_pos`
  - ~60 lignes

### 2.4 Input Manager (À FAIRE)
- [ ] `input/manager_mod.asm` - Gestionnaire centralisé
  - Exports: `input_update`, `input_get_key`, `input_get_mouse`
  - ~80 lignes

---

## Phase 3: VIDEO & DRAWING (Semaine 2)
**Priorité: HAUTE** - Affichage de base

### 3.1 Primitives (FAIT ✅)
- [x] `ui/video_mod.asm` - Opérations bas niveau
- [x] `ui/font_mod.asm` - Police 8x8
- [x] `ui/text_mod.asm` - Rendu texte
- [x] `ui/draw_mod.asm` - Rectangles, lignes

### 3.2 Colors (À FAIRE)
- [ ] `ui/colors_mod.asm` - Palette de couleurs
  - Exports: `COLOR_*` constants
  - ~40 lignes

### 3.3 Sprites (À FAIRE)
- [ ] `ui/sprite_mod.asm` - Sprites/icônes
  - Exports: `sprite_draw`, `sprite_load`
  - ~80 lignes

---

## Phase 4: WIDGETS (Semaine 2-3)
**Priorité: MOYENNE** - Composants UI réutilisables

### 4.1 Widget Base (À FAIRE)
- [ ] `widgets/widget_base_mod.asm` - Classe de base
  - Exports: `widget_create`, `widget_destroy`, `widget_draw`
  - V-table: draw, on_key, on_click, on_focus
  - ~100 lignes

### 4.2 Core Widgets (À FAIRE)
- [ ] `widgets/button_mod.asm` - Bouton cliquable (~80 lignes)
- [ ] `widgets/label_mod.asm` - Label texte (~50 lignes)
- [ ] `widgets/textbox_mod.asm` - Champ de saisie (~100 lignes)
- [ ] `widgets/checkbox_mod.asm` - Case à cocher (~60 lignes)

### 4.3 Container Widgets (À FAIRE)
- [ ] `widgets/panel_mod.asm` - Panneau conteneur (~70 lignes)
- [ ] `widgets/scrollview_mod.asm` - Vue scrollable (~100 lignes)

### 4.4 List Widgets (À FAIRE)
- [ ] `widgets/listview_mod.asm` - Liste d'items (~100 lignes)
- [ ] `widgets/treeview_mod.asm` - Vue arborescente (~100 lignes)

---

## Phase 5: WINDOW MANAGER (Semaine 3)
**Priorité: HAUTE** - Fenêtres flottantes

### 5.1 WM Core (À FAIRE)
- [ ] `wm/wm_state_mod.asm` - État du WM (~50 lignes)
  - Exports: `wm_windows[]`, `wm_active_window`, `wm_window_count`

- [ ] `wm/wm_create_mod.asm` - Création fenêtres (~80 lignes)
  - Exports: `wm_create_window`, `wm_close_window`

- [ ] `wm/wm_draw_mod.asm` - Rendu fenêtres (~100 lignes)
  - Exports: `wm_draw_all`, `wm_draw_window`, `wm_draw_titlebar`

- [ ] `wm/wm_input_mod.asm` - Input fenêtres (~100 lignes)
  - Exports: `wm_on_click`, `wm_on_key`, `wm_on_drag`

### 5.2 WM Controls (À FAIRE)
- [ ] `wm/wm_controls_mod.asm` - Boutons fenêtre (~80 lignes)
  - Exports: `wm_draw_close`, `wm_draw_minimize`, `wm_draw_maximize`

- [ ] `wm/wm_resize_mod.asm` - Redimensionnement (~70 lignes)
  - Exports: `wm_resize_start`, `wm_resize_update`

### 5.3 WM Integration (À FAIRE)
- [ ] `wm/wm_mod.asm` - Point d'entrée WM (~60 lignes)
  - Exports: `wm_init`, `wm_update`, `wm_has_windows`

---

## Phase 6: DESKTOP MODE (Semaine 3-4)
**Priorité: HAUTE** - Mode principal

### 6.1 Desktop Core (FAIT PARTIEL ✅)
- [x] `modes/desktop_mod.asm` - Base desktop (minimal)

### 6.2 Desktop Complet (À FAIRE)
- [ ] `desktop/desktop_bg_mod.asm` - Fond d'écran (~40 lignes)
- [ ] `desktop/desktop_taskbar_mod.asm` - Barre des tâches (~100 lignes)
- [ ] `desktop/desktop_icons_mod.asm` - Icônes desktop (~100 lignes)
- [ ] `desktop/desktop_menu_mod.asm` - Menu contextuel (~80 lignes)
- [ ] `desktop/desktop_click_mod.asm` - Gestion clics (~80 lignes)

---

## Phase 7: APPLICATIONS (Semaine 4-5)
**Priorité: MOYENNE** - Apps intégrées

### 7.1 Calculator (À FAIRE)
- [ ] `apps/calc/calc_state_mod.asm` - État calculatrice (~30 lignes)
- [ ] `apps/calc/calc_draw_mod.asm` - Affichage (~80 lignes)
- [ ] `apps/calc/calc_input_mod.asm` - Input (~60 lignes)
- [ ] `apps/calc/calc_logic_mod.asm` - Calculs (~80 lignes)
- [ ] `apps/calc/calc_mod.asm` - Entry point (~40 lignes)

### 7.2 Clock (À FAIRE)
- [ ] `apps/clock/clock_state_mod.asm` - État horloge (~20 lignes)
- [ ] `apps/clock/clock_draw_mod.asm` - Affichage (~100 lignes)
- [ ] `apps/clock/clock_mod.asm` - Entry point (~40 lignes)

### 7.3 Text Editor (À FAIRE)
- [ ] `apps/editor/editor_state_mod.asm` - État éditeur (~40 lignes)
- [ ] `apps/editor/editor_draw_mod.asm` - Affichage (~100 lignes)
- [ ] `apps/editor/editor_input_mod.asm` - Input (~100 lignes)
- [ ] `apps/editor/editor_mod.asm` - Entry point (~40 lignes)

### 7.4 Files Manager (À FAIRE)
- [ ] `apps/files/files_state_mod.asm` - État (~50 lignes)
- [ ] `apps/files/files_list_mod.asm` - Liste fichiers (~100 lignes)
- [ ] `apps/files/files_toolbar_mod.asm` - Toolbar (~60 lignes)
- [ ] `apps/files/files_sidebar_mod.asm` - Sidebar (~80 lignes)
- [ ] `apps/files/files_actions_mod.asm` - Actions CRUD (~80 lignes)
- [ ] `apps/files/files_mod.asm` - Entry point (~50 lignes)

### 7.5 Terminal (À FAIRE)
- [ ] `apps/terminal/term_state_mod.asm` - État terminal (~40 lignes)
- [ ] `apps/terminal/term_draw_mod.asm` - Affichage (~80 lignes)
- [ ] `apps/terminal/term_input_mod.asm` - Input (~80 lignes)
- [ ] `apps/terminal/term_mod.asm` - Entry point (~40 lignes)

---

## Phase 8: FILESYSTEM (Semaine 5)
**Priorité: MOYENNE** - Accès disque

### 8.1 ATA Driver (FAIT ✅)
- [x] `fs/ata_mod.asm` - Driver ATA PIO

### 8.2 VFS (À FAIRE)
- [ ] `fs/vfs_mod.asm` - Virtual FS layer (~100 lignes)
  - Exports: `vfs_open`, `vfs_read`, `vfs_write`, `vfs_list`

### 8.3 FAT32 (À FAIRE)
- [ ] `fs/fat32_mod.asm` - Driver FAT32 (~100 lignes)
  - Exports: `fat32_init`, `fat32_read_file`, `fat32_write_file`

---

## Phase 9: DRIVERS (Semaine 5)
**Priorité: BASSE** - Hardware additionnel

### 9.1 RTC (À FAIRE)
- [ ] `drivers/rtc_mod.asm` - Horloge temps réel (~60 lignes)
  - Exports: `rtc_get_time`, `rtc_get_date`

### 9.2 PCI (Optionnel)
- [ ] `drivers/pci_mod.asm` - Énumération PCI (~80 lignes)

---

## Phase 10: 3D GRAPHICS (Semaine 6+)
**Priorité: BASSE** - Fonctionnalité avancée

### 10.1 Math3D (À FAIRE)
- [ ] `gfx3d/math3d_mod.asm` - Vecteurs, matrices (~100 lignes)

### 10.2 Render3D (À FAIRE)
- [ ] `gfx3d/render3d_mod.asm` - Rendu 3D (~100 lignes)

### 10.3 Camera3D (À FAIRE)
- [ ] `gfx3d/camera3d_mod.asm` - Caméra 3D (~80 lignes)

---

## Résumé des Phases

| Phase | Composants | Lignes Est. | Status |
|-------|------------|-------------|--------|
| 1. Core | 5 | ~400 | 100% ✅ |
| 2. Input | 6 | ~400 | 70% ✅ |
| 3. Video | 6 | ~500 | 100% ✅ |
| 4. Widgets | 8 | ~700 | 0% |
| 5. Window Manager | 7 | ~600 | 0% |
| 6. Desktop | 6 | ~500 | 20% |
| 7. Applications | 20 | ~1500 | 0% |
| 8. Filesystem | 3 | ~300 | 30% |
| 9. Drivers | 2 | ~150 | 0% |
| 10. 3D Graphics | 3 | ~300 | 0% |
| **TOTAL** | **66** | **~5350** | **35%** |

---

## Conventions de Code (Rappel)

```asm
; ============================================================================
; MODULE_NAME_MOD.ASM - Description courte
; ============================================================================
; Description détaillée
; ============================================================================

[BITS 64]
[DEFAULT REL]

; Constants (pas de magic numbers)
CONST_NAME              equ 0x1234

; Exports
global function_name

; Imports
extern dependency_name

section .text

; Max 50 lignes par fonction
; System V: RDI, RSI, RDX, RCX, R8, R9
; Preserved: R12-R15, RBX, RBP
function_name:
    ; ...
    ret

section .data
section .rodata
section .bss
```

---

## Ordre d'Implémentation Recommandé

1. **Immédiat**: cursor_mod, input_manager_mod (pour avoir une souris visible)
2. **Court terme**: wm_* modules (pour les fenêtres)
3. **Moyen terme**: widgets, apps
4. **Long terme**: 3D, drivers avancés

---

## Prochaine Étape

Créer `input/cursor_mod.asm` pour afficher le curseur souris ?
