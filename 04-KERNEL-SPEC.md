# Mathis Kernel - Spécification

## 1. Vue d'Ensemble

Le **Mathis Kernel** est le cœur d'exécution de MATHIS OS. Il comprend:

- **VM Engine**: Machine virtuelle qui exécute le bytecode
- **Memory Manager**: Gestion de la mémoire et garbage collection
- **Scheduler**: Ordonnancement des tâches et async
- **Syscall Handler**: Interface avec le système

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MATHIS KERNEL                                     │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                          VM ENGINE                                     │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │ │
│  │  │   Decoder   │  │   Stack     │  │   Frames    │  │  Dispatch   │  │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                       MEMORY MANAGER                                   │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │ │
│  │  │  Allocator  │  │     GC      │  │   Heap      │  │   Pools     │  │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                         SCHEDULER                                      │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │ │
│  │  │   Tasks     │  │  Executor   │  │   Async     │  │  Channels   │  │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      SYSCALL HANDLER                                   │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │ │
│  │  │   I/O   │ │  Net    │ │ Process │ │  Time   │ │   AI    │  ...   │ │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. VM Engine

### 2.1 Architecture

La VM est une machine à pile (stack-based) avec:

- **Operand Stack**: Stack de valeurs pour les calculs
- **Call Stack**: Stack de frames d'appel
- **Constants Pool**: Constantes du module
- **Globals**: Variables globales

```rust
pub struct VmEngine {
    /// Stack des opérandes
    stack: Stack<Value>,
    
    /// Stack des frames d'appel
    frames: Vec<CallFrame>,
    
    /// Module en cours d'exécution
    module: Arc<Module>,
    
    /// Variables globales
    globals: HashMap<GlobalId, Value>,
    
    /// Gestionnaire mémoire
    memory: MemoryManager,
    
    /// Scheduler pour async
    scheduler: Scheduler,
    
    /// Interface syscalls
    syscalls: SyscallHandler,
    
    /// Runtime IA (optionnel)
    ai_runtime: Option<AiRuntime>,
    
    /// État d'exécution
    state: VmState,
    
    /// Compteur d'instructions (pour profiling)
    instruction_count: u64,
}

pub struct CallFrame {
    /// Fonction en cours
    function: FunctionRef,
    
    /// Program counter (offset dans le bytecode)
    pc: usize,
    
    /// Base de la stack pour ce frame
    stack_base: usize,
    
    /// Variables locales
    locals: Vec<Value>,
    
    /// Upvalues (pour closures)
    upvalues: Vec<UpvalueRef>,
    
    /// Exception handler actif
    exception_handler: Option<ExceptionHandler>,
}

pub enum VmState {
    Running,
    Paused,      // Pour AI_BREAKPOINT
    Yielded,     // Pour async/generators
    Completed,
    Error(VmError),
}
```

### 2.2 Boucle d'Exécution

```rust
impl VmEngine {
    pub fn run(&mut self) -> Result<Value, VmError> {
        loop {
            // Vérifier l'état
            match self.state {
                VmState::Completed => return Ok(self.stack.pop()?),
                VmState::Error(e) => return Err(e),
                VmState::Paused => self.handle_pause()?,
                VmState::Yielded => self.handle_yield()?,
                VmState::Running => {}
            }
            
            // Fetch
            let opcode = self.fetch_opcode()?;
            
            // Decode & Execute
            self.execute_opcode(opcode)?;
            
            // Incrémenter le compteur
            self.instruction_count += 1;
            
            // GC check périodique
            if self.instruction_count % GC_CHECK_INTERVAL == 0 {
                self.memory.maybe_collect();
            }
        }
    }
    
    fn fetch_opcode(&mut self) -> Result<OpCode, VmError> {
        let frame = self.current_frame_mut();
        let byte = frame.function.code[frame.pc];
        frame.pc += 1;
        OpCode::try_from(byte)
    }
    
    fn execute_opcode(&mut self, opcode: OpCode) -> Result<(), VmError> {
        match opcode {
            // Constants
            OpCode::Const => self.op_const()?,
            OpCode::ConstNone => self.stack.push(Value::None),
            OpCode::ConstTrue => self.stack.push(Value::Bool(true)),
            OpCode::ConstFalse => self.stack.push(Value::Bool(false)),
            OpCode::ConstI64 => self.op_const_i64()?,
            OpCode::ConstF64 => self.op_const_f64()?,
            
            // Variables
            OpCode::GetLocal => self.op_get_local()?,
            OpCode::SetLocal => self.op_set_local()?,
            OpCode::GetGlobal => self.op_get_global()?,
            OpCode::SetGlobal => self.op_set_global()?,
            
            // Arithmetic
            OpCode::Add => self.op_binary(BinaryOp::Add)?,
            OpCode::Sub => self.op_binary(BinaryOp::Sub)?,
            OpCode::Mul => self.op_binary(BinaryOp::Mul)?,
            OpCode::Div => self.op_binary(BinaryOp::Div)?,
            
            // Control flow
            OpCode::Jump => self.op_jump()?,
            OpCode::JumpIfTrue => self.op_jump_if(true)?,
            OpCode::JumpIfFalse => self.op_jump_if(false)?,
            OpCode::Call => self.op_call()?,
            OpCode::Ret => self.op_return()?,
            
            // AI Instructions
            OpCode::AiBreakpoint => self.op_ai_breakpoint()?,
            OpCode::AiCall => self.op_ai_call()?,
            OpCode::AiDecide => self.op_ai_decide()?,
            OpCode::AiExplainStart => self.op_ai_explain_start()?,
            OpCode::AiExplainEnd => self.op_ai_explain_end()?,
            
            // System
            OpCode::Syscall => self.op_syscall()?,
            
            // ... autres opcodes
            
            _ => return Err(VmError::UnknownOpcode(opcode as u8)),
        }
        Ok(())
    }
}
```

