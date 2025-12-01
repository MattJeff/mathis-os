# Syscalls - Spécification Complète

## 1. Vue d'Ensemble

Les **syscalls** sont l'interface entre le code MATHIS et les services du kernel. Ils permettent d'accéder aux fonctionnalités de tes **65 modules existants**.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CODE MATHIS                                      │
│                                                                             │
│  SYSCALL 0x0A01    ←── Instruction bytecode                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SYSCALL DISPATCHER                                  │
│                                                                             │
│  match syscall_id {                                                         │
│      0x0001..0x00FF => io_handler,      // mathis-io                       │
│      0x0100..0x01FF => net_handler,     // mathis-http, websocket, grpc    │
│      0x0700..0x07FF => db_handler,      // mathis-database, redis          │
│      0x0900..0x09FF => crypto_handler,  // mathis-crypto, tls              │
│      0x0A00..0x0AFF => ai_handler,      // mathis-ai, rag ⭐               │
│      ...                                                                    │
│  }                                                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     TES 65 MODULES EXISTANTS                                │
│                                                                             │
│  mathis-crypto │ mathis-http │ mathis-ai │ mathis-database │ ...           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Convention d'Appel

### 2.1 Format Bytecode

```
SYSCALL <syscall_id:u16>
```

### 2.2 Passage d'Arguments

Les arguments sont passés sur la stack (premier argument au fond):

```masm
; Exemple: http_get("https://api.example.com")
CONST_STR "https://api.example.com"   ; Push URL
SYSCALL 0x0120                         ; Appel syscall
; Stack contient maintenant: [Response]
```

### 2.3 Valeur de Retour

- **Succès**: La valeur de retour est sur la stack
- **Erreur**: Exception levée (ou `Result<T, E>` selon le syscall)

---

## 3. Mapping Modules → Syscalls

### 3.1 Vue d'Ensemble

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  RANGE           │ CATÉGORIE      │ MODULES MATHIS                          ║
╠══════════════════╪════════════════╪═════════════════════════════════════════╣
║  0x0001-0x00FF   │ I/O            │ (core) fichiers, console                ║
║  0x0100-0x01FF   │ Network        │ http, http2, websocket, grpc, webrtc    ║
║  0x0200-0x02FF   │ DNS            │ (dans http)                             ║
║  0x0300-0x03FF   │ Process        │ async (scheduler, tasks)                ║
║  0x0400-0x04FF   │ Memory         │ (kernel interne)                        ║
║  0x0500-0x05FF   │ Sync           │ async (channels, mutex)                 ║
║  0x0600-0x06FF   │ Filesystem     │ storage, s3                             ║
║  0x0700-0x07FF   │ Database       │ database, redis, vectordb               ║
║  0x0800-0x08FF   │ Auth           │ auth (JWT, OAuth, TOTP, WebAuthn)       ║
║  0x0900-0x09FF   │ Crypto         │ crypto, tls                             ║
║  0x0A00-0x0AFF   │ AI ⭐          │ ai, rag, vectordb                       ║
║  0x0B00-0x0BFF   │ Media          │ image, rtmp, hls, ffmpeg, transcode,drm ║
║  0x0C00-0x0CFF   │ Time           │ time, cron                              ║
║  0x0D00-0x0DFF   │ Queue          │ queue                                   ║
║  0x0E00-0x0EFF   │ Search         │ fts                                     ║
║  0x0F00-0x0FFF   │ Observability  │ metrics, log                            ║
║  0x1000-0x10FF   │ Email          │ email                                   ║
║  0x1100-0x11FF   │ Documents      │ pdf                                     ║
║  0x1200-0x12FF   │ Geo            │ geo                                     ║
║  0x1300-0x13FF   │ Serialization  │ json, protobuf, serialize               ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 4. I/O Syscalls (0x0001-0x00FF)

