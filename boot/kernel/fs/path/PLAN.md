# Plan: Path Parsing pour fs_readdir

## Objectif
Permettre à `fs_readdir("/desktop")` de lire les sous-répertoires, pas seulement root.

## Architecture Existante
- `fat32_find_file(name, dir_cluster)` → trouve un fichier/dossier dans un répertoire
- `fat32_read_cluster(cluster)` → lit un cluster
- `fs_readdir(path, buffer, max)` → lit les entrées d'un répertoire (ROOT only actuellement)

## Nouveau Module: fs/path/

### Fichier 1: path_types.asm (~10 lignes)
- Constantes: PATH_MAX_SEGMENTS, PATH_SEG_SIZE
- Buffer: path_segments (tableau de segments parsés)

### Fichier 2: path_parse.asm (~40 lignes)
- `path_parse(path)` → parse "/desktop/folder" en segments ["desktop", "folder"]
- Retourne: nombre de segments dans EAX

### Fichier 3: path_resolve.asm (~50 lignes)
- `path_resolve(path)` → retourne le cluster FAT32 du répertoire
- Utilise `path_parse` + `fat32_find_file` en boucle
- "/" → root_cluster
- "/desktop" → trouve "DESKTOP" dans root, retourne son cluster
- "/desktop/folder" → trouve "DESKTOP", puis "FOLDER" dedans

### Fichier 4: path.asm (~5 lignes)
- Include des 3 fichiers ci-dessus

## Modification de fs_svc.asm
Remplacer:
```asm
; Get root directory cluster
mov eax, [fat32_root_cluster]
```
Par:
```asm
; Resolve path to cluster
mov rdi, r12          ; path
call path_resolve
cmp eax, -1
je .readdir_error
```

## Flow
```
fs_readdir("/desktop")
    → path_resolve("/desktop")
        → path_parse("/desktop") → ["desktop"]
        → fat32_find_file("DESKTOP   ", root_cluster)
        → return cluster de DESKTOP
    → fat32_read_cluster(desktop_cluster)
    → parse entries
```

## Dépendances
- `fat32_find_file` existe déjà
- `fat32_convert_name` existe (convertit "desktop" → "DESKTOP   ")

## Estimation
- 4 fichiers
- ~100 lignes total
- Aucune modification de fat32.asm