### 2.3 Types de Valeurs

```rust
pub enum Value {
    None,
    Bool(bool),
    Int(i64),
    Float(f64),
    Char(char),
    String(GcRef<MathisString>),
    List(GcRef<MathisList>),
    Map(GcRef<MathisMap>),
    Set(GcRef<MathisSet>),
    Tuple(GcRef<MathisTuple>),
    Struct(GcRef<MathisStruct>),
    Enum(GcRef<MathisEnum>),
    Function(GcRef<MathisFunction>),
    Closure(GcRef<MathisClosure>),
    NativeFunction(NativeFunctionRef),
    Future(GcRef<MathisFuture>),
    Channel(GcRef<MathisChannel>),
    Bytes(GcRef<MathisBytes>),
    Error(GcRef<MathisError>),
    
    // Types bas niveau (kernel mode)
    RawPtr(usize),
    TypeId(u32),
}

impl Value {
    pub fn type_name(&self) -> &'static str {
        match self {
            Value::None => "none",
            Value::Bool(_) => "bool",
            Value::Int(_) => "int",
            Value::Float(_) => "float",
            Value::Char(_) => "char",
            Value::String(_) => "str",
            Value::List(_) => "list",
            Value::Map(_) => "map",
            // ...
        }
    }
    
    pub fn is_truthy(&self) -> bool {
        match self {
            Value::None => false,
            Value::Bool(b) => *b,
            Value::Int(i) => *i != 0,
            Value::Float(f) => *f != 0.0,
            Value::String(s) => !s.is_empty(),
            Value::List(l) => !l.is_empty(),
            _ => true,
        }
    }
}
```

---

## 3. Memory Manager

### 3.1 Architecture

```rust
pub struct MemoryManager {
    /// Heap pour les objets GC
    heap: GcHeap,
    
    /// Allocateur pour la mémoire raw
    allocator: Allocator,
    
    /// Pools pour les petits objets
    small_object_pools: SmallObjectPools,
    
    /// Statistiques
    stats: MemoryStats,
    
    /// Configuration GC
    gc_config: GcConfig,
}

pub struct GcHeap {
    /// Objets vivants
    objects: Vec<GcObject>,
    
    /// Racines GC (stack, globals)
    roots: Vec<GcRef<dyn GcTraceable>>,
    
    /// Bytes alloués
    bytes_allocated: usize,
    
    /// Seuil pour déclencher GC
    gc_threshold: usize,
}

pub struct GcConfig {
    /// Seuil initial (bytes)
    initial_threshold: usize,
    
    /// Facteur de croissance du seuil
    growth_factor: f64,
    
    /// Minimum entre deux GC (instructions)
    min_interval: u64,
    
    /// Type de GC
    gc_type: GcType,
}

pub enum GcType {
    /// Mark and sweep simple
    MarkSweep,
    
    /// Générationnel (young/old)
    Generational,
    
    /// Incrémental (pour faible latence)
    Incremental,
    
    /// Concurrent (multi-thread)
    Concurrent,
}
```