### 4.1 Fichiers

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0001` | `io_open` | `(path: str, flags: i64) -> fd` | Ouvre un fichier |
| `0x0002` | `io_read` | `(fd: i64, len: i64) -> bytes` | Lit des bytes |
| `0x0003` | `io_write` | `(fd: i64, data: bytes) -> i64` | Écrit, retourne nb écrit |
| `0x0004` | `io_close` | `(fd: i64) -> none` | Ferme un fichier |
| `0x0005` | `io_seek` | `(fd, offset, whence) -> i64` | Déplace le curseur |
| `0x0006` | `io_flush` | `(fd: i64) -> none` | Flush le buffer |
| `0x0007` | `io_stat` | `(path: str) -> FileStat` | Métadonnées |
| `0x0008` | `io_exists` | `(path: str) -> bool` | Fichier existe? |

### 4.2 Console

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0010` | `io_print` | `(msg: str) -> none` | Print stdout |
| `0x0011` | `io_println` | `(msg: str) -> none` | Print + newline |
| `0x0012` | `io_eprint` | `(msg: str) -> none` | Print stderr |
| `0x0013` | `io_input` | `() -> str` | Lit une ligne stdin |
| `0x0014` | `io_input_prompt` | `(prompt: str) -> str` | Input avec prompt |

### 4.3 Flags d'Ouverture

```rust
const O_RDONLY: i64 = 0x0001;
const O_WRONLY: i64 = 0x0002;
const O_RDWR: i64   = 0x0003;
const O_CREATE: i64 = 0x0100;
const O_TRUNC: i64  = 0x0200;
const O_APPEND: i64 = 0x0400;
```

---

## 5. Network Syscalls (0x0100-0x01FF)

### 5.1 HTTP Client (→ mathis-http)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0120` | `http_get` | `(url: str) -> Response` | GET request |
| `0x0121` | `http_post` | `(url, body, headers) -> Response` | POST request |
| `0x0122` | `http_put` | `(url, body, headers) -> Response` | PUT request |
| `0x0123` | `http_delete` | `(url, headers) -> Response` | DELETE request |
| `0x0124` | `http_request` | `(Request) -> Response` | Request générique |
| `0x0125` | `http_download` | `(url, path) -> i64` | Download fichier |

### 5.2 HTTP Server (→ mathis-http)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0130` | `http_server_new` | `(addr, port) -> server_id` | Crée serveur |
| `0x0131` | `http_server_route` | `(server, method, path, handler) -> none` | Ajoute route |
| `0x0132` | `http_server_middleware` | `(server, middleware) -> none` | Ajoute middleware |
| `0x0133` | `http_server_start` | `(server) -> none` | Démarre (async) |
| `0x0134` | `http_server_stop` | `(server) -> none` | Arrête |

### 5.3 WebSocket (→ mathis-websocket)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0140` | `ws_connect` | `(url: str) -> ws_id` | Connecte WS client |
| `0x0141` | `ws_send` | `(ws_id, data) -> none` | Envoie message |
| `0x0142` | `ws_send_binary` | `(ws_id, bytes) -> none` | Envoie binaire |
| `0x0143` | `ws_recv` | `(ws_id) -> Message` | Reçoit message |
| `0x0144` | `ws_close` | `(ws_id) -> none` | Ferme |

### 5.4 gRPC (→ mathis-grpc)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0150` | `grpc_channel` | `(addr: str) -> channel_id` | Crée channel |
| `0x0151` | `grpc_call` | `(channel, service, method, req) -> resp` | Appel unaire |
| `0x0152` | `grpc_stream` | `(channel, service, method) -> stream_id` | Stream |

### 5.5 WebRTC (→ mathis-webrtc)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0160` | `webrtc_peer_new` | `(config) -> peer_id` | Crée peer connection |
| `0x0161` | `webrtc_create_offer` | `(peer_id) -> sdp` | Crée offer |
| `0x0162` | `webrtc_create_answer` | `(peer_id, offer) -> sdp` | Crée answer |
| `0x0163` | `webrtc_set_remote` | `(peer_id, sdp) -> none` | Set remote SDP |
| `0x0164` | `webrtc_add_ice` | `(peer_id, candidate) -> none` | Add ICE candidate |
| `0x0165` | `webrtc_data_channel` | `(peer_id, label) -> dc_id` | Crée data channel |
| `0x0166` | `webrtc_send` | `(dc_id, data) -> none` | Envoie sur DC |

