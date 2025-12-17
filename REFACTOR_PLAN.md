# MathisOS Refactor Plan

## Objectif
Passer de go64.asm (4K lignes) vers une architecture modulaire propre.

## Etat actuel (STABLE - commit 5af5843)
- File manager 2D fonctionnel
- Navigation clavier OK
- Style TVA/Loki OK

---

## PHASE 1 : Preparation (sans casser le build)

### Step 1.1 - Creer structure dossiers
```
mkdir -p boot/kernel/ui
mkdir -p boot/kernel/deprecated/3d
```
**Validation** : `ls boot/kernel/` montre les nouveaux dossiers

### Step 1.2 - Copier fichiers 3D vers deprecated (PAS supprimer)
```
cp boot/kernel/gfx3d/*.asm boot/kernel/deprecated/3d/
```
**Validation** : Les fichiers existent dans les 2 endroits

---

## PHASE 2 : Extraction UI (un fichier a la fois)

### Step 2.1 - Extraire draw.asm
Fonctions a extraire de go64.asm :
- draw_rect
- draw_filled_rect
- draw_line_h
- draw_line_v
- draw_char
- draw_string

**Validation** : Build OK + QEMU boot OK

### Step 2.2 - Extraire dialog.asm
Fonctions a extraire :
- draw_dialog_new
- dialog strings

**Validation** : Build OK + QEMU boot OK

### Step 2.3 - Extraire files.asm
Fonctions a extraire :
- draw_files_window
- files_mode logic
- navigation clavier fichiers

**Validation** : Build OK + QEMU boot OK + File manager fonctionne

### Step 2.4 - Extraire input.asm
Fonctions a extraire :
- keyboard_isr64 (partie fichiers)
- mouse handling

**Validation** : Build OK + clavier/souris OK

---

## PHASE 3 : Nettoyage

### Step 3.1 - Commenter includes 3D dans go64.asm
(Garder le code, juste desactiver)

### Step 3.2 - Verifier taille go64.asm < 2K lignes

### Step 3.3 - Documentation finale

---

## Regles
1. UN SEUL fichier modifie par step
2. Build + test apres CHAQUE step
3. Commit apres chaque step valide
4. Si ca casse -> git checkout -- . et on recommence le step