### 3.2 Garbage Collector

```rust
impl GcHeap {
    pub fn collect(&mut self) {
        // Phase 1: Mark
        self.mark_roots();
        
        // Phase 2: Sweep
        self.sweep();
        
        // Mettre à jour les stats
        self.update_stats();
        
        // Ajuster le seuil
        self.adjust_threshold();
    }
    
    fn mark_roots(&mut self) {
        for root in &self.roots {
            self.mark_object(root);
        }
    }
    
    fn mark_object(&mut self, obj: &GcRef<dyn GcTraceable>) {
        if obj.is_marked() {
            return;
        }
        
        obj.set_marked(true);
        
        // Marquer les références
        for child in obj.trace() {
            self.mark_object(&child);
        }
    }
    
    fn sweep(&mut self) {
        self.objects.retain(|obj| {
            if obj.is_marked() {
                obj.set_marked(false);
                true
            } else {
                self.bytes_allocated -= obj.size();
                obj.finalize();
                false
            }
        });
    }
}

/// Trait pour les objets traçables par le GC
pub trait GcTraceable {
    /// Retourne les références vers d'autres objets GC
    fn trace(&self) -> Vec<GcRef<dyn GcTraceable>>;
    
    /// Taille en bytes
    fn size(&self) -> usize;
    
    /// Appelé avant destruction
    fn finalize(&self) {}
}
```

### 3.3 Allocateur Raw (Kernel Mode)

```rust
pub struct Allocator {
    /// Blocs libres par taille
    free_lists: [FreeList; NUM_SIZE_CLASSES],
    
    /// Arène pour les grandes allocations
    large_arena: Arena,
    
    /// Statistiques
    stats: AllocStats,
}

impl Allocator {
    pub fn alloc(&mut self, size: usize) -> Result<*mut u8, AllocError> {
        let size = align_up(size, 8);
        
        if size <= MAX_SMALL_SIZE {
            self.alloc_small(size)
        } else {
            self.alloc_large(size)
        }
    }
    
    pub fn free(&mut self, ptr: *mut u8, size: usize) -> Result<(), AllocError> {
        if size <= MAX_SMALL_SIZE {
            self.free_small(ptr, size)
        } else {
            self.free_large(ptr, size)
        }
    }
    
    pub fn realloc(
        &mut self, 
        ptr: *mut u8, 
        old_size: usize, 
        new_size: usize
    ) -> Result<*mut u8, AllocError> {
        let new_ptr = self.alloc(new_size)?;
        unsafe {
            std::ptr::copy_nonoverlapping(
                ptr, 
                new_ptr, 
                old_size.min(new_size)
            );
        }
        self.free(ptr, old_size)?;
        Ok(new_ptr)
    }
}
```

---

## 4. Scheduler

### 4.1 Architecture

```rust
pub struct Scheduler {
    /// File de tâches prêtes
    ready_queue: VecDeque<Task>,
    
    /// Tâches en attente (I/O, timers)
    waiting: HashMap<TaskId, WaitReason>,
    
    /// Tâche courante
    current: Option<Task>,
    
    /// Exécuteur async
    executor: AsyncExecutor,
    
    /// Channels
    channels: HashMap<ChannelId, Channel>,
    
    /// Timers
    timers: BinaryHeap<Timer>,
    
    /// ID counter
    next_task_id: TaskId,
}

pub struct Task {
    id: TaskId,
    state: TaskState,
    priority: Priority,
    
    /// État de la VM pour cette tâche
    vm_state: VmState,
    
    /// Stack sauvegardée
    saved_stack: Vec<Value>,
    
    /// Frames sauvegardés
    saved_frames: Vec<CallFrame>,
    
    /// Résultat (si terminé)
    result: Option<Result<Value, VmError>>,
}

pub enum TaskState {
    Ready,
    Running,
    Waiting(WaitReason),
    Completed,
    Failed,
}

pub enum WaitReason {
    Io(IoHandle),
    Timer(Instant),
    Channel(ChannelId),
    Future(FutureId),
    Task(TaskId),
}
```

### 4.2 Async Executor