### 5.6 TLS (→ mathis-tls)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0170` | `tls_connect` | `(sock, hostname) -> tls_sock` | Upgrade TLS |
| `0x0171` | `tls_accept` | `(sock, cert, key) -> tls_sock` | Accept TLS |

---

## 6. Database Syscalls (0x0700-0x07FF)

### 6.1 SQL (→ mathis-database)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0700` | `db_connect` | `(url: str) -> conn_id` | Connect (PG/SQLite) |
| `0x0701` | `db_close` | `(conn_id) -> none` | Close |
| `0x0702` | `db_ping` | `(conn_id) -> bool` | Ping |
| `0x0710` | `db_query` | `(conn, sql, params) -> List<Row>` | Query |
| `0x0711` | `db_execute` | `(conn, sql, params) -> i64` | Execute (affected) |
| `0x0712` | `db_query_one` | `(conn, sql, params) -> Option<Row>` | Query one |
| `0x0720` | `db_begin` | `(conn) -> tx_id` | Begin transaction |
| `0x0721` | `db_commit` | `(tx_id) -> none` | Commit |
| `0x0722` | `db_rollback` | `(tx_id) -> none` | Rollback |

### 6.2 Redis (→ mathis-redis)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0740` | `redis_connect` | `(url) -> redis_id` | Connect |
| `0x0741` | `redis_get` | `(redis, key) -> Option<str>` | GET |
| `0x0742` | `redis_set` | `(redis, key, value) -> none` | SET |
| `0x0743` | `redis_setex` | `(redis, key, value, ttl) -> none` | SETEX |
| `0x0744` | `redis_del` | `(redis, key) -> i64` | DEL |
| `0x0745` | `redis_incr` | `(redis, key) -> i64` | INCR |
| `0x0746` | `redis_lpush` | `(redis, key, values) -> i64` | LPUSH |
| `0x0747` | `redis_rpop` | `(redis, key) -> Option<str>` | RPOP |
| `0x0748` | `redis_hget` | `(redis, key, field) -> Option<str>` | HGET |
| `0x0749` | `redis_hset` | `(redis, key, field, value) -> none` | HSET |
| `0x074A` | `redis_publish` | `(redis, channel, msg) -> i64` | PUBLISH |
| `0x074B` | `redis_subscribe` | `(redis, channels) -> sub_id` | SUBSCRIBE |

### 6.3 Vector DB (→ mathis-vectordb)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0760` | `vectordb_create` | `(name, dimensions) -> db_id` | Crée collection |
| `0x0761` | `vectordb_insert` | `(db, id, vector, metadata) -> none` | Insert |
| `0x0762` | `vectordb_search` | `(db, vector, k, filter) -> List<Match>` | KNN search |
| `0x0763` | `vectordb_delete` | `(db, id) -> none` | Delete |
| `0x0764` | `vectordb_update` | `(db, id, vector, metadata) -> none` | Update |

---

## 7. Auth Syscalls (0x0800-0x08FF)

### 7.1 JWT (→ mathis-auth)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0800` | `auth_jwt_sign` | `(payload, secret, algo) -> str` | Sign JWT |
| `0x0801` | `auth_jwt_verify` | `(token, secret) -> Claims` | Verify JWT |
| `0x0802` | `auth_jwt_decode` | `(token) -> Claims` | Decode (no verify) |

### 7.2 OAuth2 (→ mathis-auth)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0810` | `auth_oauth_url` | `(provider, config) -> str` | Auth URL |
| `0x0811` | `auth_oauth_callback` | `(provider, code) -> TokenResponse` | Handle callback |
| `0x0812` | `auth_oauth_refresh` | `(provider, refresh_token) -> TokenResponse` | Refresh |
| `0x0813` | `auth_oauth_userinfo` | `(provider, access_token) -> UserInfo` | Get user info |

