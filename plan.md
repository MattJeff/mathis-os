 PLAN - Mode FILES amélioré

  Step 1 : Ajouter touches N, D, R dans handlers/files_keys.asm (~20 lignes)
  - N (0x31) = ouvre dialog New
  - D (0x20) = ouvre dialog Delete
  - R (0x13) = ouvre dialog Rename

  Step 2 : Créer modes/files/files_dialog.asm (~150 lignes)
  - Variable files_dialog_type (0=none, 1=new, 2=delete, 3=rename)
  - files_draw_dialog_new - Dialog création
  - files_draw_dialog_delete - Dialog confirmation
  - files_draw_dialog_rename - Dialog renommage

  Step 3 : Ajouter données dialog dans modes/files/files_data.asm (~20 lignes)
  - Strings pour dialogs
  - Variables dialog (type, input buffer)

  Step 4 : Créer modes/files/files_edit.asm (~200 lignes)
  - Variable files_editing (0/1)
  - files_draw_editor - Affiche éditeur texte
  - Gestion curseur (ligne, colonne)
  - Buffer édition

  Step 5 : Ajouter touches éditeur dans handlers/files_keys.asm (~50 lignes)
  - Flèches = déplacer curseur
  - Caractères = taper
  - Backspace = effacer
  - CTRL+S = sauvegarder
  - ESC = fermer

  Step 6 : Intégrer dans files_main.asm (~10 lignes)
  - Check files_dialog_type pour afficher dialog
  - Check files_editing pour afficher éditeur

  ---
  On commence par Step 1 ?