```rust
pub struct AsyncExecutor {
    /// Tâches async (coroutines)
    coroutines: HashMap<CoroutineId, Coroutine>,
    
    /// Waker pour réveiller les tâches
    wakers: HashMap<CoroutineId, Waker>,
}

impl AsyncExecutor {
    pub fn spawn(&mut self, task: Task) -> TaskHandle {
        let id = self.next_id();
        self.coroutines.insert(id, Coroutine::new(task));
        TaskHandle(id)
    }
    
    pub fn poll(&mut self, id: CoroutineId) -> Poll<Value> {
        let coroutine = self.coroutines.get_mut(&id)?;
        
        match coroutine.poll() {
            Poll::Ready(value) => {
                self.coroutines.remove(&id);
                Poll::Ready(value)
            }
            Poll::Pending => Poll::Pending,
        }
    }
    
    pub fn run_until_complete(&mut self) -> Vec<Result<Value, VmError>> {
        let mut results = Vec::new();
        
        while !self.coroutines.is_empty() {
            // Collecter les tâches prêtes
            let ready: Vec<_> = self.coroutines.keys()
                .filter(|id| self.is_ready(**id))
                .copied()
                .collect();
            
            for id in ready {
                if let Poll::Ready(value) = self.poll(id) {
                    results.push(Ok(value));
                }
            }
            
            // Attendre des événements si rien n'est prêt
            if self.all_pending() {
                self.wait_for_events();
            }
        }
        
        results
    }
}
```

### 4.3 Channels

```rust
pub struct Channel {
    id: ChannelId,
    
    /// Buffer des messages
    buffer: VecDeque<Value>,
    
    /// Capacité (0 = unbuffered)
    capacity: usize,
    
    /// Tâches en attente d'envoi
    send_waiters: VecDeque<TaskId>,
    
    /// Tâches en attente de réception
    recv_waiters: VecDeque<TaskId>,
    
    /// Channel fermé?
    closed: bool,
}

impl Channel {
    pub fn send(&mut self, value: Value, sender: TaskId) -> SendResult {
        if self.closed {
            return SendResult::Closed;
        }
        
        if self.buffer.len() < self.capacity || self.capacity == 0 {
            // Si quelqu'un attend, envoyer directement
            if let Some(waiter) = self.recv_waiters.pop_front() {
                return SendResult::DirectSend(waiter, value);
            }
            
            // Sinon buffer
            if self.buffer.len() < self.capacity {
                self.buffer.push_back(value);
                return SendResult::Buffered;
            }
        }
        
        // Bloquer
        self.send_waiters.push_back(sender);
        SendResult::Blocked(value)
    }
    
    pub fn recv(&mut self, receiver: TaskId) -> RecvResult {
        if let Some(value) = self.buffer.pop_front() {
            // Débloquer un sender si présent
            if let Some(sender) = self.send_waiters.pop_front() {
                return RecvResult::ValueWithUnblock(value, sender);
            }
            return RecvResult::Value(value);
        }
        
        if self.closed {
            return RecvResult::Closed;
        }
        
        // Bloquer
        self.recv_waiters.push_back(receiver);
        RecvResult::Blocked
    }
}
```

---

## 5. Syscall Handler

### 5.1 Interface

```rust
pub struct SyscallHandler {
    /// Handlers par catégorie
    io_handler: IoHandler,
    net_handler: NetHandler,
    process_handler: ProcessHandler,
    time_handler: TimeHandler,
    crypto_handler: CryptoHandler,
    ai_handler: AiHandler,
    
    /// Permissions
    permissions: Permissions,
}

impl SyscallHandler {
    pub fn handle(
        &mut self,
        syscall_id: u16,
        args: Vec<Value>,
        vm: &mut VmEngine,
    ) -> Result<Value, SyscallError> {
        // Vérifier les permissions
        self.check_permission(syscall_id)?;
        
        // Dispatcher
        match syscall_id {
            // I/O (0x0001 - 0x00FF)
            0x0001 => self.io_handler.open(args),
            0x0002 => self.io_handler.read(args),
            0x0003 => self.io_handler.write(args),
            0x0004 => self.io_handler.close(args),
            
            // Network (0x0100 - 0x01FF)
            0x0100 => self.net_handler.socket(args),
            0x0101 => self.net_handler.connect(args),
            0x0102 => self.net_handler.bind(args),
            
            // Process (0x0300 - 0x03FF)
            0x0300 => self.process_handler.spawn(args, vm),
            0x0301 => self.process_handler.kill(args),
            
            // Time (0x0C00 - 0x0CFF)
            0x0C00 => self.time_handler.now(),
            0x0C01 => self.time_handler.sleep(args, vm),
            
            // Crypto (0x0D00 - 0x0DFF)
            0x0D00 => self.crypto_handler.hash(args),
            0x0D01 => self.crypto_handler.sign(args),
            
            // AI (0x0A00 - 0x0AFF)
            0x0A00 => self.ai_handler.complete(args),
            0x0A01 => self.ai_handler.embed(args),
            0x0A02 => self.ai_handler.search(args),
            
            _ => Err(SyscallError::UnknownSyscall(syscall_id)),
        }
    }
}
```