**Providers supportés**: Google, GitHub, Discord, Apple, Microsoft

### 7.3 Password (→ mathis-auth)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0820` | `auth_password_hash` | `(password) -> str` | Argon2 hash |
| `0x0821` | `auth_password_verify` | `(password, hash) -> bool` | Verify |

### 7.4 TOTP/2FA (→ mathis-auth)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0830` | `auth_totp_secret` | `() -> str` | Generate secret |
| `0x0831` | `auth_totp_generate` | `(secret) -> str` | Generate code |
| `0x0832` | `auth_totp_verify` | `(secret, code) -> bool` | Verify code |
| `0x0833` | `auth_totp_qr` | `(secret, issuer, account) -> str` | QR URL |

### 7.5 WebAuthn/Passkeys (→ mathis-auth)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0840` | `auth_webauthn_register_options` | `(user) -> Options` | Registration options |
| `0x0841` | `auth_webauthn_register_verify` | `(response) -> Credential` | Verify registration |
| `0x0842` | `auth_webauthn_auth_options` | `(user) -> Options` | Auth options |
| `0x0843` | `auth_webauthn_auth_verify` | `(response) -> bool` | Verify auth |

### 7.6 Sessions (→ mathis-auth)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0850` | `auth_session_create` | `(user_id, data, ttl) -> session_id` | Create |
| `0x0851` | `auth_session_get` | `(session_id) -> Option<Session>` | Get |
| `0x0852` | `auth_session_update` | `(session_id, data) -> none` | Update |
| `0x0853` | `auth_session_destroy` | `(session_id) -> none` | Destroy |

---

## 8. Crypto Syscalls (0x0900-0x09FF)

### 8.1 Hashing (→ mathis-crypto)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0900` | `crypto_sha256` | `(data: bytes) -> bytes` | SHA-256 |
| `0x0901` | `crypto_sha384` | `(data: bytes) -> bytes` | SHA-384 |
| `0x0902` | `crypto_sha512` | `(data: bytes) -> bytes` | SHA-512 |
| `0x0903` | `crypto_blake3` | `(data: bytes) -> bytes` | BLAKE3 |
| `0x0904` | `crypto_hmac` | `(algo, key, data) -> bytes` | HMAC |

### 8.2 Encryption (→ mathis-crypto)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0910` | `crypto_aes_encrypt` | `(key, iv, data) -> bytes` | AES-256-GCM |
| `0x0911` | `crypto_aes_decrypt` | `(key, iv, data) -> bytes` | AES-256-GCM |
| `0x0912` | `crypto_chacha_encrypt` | `(key, nonce, data) -> bytes` | ChaCha20-Poly1305 |
| `0x0913` | `crypto_chacha_decrypt` | `(key, nonce, data) -> bytes` | ChaCha20-Poly1305 |

### 8.3 Signatures (→ mathis-crypto)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0920` | `crypto_ed25519_keypair` | `() -> (private, public)` | Generate keypair |
| `0x0921` | `crypto_ed25519_sign` | `(private_key, data) -> bytes` | Sign |
| `0x0922` | `crypto_ed25519_verify` | `(public_key, data, sig) -> bool` | Verify |
| `0x0923` | `crypto_ecdsa_sign` | `(private_key, data) -> bytes` | ECDSA sign |
| `0x0924` | `crypto_ecdsa_verify` | `(public_key, data, sig) -> bool` | ECDSA verify |
| `0x0925` | `crypto_rsa_sign` | `(private_key, data) -> bytes` | RSA sign |
| `0x0926` | `crypto_rsa_verify` | `(public_key, data, sig) -> bool` | RSA verify |

### 8.4 Key Exchange (→ mathis-crypto)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0930` | `crypto_x25519_keypair` | `() -> (private, public)` | Generate |
| `0x0931` | `crypto_x25519_derive` | `(private, peer_public) -> bytes` | Derive secret |

