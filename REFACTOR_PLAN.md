# MathisOS Refactor Plan

## Objectif
Passer de go64.asm (4K lignes) vers une architecture modulaire propre.

---

## ETAT ACTUEL (Phase 1-2 terminee)

### Structure creee
```
boot/kernel/
├── ui/                      # NEW - UI modules
│   ├── draw.asm             # Primitives (draw_line_h, fill_rect, draw_rect, draw_text)
│   ├── dialog.asm           # Stub - popups (a remplir)
│   ├── files.asm            # Stub - file manager (a remplir)
│   └── input.asm            # Stub - clavier/souris (a remplir)
│
├── deprecated/3d/           # NEW - Backup 3D engine
│   ├── camera3d.asm
│   ├── effects3d.asm
│   ├── math3d.asm
│   ├── render3d.asm
│   ├── ui3d.asm
│   └── world3d.asm
│
├── gfx3d/                   # 3D engine (still active, marked DEPRECATED)
├── go64.asm                 # Main kernel (~4K lignes -> a reduire)
└── ...
```

### Fonctions deplacees vers ui/draw.asm
- [x] draw_line_h
- [x] fill_rect
- [x] draw_rect
- [x] draw_text

### Fonctions restantes a deplacer
- [ ] draw_line (Bresenham)
- [ ] draw_dialog_new -> ui/dialog.asm
- [ ] draw_files_window -> ui/files.asm
- [ ] keyboard_isr64 (partie UI) -> ui/input.asm
- [ ] mouse_isr64 -> ui/input.asm

---

## PROCHAINES ETAPES

### Phase 3 (en cours)
1. Continuer extraction vers ui/*.asm
2. Reduire go64.asm < 2K lignes
3. Tester chaque extraction

### Phase 4 (futur)
1. Commenter/desactiver gfx3d includes
2. Nettoyer code mort
3. Activer fichiers depuis deprecated/3d/ quand 2D stable

---

## Regles
1. UN SEUL fichier modifie par step
2. Build + test apres CHAQUE step
3. User valide avant push
4. Si ca casse -> git restore et recommencer