### 5.2 I/O Handler

```rust
pub struct IoHandler {
    /// File descriptors ouverts
    open_files: HashMap<Fd, OpenFile>,
    
    /// Prochain FD
    next_fd: Fd,
}

impl IoHandler {
    pub fn open(&mut self, args: Vec<Value>) -> Result<Value, SyscallError> {
        let path = args[0].as_str()?;
        let flags = args[1].as_int()? as u32;
        
        let file = std::fs::OpenOptions::new()
            .read(flags & O_RDONLY != 0)
            .write(flags & O_WRONLY != 0)
            .create(flags & O_CREAT != 0)
            .truncate(flags & O_TRUNC != 0)
            .open(path)?;
        
        let fd = self.next_fd;
        self.next_fd += 1;
        self.open_files.insert(fd, OpenFile::File(file));
        
        Ok(Value::Int(fd as i64))
    }
    
    pub fn read(&mut self, args: Vec<Value>) -> Result<Value, SyscallError> {
        let fd = args[0].as_int()? as Fd;
        let len = args[1].as_int()? as usize;
        
        let file = self.open_files.get_mut(&fd)
            .ok_or(SyscallError::InvalidFd)?;
        
        let mut buf = vec![0u8; len];
        let n = file.read(&mut buf)?;
        buf.truncate(n);
        
        Ok(Value::Bytes(GcRef::new(MathisBytes::from(buf))))
    }
    
    pub fn write(&mut self, args: Vec<Value>) -> Result<Value, SyscallError> {
        let fd = args[0].as_int()? as Fd;
        let data = args[1].as_bytes()?;
        
        let file = self.open_files.get_mut(&fd)
            .ok_or(SyscallError::InvalidFd)?;
        
        let n = file.write(&data)?;
        
        Ok(Value::Int(n as i64))
    }
}
```

---

## 6. Configuration et Démarrage

### 6.1 Configuration

```rust
pub struct KernelConfig {
    /// Taille max de la stack
    pub max_stack_size: usize,
    
    /// Taille max du heap
    pub max_heap_size: usize,
    
    /// Configuration GC
    pub gc_config: GcConfig,
    
    /// Nombre max de tâches
    pub max_tasks: usize,
    
    /// Timeout par défaut (ms)
    pub default_timeout: u64,
    
    /// Activer le runtime IA
    pub enable_ai_runtime: bool,
    
    /// Mode debug
    pub debug_mode: bool,
    
    /// Profiling
    pub enable_profiling: bool,
    
    /// Permissions
    pub permissions: Permissions,
}

impl Default for KernelConfig {
    fn default() -> Self {
        Self {
            max_stack_size: 1024 * 1024,      // 1MB
            max_heap_size: 256 * 1024 * 1024, // 256MB
            gc_config: GcConfig::default(),
            max_tasks: 10000,
            default_timeout: 30000,           // 30s
            enable_ai_runtime: true,
            debug_mode: false,
            enable_profiling: false,
            permissions: Permissions::default(),
        }
    }
}
```

### 6.2 Démarrage du Kernel

```rust
pub struct MathisKernel {
    vm: VmEngine,
    config: KernelConfig,
}

impl MathisKernel {
    pub fn new(config: KernelConfig) -> Self {
        Self {
            vm: VmEngine::new(&config),
            config,
        }
    }
    
    pub fn load_module(&mut self, bytecode: &[u8]) -> Result<ModuleId, LoadError> {
        // Valider le bytecode
        let module = Module::from_bytecode(bytecode)?;
        
        // Vérifier la signature si requise
        if self.config.require_signed && !module.is_signed() {
            return Err(LoadError::UnsignedModule);
        }
        
        // Résoudre les imports
        self.resolve_imports(&module)?;
        
        // Charger dans la VM
        self.vm.load_module(module)
    }
    
    pub fn run(&mut self, entry_point: &str) -> Result<Value, RuntimeError> {
        // Trouver la fonction d'entrée
        let func = self.vm.find_function(entry_point)?;
        
        // Exécuter
        self.vm.call(func, vec![])
    }
    
    pub fn run_async(&mut self, entry_point: &str) -> TaskHandle {
        let func = self.vm.find_function(entry_point).unwrap();
        self.vm.scheduler.spawn_task(func, vec![])
    }
}
```