### 8.5 Random (→ mathis-crypto)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0940` | `crypto_random_bytes` | `(len: i64) -> bytes` | Random bytes |
| `0x0941` | `crypto_random_int` | `(min, max) -> i64` | Random int |
| `0x0942` | `crypto_uuid_v4` | `() -> str` | UUID v4 |
| `0x0943` | `crypto_uuid_v7` | `() -> str` | UUID v7 |

---

## 9. AI Syscalls (0x0A00-0x0AFF) ⭐ UNIQUE

### 9.1 Chat/Completions (→ mathis-ai)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0A00` | `ai_chat` | `(messages, model, opts) -> str` | Chat completion |
| `0x0A01` | `ai_complete` | `(prompt, model, opts) -> str` | Text completion |
| `0x0A02` | `ai_stream` | `(messages, model, opts) -> Stream` | Streaming |

### 9.2 Embeddings (→ mathis-ai)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0A10` | `ai_embed` | `(text: str) -> List<f64>` | Generate embedding |
| `0x0A11` | `ai_embed_batch` | `(texts: List) -> List<List<f64>>` | Batch |
| `0x0A12` | `ai_similarity` | `(emb1, emb2) -> f64` | Cosine similarity |

### 9.3 Function Calling (→ mathis-ai)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0A20` | `ai_function_call` | `(messages, functions) -> FunctionCall` | Function calling |
| `0x0A21` | `ai_structured` | `(prompt, json_schema) -> json` | Structured output |

### 9.4 RAG (→ mathis-rag)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0A30` | `ai_rag_chunk` | `(text, strategy, opts) -> List<Chunk>` | Chunk text |
| `0x0A31` | `ai_rag_index` | `(docs, opts) -> index_id` | Index documents |
| `0x0A32` | `ai_rag_query` | `(index, query, k) -> List<Doc>` | Query similar |
| `0x0A33` | `ai_rag_answer` | `(index, question, opts) -> str` | RAG answer |
| `0x0A34` | `ai_rag_rerank` | `(docs, query, method) -> List<Doc>` | Rerank (BM25/MMR) |

### 9.5 Agents (→ mathis-ai)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0A40` | `ai_agent_create` | `(config) -> agent_id` | Create agent |
| `0x0A41` | `ai_agent_run` | `(agent_id, task) -> result` | Run agent |
| `0x0A42` | `ai_agent_tool_add` | `(agent_id, tool) -> none` | Add tool |
| `0x0A43` | `ai_agent_memory_add` | `(agent_id, memory) -> none` | Add memory |

### 9.6 Kernel AI (introspection)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0A50` | `ai_explain_code` | `(code_ref) -> str` | Explain code |
| `0x0A51` | `ai_suggest_fix` | `(error) -> str` | Suggest fix |
| `0x0A52` | `ai_optimize` | `(code_ref) -> OptResult` | AI optimization |
| `0x0A53` | `ai_verify` | `(code_ref, spec) -> bool` | Verify spec |

### 9.7 Config

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0A60` | `ai_set_provider` | `(provider: str) -> none` | openai/anthropic/ollama |
| `0x0A61` | `ai_set_model` | `(model: str) -> none` | gpt-4/claude-3/llama3 |
| `0x0A62` | `ai_set_api_key` | `(key: str) -> none` | Set API key |
| `0x0A63` | `ai_token_count` | `(text, model) -> i64` | Count tokens |

---

## 10. Media Syscalls (0x0B00-0x0BFF)

### 10.1 Image (→ mathis-image)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0B00` | `image_load` | `(path) -> image_id` | Load image |
| `0x0B01` | `image_decode` | `(bytes) -> image_id` | Decode from bytes |
| `0x0B02` | `image_encode` | `(image_id, format) -> bytes` | Encode to bytes |
| `0x0B03` | `image_save` | `(image_id, path, format) -> none` | Save to file |
| `0x0B04` | `image_resize` | `(image_id, width, height) -> image_id` | Resize |
| `0x0B05` | `image_crop` | `(image_id, x, y, w, h) -> image_id` | Crop |
| `0x0B06` | `image_filter` | `(image_id, filter) -> image_id` | Apply filter |

