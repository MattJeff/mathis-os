# MODE FILES - Plan d'implémentation UI 2D

## État actuel ✅
- Liste de fichiers avec 3 entrées (PROJECTS/, README.TXT, HELLO.ASM)
- Sélection avec highlight
- Colonnes (Name, Size, Modified)
- Viewer simple avec syntax highlighting
- Navigation W/S, ENTER pour ouvrir, ESC pour fermer

---

## Phase 1 : Améliorer la liste de fichiers

### Step 1.1 - Footer avec raccourcis
- [ ] Activer `files_draw_footer` dans `files_main.asm`
- [ ] Afficher `[↑/↓] Navigate [ENTER] Open [N] New [D] Del [R] Rename`

### Step 1.2 - Plus d'entrées mock
- [ ] Ajouter 5 entrées supplémentaires dans `files_data.asm`
- [ ] Gérer le scroll si > 8 entrées visibles

### Step 1.3 - Icônes par type
- [ ] Icône dossier pour les `/`
- [ ] Icône fichier pour `.txt`, `.md`, `.asm`

---

## Phase 2 : Dialogs

### Step 2.1 - Créer `ui/dialog.asm`
- [ ] Fonction `draw_dialog_box(x, y, w, h, title)`
- [ ] Box centrée avec bordure blanche
- [ ] Fond semi-transparent ou sombre

### Step 2.2 - Dialog DELETE
- [ ] Afficher "⚠️ DELETE"
- [ ] Message "Are you sure you want to delete:"
- [ ] Nom du fichier sélectionné
- [ ] Boutons [CANCEL] [DELETE]

### Step 2.3 - Touche D
- [ ] Ajouter scancode 0x20 (D) dans `files_keys.asm`
- [ ] Mettre `files_dialog = 1` (delete dialog)
- [ ] Y = confirmer, N/ESC = annuler

### Step 2.4 - Dialog NEW
- [ ] Afficher "CREATE NEW"
- [ ] Radio: [●] File [ ] Folder
- [ ] Input field pour le nom
- [ ] Boutons [CANCEL] [CREATE]

### Step 2.5 - Touche N
- [ ] Ajouter scancode 0x31 (N) dans `files_keys.asm`
- [ ] Mettre `files_dialog = 2` (new dialog)

### Step 2.6 - Dialog RENAME
- [ ] Afficher "RENAME"
- [ ] Current name (lecture seule)
- [ ] Input field nouveau nom
- [ ] Boutons [CANCEL] [RENAME]

### Step 2.7 - Touche R
- [ ] Ajouter scancode 0x13 (R) dans `files_keys.asm`
- [ ] Mettre `files_dialog = 3` (rename dialog)

---

## Phase 3 : Input field

### Step 3.1 - Créer `ui/input.asm`
- [ ] Fonction `draw_input_field(x, y, w, buffer, cursor_pos)`
- [ ] Box avec fond sombre
- [ ] Texte blanc

### Step 3.2 - Saisie clavier
- [ ] Capturer caractères A-Z, 0-9, `.`, `_`, `-`
- [ ] Backspace pour effacer
- [ ] Limite de caractères (32 max)

### Step 3.3 - Curseur clignotant
- [ ] Bloc blanc à la position du curseur
- [ ] Toggle ON/OFF toutes les 500ms (via timer tick)

---

## Phase 4 : Éditeur de texte

### Step 4.1 - Créer `modes/files/files_edit.asm`
- [ ] Structure de base avec `files_edit_mode`
- [ ] Variables: `edit_line`, `edit_col`, `edit_modified`

### Step 4.2 - Header éditeur
- [ ] "📝 EDIT: filename"
- [ ] "[CTRL+S] Save [ESC] Back"

### Step 4.3 - Numéros de ligne
- [ ] Gutter de 4 caractères
- [ ] Couleur grise
- [ ] Format: ` 1 │`, ` 2 │`, etc.

### Step 4.4 - Contenu fichier
- [ ] Buffer de 20 lignes x 80 colonnes (mock)
- [ ] Afficher le texte ligne par ligne

### Step 4.5 - Status bar
- [ ] "Line X, Col Y"
- [ ] Type de fichier (ASM, TXT, MD)
- [ ] "Saved" ou "Modified"

### Step 4.6 - Navigation curseur
- [ ] Flèches haut/bas = changer de ligne
- [ ] Flèches gauche/droite = changer de colonne
- [ ] Home/End = début/fin de ligne

### Step 4.7 - Affichage curseur
- [ ] Bloc blanc à la position (line, col)
- [ ] Clignotant

### Step 4.8 - Syntax highlighting
- [ ] Commentaires (`;`) = vert
- [ ] Labels (`:`) = bleu
- [ ] Keywords (`mov`, `call`, `ret`) = jaune
- [ ] Strings (`"..."`) = orange

---

## Phase 5 : Intégration

### Step 5.1 - ENTER ouvre l'éditeur
- [ ] Modifier `files_keys.asm` pour appeler `files_edit_mode`
- [ ] Passer le fichier sélectionné

### Step 5.2 - ESC retourne à la liste
- [ ] Si `edit_modified`, demander confirmation
- [ ] Sinon, retour direct à `files_mode`

---

## Fichiers à créer/modifier

```
boot/kernel/
├── modes/files/
│   ├── files_main.asm      (modifier)
│   ├── files_draw.asm      (modifier)
│   ├── files_view.asm      (modifier)
│   ├── files_data.asm      (modifier)
│   └── files_edit.asm      (NOUVEAU)
├── ui/
│   ├── dialog.asm          (NOUVEAU)
│   └── input.asm           (NOUVEAU)
└── handlers/
    └── files_keys.asm      (modifier)
```

---

## Scancodes utiles

| Touche | Scancode |
|--------|----------|
| N      | 0x31     |
| D      | 0x20     |
| R      | 0x13     |
| Y      | 0x15     |
| ESC    | 0x01     |
| ENTER  | 0x1C     |
| BACKSP | 0x0E     |
| CTRL   | 0x1D     |
| S      | 0x1F     |

---

## Variables à ajouter dans `files_data.asm`

```asm
; Dialog state
files_dialog:     db 0    ; 0=none, 1=delete, 2=new, 3=rename
dialog_input_buf: times 32 db 0
dialog_input_pos: db 0
dialog_type:      db 0    ; 0=file, 1=folder (pour NEW)

; Editor state
edit_line:        dd 0
edit_col:         dd 0
edit_modified:    db 0
edit_filename:    times 32 db 0
```
