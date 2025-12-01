#!/usr/bin/env python3
"""
JARVIS Serial Bridge - Connects MATHIS OS to AI via serial port
================================================================

This script:
1. Creates a PTY (pseudo-terminal) for QEMU serial
2. Listens for messages from MATHIS OS
3. Sends to Ollama/Claude
4. Returns response to MATHIS OS

Usage:
    python3 serial_bridge.py
    
Then start QEMU with:
    qemu-system-i386 -fda mathis.img -serial pty
"""

import os
import sys
import pty
import json
import select
import urllib.request
import urllib.error

OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "tinyllama"

def ask_ollama(prompt):
    """Query Ollama LLM"""
    try:
        system = "You are JARVIS, AI for MATHIS OS. Be VERY brief (1-2 sentences max)."
        data = json.dumps({
            "model": OLLAMA_MODEL,
            "prompt": f"{system}\n\nUser: {prompt}\n\nJARVIS:",
            "stream": False
        }).encode('utf-8')
        
        req = urllib.request.Request(
            OLLAMA_URL,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req, timeout=15) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result.get("response", "Error")[:70]  # Max 70 chars for kernel
            
    except Exception as e:
        return f"Error: {str(e)[:50]}"

def main():
    print("""
   ╔═══════════════════════════════════════════════════╗
   ║  JARVIS Serial Bridge - MATHIS OS AI Connector   ║
   ╚═══════════════════════════════════════════════════╝
    """)
    
    # Create a pseudo-terminal
    master, slave = pty.openpty()
    slave_name = os.ttyname(slave)
    
    print(f"✅ PTY created: {slave_name}")
    print(f"\n🚀 Start QEMU with:")
    print(f"   qemu-system-i386 -fda boot/mathis.img -serial {slave_name}")
    print(f"\n⏳ Waiting for MATHIS OS...\n")
    
    buffer = b""
    
    try:
        while True:
            # Wait for data
            ready, _, _ = select.select([master], [], [], 1.0)
            
            if master in ready:
                data = os.read(master, 256)
                buffer += data
                
                # Check for newline (command complete)
                if b'\n' in buffer:
                    line = buffer.decode('utf-8', errors='ignore').strip()
                    buffer = b""
                    
                    if line:
                        print(f"📥 MATHIS OS: {line}")
                        
                        # Get AI response
                        response = ask_ollama(line)
                        print(f"📤 JARVIS: {response}")
                        
                        # Send back to MATHIS OS
                        os.write(master, (response + "\n").encode('utf-8'))
                        
    except KeyboardInterrupt:
        print("\n👋 Bridge stopped")
    finally:
        os.close(master)
        os.close(slave)

if __name__ == "__main__":
    main()