### 10.2 RTMP (→ mathis-rtmp)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0B10` | `rtmp_server_new` | `(port) -> server_id` | Create RTMP server |
| `0x0B11` | `rtmp_server_start` | `(server) -> none` | Start |
| `0x0B12` | `rtmp_on_publish` | `(server, handler) -> none` | On publish event |

### 10.3 HLS (→ mathis-hls)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0B20` | `hls_create` | `(config) -> hls_id` | Create HLS stream |
| `0x0B21` | `hls_add_segment` | `(hls_id, segment) -> none` | Add segment |
| `0x0B22` | `hls_playlist` | `(hls_id) -> str` | Get M3U8 playlist |

### 10.4 Transcoding (→ mathis-ffmpeg, mathis-transcode)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0B30` | `transcode_video` | `(input, output, opts) -> none` | Transcode video |
| `0x0B31` | `transcode_audio` | `(input, output, opts) -> none` | Transcode audio |
| `0x0B32` | `transcode_hls` | `(input, output_dir, opts) -> none` | To HLS |

### 10.5 DRM (→ mathis-drm)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0B40` | `drm_encrypt` | `(content, key_id, key) -> bytes` | Encrypt content |
| `0x0B41` | `drm_pssh` | `(system, key_id) -> bytes` | Generate PSSH box |
| `0x0B42` | `drm_license_request` | `(system, challenge) -> response` | License request |

---

## 11. Time Syscalls (0x0C00-0x0CFF)

### 11.1 Time (→ mathis-time)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0C00` | `time_now` | `() -> i64` | Unix timestamp (ms) |
| `0x0C01` | `time_now_nano` | `() -> i64` | Unix timestamp (ns) |
| `0x0C02` | `time_sleep` | `(ms: i64) -> none` | Sleep (async-aware) |
| `0x0C03` | `time_format` | `(timestamp, format) -> str` | Format date |
| `0x0C04` | `time_parse` | `(str, format) -> i64` | Parse date |
| `0x0C05` | `time_timezone` | `() -> str` | Current timezone |

### 11.2 Cron (→ mathis-cron)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0C10` | `cron_parse` | `(expr: str) -> cron_id` | Parse cron expression |
| `0x0C11` | `cron_next` | `(cron_id) -> i64` | Next occurrence |
| `0x0C12` | `cron_schedule` | `(cron_id, handler) -> job_id` | Schedule job |
| `0x0C13` | `cron_cancel` | `(job_id) -> none` | Cancel job |

---

## 12. Queue Syscalls (0x0D00-0x0DFF)

### 12.1 Jobs (→ mathis-queue)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0D00` | `queue_create` | `(name, opts) -> queue_id` | Create queue |
| `0x0D01` | `queue_push` | `(queue_id, job) -> job_id` | Push job |
| `0x0D02` | `queue_pop` | `(queue_id) -> Option<Job>` | Pop job |
| `0x0D03` | `queue_ack` | `(job_id) -> none` | Acknowledge job |
| `0x0D04` | `queue_nack` | `(job_id) -> none` | Negative ack (retry) |
| `0x0D05` | `queue_schedule` | `(queue_id, job, delay) -> job_id` | Delayed job |

---

## 13. Search Syscalls (0x0E00-0x0EFF)

### 13.1 Full-Text Search (→ mathis-fts)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x0E00` | `fts_index_create` | `(name, config) -> index_id` | Create index |
| `0x0E01` | `fts_index_add` | `(index_id, doc_id, text) -> none` | Add document |
| `0x0E02` | `fts_search` | `(index_id, query, opts) -> List<Result>` | Search |
| `0x0E03` | `fts_search_fuzzy` | `(index_id, query, distance) -> List<Result>` | Fuzzy search |
| `0x0E04` | `fts_facets` | `(index_id, query, facet_fields) -> Facets` | Faceted search |

