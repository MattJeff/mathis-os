#!/usr/bin/env python3
"""
JARVIS - MATHIS OS AI Assistant
================================

Uses Claude CLI to provide AI capabilities to MATHIS OS.
Can generate code, improve the kernel, and follow a roadmap autonomously.

Usage:
    python3 jarvis.py              # Interactive mode
    python3 jarvis.py --auto       # Autonomous mode (follows roadmap)
    python3 jarvis.py --ask "..."  # Single query

"""

import os
import sys
import subprocess
import json
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime

# Paths
MATHIS_OS = Path(__file__).parent.parent
BOOT_DIR = MATHIS_OS / "boot"
BOOTSTRAP_DIR = MATHIS_OS / "bootstrap"

# Claude CLI
CLAUDE_CLI = "/opt/homebrew/bin/claude"

# Ollama (local LLM backup)
OLLAMA_MODEL = "tinyllama"
OLLAMA_URL = "http://localhost:11434/api/generate"

class Jarvis:
    def __init__(self):
        self.history = []
        self.roadmap = [
            {"task": "Add 'jarvis' command to kernel", "status": "pending"},
            {"task": "Implement basic filesystem", "status": "pending"},
            {"task": "Add file read/write commands", "status": "pending"},
            {"task": "Implement process scheduler", "status": "pending"},
            {"task": "Add networking (TCP/IP)", "status": "pending"},
            {"task": "Create GUI framework", "status": "pending"},
            {"task": "Train MathisAI model", "status": "pending"},
        ]
        self.sandbox = []
        
    def banner(self):
        print("""
   ██╗ █████╗ ██████╗ ██╗   ██╗██╗███████╗
   ██║██╔══██╗██╔══██╗██║   ██║██║██╔════╝
   ██║███████║██████╔╝██║   ██║██║███████╗
   ██║██╔══██║██╔══██╗╚██╗ ██╔╝██║╚════██║
██╗╚█████╔╝██║  ██║██║  ██║ ╚████╔╝ ██║███████║
╚═╝ ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚══════╝
                                               
   MATHIS OS AI Assistant - Powered by Claude
        """)
    
    def ask_claude(self, prompt, context=""):
        """Ask Claude CLI a question"""
        full_prompt = f"""You are JARVIS, the AI assistant for MATHIS OS.
MATHIS OS is a custom operating system written in the Mathis programming language.

Context about MATHIS:
- Mathis is a stack-based assembly language with AI annotations
- Files use .masm extension
- Compiles to .mbc bytecode
- Kernel runs on x86 bare metal
- Current features: shell, keyboard, Mini VM

{context}

User request: {prompt}

Respond concisely and provide code when asked."""

        try:
            result = subprocess.run(
                [CLAUDE_CLI, "-p", full_prompt],
                capture_output=True,
                text=True,
                timeout=60
            )
            output = result.stdout.strip()
            
            # Check for rate limit
            if "limit reached" in output.lower() or "resets" in output.lower():
                print("⚠️  Claude CLI limit reached, using Ollama (local LLM)...")
                return self.ask_ollama(prompt)
            
            return output
        except subprocess.TimeoutExpired:
            return "Error: Claude CLI timeout"
        except Exception as e:
            return f"Error: {e}"
    
    def ask_ollama(self, prompt):
        """Query local Ollama LLM"""
        try:
            system_prompt = """You are JARVIS, an AI assistant for MATHIS OS.
MATHIS OS is a custom operating system with its own programming language called Mathis.
Mathis is a stack-based assembly language with AI annotations.
Be concise and helpful. Generate code when asked."""

            data = json.dumps({
                "model": OLLAMA_MODEL,
                "prompt": f"{system_prompt}\n\nUser: {prompt}\n\nJARVIS:",
                "stream": False
            }).encode('utf-8')
            
            req = urllib.request.Request(
                OLLAMA_URL,
                data=data,
                headers={'Content-Type': 'application/json'}
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode('utf-8'))
                return result.get("response", "No response")
                
        except urllib.error.URLError:
            print("⚠️  Ollama not running. Start with: ollama serve")
            return self.mock_response(prompt)
        except Exception as e:
            return f"Ollama error: {e}"
    
    def mock_response(self, prompt):
        """Fallback responses when all AI unavailable"""
        prompt_lower = prompt.lower()
        
        if "filesystem" in prompt_lower:
            return """Pour le filesystem, voici le code:

```masm
.module "filesystem"
.version "1.0.0"

.func fs_init
    .arity 0
    .locals 2
    .ai_block "fs_init"
    .ai_intent "Initialize filesystem"
    
    ; Reserve memory for file table
    CONST_I64 0x30000
    SET_LOCAL 0
    
    CONST_I64 0
    RET
.end
```"""
        elif "jarvis" in prompt_lower or "command" in prompt_lower:
            return """Pour ajouter la commande jarvis au kernel:

1. Modifier command_handler dans kernel.asm
2. Ajouter le pattern matching pour "jarvis"
3. Implémenter la communication série
"""
        elif "what is" in prompt_lower or "mathis" in prompt_lower:
            return """MATHIS OS est un système d'exploitation créé par Mathis Higuinen.
Il utilise le langage Mathis (stack-based assembly avec annotations IA).
C'est 100% autonome - pas de Rust, pas de dépendances externes."""
        else:
            return f"[Mode mock] Je comprends: {prompt[:100]}..."
    
    def generate_masm_code(self, description):
        """Generate Mathis assembly code"""
        prompt = f"""Generate Mathis assembly code (.masm) for: {description}

Follow this exact format:
```masm
.module "module_name"
.version "1.0.0"

.constants:
    0: str "constant_value"

.func function_name
    .arity 0
    .locals 2
    .ai_block "block_name"
    .ai_intent "what this does"
    
    ; Your code here
    CONST_I64 0
    RET
.end
```

Output ONLY the code, no explanations."""

        response = self.ask_claude(prompt)
        
        # Extract code block if present
        if "```" in response:
            lines = response.split("```")
            for i, block in enumerate(lines):
                if block.startswith("masm") or block.startswith("\nmasm"):
                    return block.replace("masm\n", "").replace("masm", "").strip()
        
        return response
    
    def save_to_file(self, filename, content):
        """Save generated code to file"""
        path = MATHIS_OS / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        print(f"💾 Saved: {path}")
        return path
    
    def compile_masm(self, masm_file):
        """Compile .masm to .mbc using bootstrap compiler"""
        masm_path = Path(masm_file)
        mbc_path = masm_path.with_suffix(".mbc")
        
        compiler = BOOTSTRAP_DIR / "masm"
        if not compiler.exists():
            print(f"❌ Compiler not found: {compiler}")
            return None
        
        result = subprocess.run(
            [str(compiler), "assemble", str(masm_path), "-o", str(mbc_path)],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            print(f"✅ Compiled: {mbc_path}")
            return mbc_path
        else:
            print(f"❌ Compile error: {result.stderr}")
            return None
    
    def show_roadmap(self):
        """Display current roadmap"""
        print("\n📋 JARVIS ROADMAP\n")
        for i, item in enumerate(self.roadmap):
            status = "✅" if item["status"] == "done" else "⏳" if item["status"] == "in_progress" else "○"
            print(f"  {status} {i+1}. {item['task']}")
        print()
    
    def work_on_task(self, task_index=None):
        """Work on a roadmap task"""
        if task_index is None:
            # Find first pending task
            for i, item in enumerate(self.roadmap):
                if item["status"] == "pending":
                    task_index = i
                    break
        
        if task_index is None or task_index >= len(self.roadmap):
            print("🎉 All tasks complete!")
            return
        
        task = self.roadmap[task_index]
        print(f"\n🔨 Working on: {task['task']}")
        task["status"] = "in_progress"
        
        # Ask Claude to implement
        response = self.ask_claude(
            f"Implement this for MATHIS OS: {task['task']}. "
            f"Provide the code and explain what to do."
        )
        
        print(f"\n🤖 JARVIS:\n{response[:1000]}...")
        
        task["status"] = "done"
        print(f"\n✅ Task marked complete!")
    
    def interactive_mode(self):
        """Interactive command loop"""
        self.banner()
        print("Commands: ask, code, roadmap, next, build, improve, status, quit\n")
        
        while True:
            try:
                cmd = input("JARVIS> ").strip()
                if not cmd:
                    continue
                
                parts = cmd.split(" ", 1)
                action = parts[0].lower()
                args = parts[1] if len(parts) > 1 else ""
                
                if action in ["quit", "exit", "q"]:
                    print("👋 Goodbye!")
                    break
                elif action == "ask":
                    if args:
                        response = self.ask_claude(args)
                        print(f"\n🤖 {response}\n")
                    else:
                        print("Usage: ask <question>")
                elif action == "code":
                    if args:
                        code = self.generate_masm_code(args)
                        print(f"\n```masm\n{code}\n```\n")
                        
                        save = input("Save to file? (filename or n): ").strip()
                        if save and save != "n":
                            self.save_to_file(save, code)
                    else:
                        print("Usage: code <description>")
                elif action == "roadmap":
                    self.show_roadmap()
                elif action == "next":
                    self.work_on_task()
                elif action == "build":
                    if args:
                        self.build_feature(args)
                    else:
                        print("Usage: build <feature>")
                elif action == "improve":
                    self.improve_code(args if args else None)
                elif action == "status":
                    self.show_status()
                else:
                    # Treat as natural language query
                    response = self.ask_claude(cmd)
                    print(f"\n🤖 {response}\n")
                    
            except KeyboardInterrupt:
                print("\n👋 Goodbye!")
                break
            except Exception as e:
                print(f"Error: {e}")
    
    def build_feature(self, feature):
        """Build a complete feature"""
        print(f"\n🏗️ Building: {feature}\n")
        
        # Generate code
        print("1️⃣ Generating code...")
        code = self.generate_masm_code(feature)
        print(f"   Generated {len(code)} chars")
        
        # Save
        filename = f"programs/{feature.replace(' ', '_').lower()}.masm"
        path = self.save_to_file(filename, code)
        
        # Compile
        print("2️⃣ Compiling...")
        mbc = self.compile_masm(path)
        
        if mbc:
            print(f"\n✅ Feature '{feature}' built successfully!")
            print(f"   Source: {path}")
            print(f"   Binary: {mbc}")
        
    def improve_code(self, file=None):
        """Ask Claude to improve existing code"""
        if file:
            path = MATHIS_OS / file
            if path.exists():
                code = path.read_text()
                prompt = f"""Review and improve this Mathis code:

```masm
{code}
```

Suggest specific improvements for:
1. Performance
2. Readability  
3. Bug fixes
4. New features"""
                response = self.ask_claude(prompt)
                print(f"\n🔍 Code Review:\n{response}\n")
            else:
                print(f"File not found: {file}")
        else:
            print("Usage: improve <file>")
    
    def show_status(self):
        """Show current status"""
        done = sum(1 for t in self.roadmap if t["status"] == "done")
        total = len(self.roadmap)
        
        print(f"\n📊 JARVIS STATUS")
        print(f"   Roadmap: {done}/{total} tasks complete")
        print(f"   Sandbox: {len(self.sandbox)} items")
        print(f"   MATHIS OS: {MATHIS_OS}")
        print()


def main():
    jarvis = Jarvis()
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "--auto":
            jarvis.banner()
            print("🤖 Autonomous mode - working on roadmap...\n")
            while any(t["status"] == "pending" for t in jarvis.roadmap):
                jarvis.work_on_task()
        elif sys.argv[1] == "--ask" and len(sys.argv) > 2:
            response = jarvis.ask_claude(" ".join(sys.argv[2:]))
            print(response)
        else:
            jarvis.interactive_mode()
    else:
        jarvis.interactive_mode()


if __name__ == "__main__":
    main()