---

## 7. API pour l'IA

### 7.1 Interface d'Introspection

```rust
/// API pour le runtime IA
pub trait AiIntrospection {
    /// Obtenir l'état actuel de la VM
    fn get_vm_state(&self) -> VmSnapshot;
    
    /// Obtenir la stack actuelle
    fn get_stack(&self) -> Vec<Value>;
    
    /// Obtenir les variables locales
    fn get_locals(&self) -> HashMap<String, Value>;
    
    /// Obtenir le code autour du PC actuel
    fn get_surrounding_code(&self, context: usize) -> CodeContext;
    
    /// Obtenir les metadata du bloc courant
    fn get_current_metadata(&self) -> Option<AiMetadata>;
    
    /// Obtenir la pile d'appels
    fn get_call_stack(&self) -> Vec<FrameInfo>;
    
    /// Expliquer le code courant
    fn explain_current(&self) -> String;
    
    /// Suggérer des optimisations
    fn suggest_optimizations(&self) -> Vec<Optimization>;
}

pub struct VmSnapshot {
    pub pc: usize,
    pub stack_size: usize,
    pub frame_depth: usize,
    pub instruction_count: u64,
    pub memory_used: usize,
    pub current_function: String,
    pub current_intent: Option<String>,
}

pub struct CodeContext {
    pub before: Vec<Instruction>,
    pub current: Instruction,
    pub after: Vec<Instruction>,
    pub source_location: Option<SourceLocation>,
}
```

### 7.2 Interface de Modification

```rust
/// API pour modifier le bytecode
pub trait AiModification {
    /// Remplacer un bloc de code
    fn replace_block(
        &mut self, 
        start: usize, 
        end: usize, 
        new_code: Vec<Instruction>
    ) -> Result<(), ModificationError>;
    
    /// Insérer du code
    fn insert_code(
        &mut self,
        position: usize,
        code: Vec<Instruction>
    ) -> Result<(), ModificationError>;
    
    /// Supprimer du code
    fn remove_code(
        &mut self,
        start: usize,
        end: usize
    ) -> Result<(), ModificationError>;
    
    /// Optimiser une fonction
    fn optimize_function(
        &mut self,
        func_id: FunctionId,
        strategy: OptimizationStrategy
    ) -> Result<OptimizationResult, ModificationError>;
    
    /// Vérifier la validité après modification
    fn verify(&self) -> Result<(), VerificationError>;
}
```

---

## 8. Sécurité

### 8.1 Sandboxing

```rust
pub struct Sandbox {
    /// Syscalls autorisés
    allowed_syscalls: HashSet<u16>,
    
    /// Chemins accessibles
    allowed_paths: Vec<PathPattern>,
    
    /// Domaines réseau autorisés
    allowed_domains: Vec<DomainPattern>,
    
    /// Mémoire max
    max_memory: usize,
    
    /// CPU max (instructions)
    max_instructions: u64,
    
    /// Temps max (ms)
    max_time: u64,
}

impl Sandbox {
    pub fn check_syscall(&self, syscall_id: u16) -> Result<(), SecurityError> {
        if self.allowed_syscalls.contains(&syscall_id) {
            Ok(())
        } else {
            Err(SecurityError::SyscallNotAllowed(syscall_id))
        }
    }
    
    pub fn check_path(&self, path: &Path) -> Result<(), SecurityError> {
        for pattern in &self.allowed_paths {
            if pattern.matches(path) {
                return Ok(());
            }
        }
        Err(SecurityError::PathNotAllowed(path.to_owned()))
    }
}
```

### 8.2 Capabilities

```rust
pub struct Capabilities {
    /// Peut accéder au filesystem
    pub fs_access: bool,
    
    /// Peut accéder au réseau
    pub net_access: bool,
    
    /// Peut spawner des processus
    pub process_spawn: bool,
    
    /// Peut utiliser le runtime IA
    pub ai_access: bool,
    
    /// Peut modifier le bytecode
    pub bytecode_modify: bool,
    
    /// Accès kernel mode
    pub kernel_mode: bool,
}
```

---

*Kernel Specification v1.0.0*