---

## 14. Email Syscalls (0x1000-0x10FF)

### 14.1 SMTP (→ mathis-email)

| ID | Nom | Signature | Description |
|----|-----|-----------|-------------|
| `0x1000` | `email_send` | `(to, subject, body, opts) -> none` | Send email |
| `0x1001` | `email_send_template` | `(to, template, data) -> none` | Send with template |
| `0x1002` | `email_send_bulk` | `(recipients, template, data) -> List<Result>` | Bulk send |

---

## 15. Implémentation Rust

### 15.1 Dispatcher Principal

```rust
// kernel/src/syscalls/mod.rs

pub mod io;
pub mod net;
pub mod db;
pub mod auth;
pub mod crypto;
pub mod ai;
pub mod media;
pub mod time;
pub mod queue;
pub mod search;
pub mod email;

use crate::vm::{Value, VmError};

pub fn dispatch(syscall_id: u16, args: Vec<Value>) -> Result<Value, VmError> {
    match syscall_id {
        // I/O
        0x0001..=0x00FF => io::handle(syscall_id, args),
        
        // Network
        0x0100..=0x01FF => net::handle(syscall_id, args),
        
        // Database
        0x0700..=0x07FF => db::handle(syscall_id, args),
        
        // Auth
        0x0800..=0x08FF => auth::handle(syscall_id, args),
        
        // Crypto
        0x0900..=0x09FF => crypto::handle(syscall_id, args),
        
        // AI ⭐
        0x0A00..=0x0AFF => ai::handle(syscall_id, args),
        
        // Media
        0x0B00..=0x0BFF => media::handle(syscall_id, args),
        
        // Time
        0x0C00..=0x0CFF => time::handle(syscall_id, args),
        
        // Queue
        0x0D00..=0x0DFF => queue::handle(syscall_id, args),
        
        // Search
        0x0E00..=0x0EFF => search::handle(syscall_id, args),
        
        // Email
        0x1000..=0x10FF => email::handle(syscall_id, args),
        
        _ => Err(VmError::UnknownSyscall(syscall_id)),
    }
}
```

### 15.2 Exemple: Wrapper pour mathis-ai

```rust
// kernel/src/syscalls/ai.rs

use mathis_ai::{AiClient, ChatMessage, Model};
use crate::vm::{Value, VmError};

pub fn handle(syscall_id: u16, args: Vec<Value>) -> Result<Value, VmError> {
    match syscall_id {
        // ai_chat
        0x0A00 => {
            let messages = args[0].as_list()?;
            let model = args[1].as_str().unwrap_or("gpt-4");
            
            let client = AiClient::new();
            let response = client.chat(
                messages.iter().map(|m| m.into()).collect(),
                Model::from_str(model),
            )?;
            
            Ok(Value::String(response.into()))
        }
        
        // ai_complete
        0x0A01 => {
            let prompt = args[0].as_str()?;
            let model = args.get(1).and_then(|v| v.as_str().ok()).unwrap_or("gpt-4");
            
            let client = AiClient::new();
            let response = client.complete(prompt, Model::from_str(model))?;
            
            Ok(Value::String(response.into()))
        }
        
        // ai_embed
        0x0A10 => {
            let text = args[0].as_str()?;
            
            let client = AiClient::new();
            let embedding = client.embed(text)?;
            
            Ok(Value::List(
                embedding.into_iter()
                    .map(Value::Float)
                    .collect()
            ))
        }
        
        // ai_rag_answer
        0x0A33 => {
            let index_id = args[0].as_int()?;
            let question = args[1].as_str()?;
            
            // Utilise mathis-rag!
            let rag = get_rag_index(index_id)?;
            let answer = rag.answer(question)?;
            
            Ok(Value::String(answer.into()))
        }
        
        _ => Err(VmError::UnknownSyscall(syscall_id)),
    }
}
```

---

*Syscalls Specification v1.0.0*
