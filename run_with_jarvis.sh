#!/bin/bash
# Run MATHIS OS with JARVIS AI
# =============================

echo "🤖 Starting JARVIS AI Bridge + MATHIS OS..."
echo ""

# Kill any existing QEMU
pkill -f qemu-system 2>/dev/null

# Create a named pipe for serial
SERIAL_PIPE="/tmp/mathis_serial"
rm -f $SERIAL_PIPE
mkfifo $SERIAL_PIPE

# Start the Python bridge in background
echo "1️⃣ Starting JARVIS bridge..."
python3 jarvis/serial_bridge.py &
BRIDGE_PID=$!
sleep 2

# Get the PTY from bridge output (we'll use a simpler approach)
echo "2️⃣ Starting QEMU with serial output..."
cd boot

# Run QEMU with serial to stdio (simplest approach)
qemu-system-i386 -fda mathis.img -boot a -m 32M -serial stdio &
QEMU_PID=$!

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  MATHIS OS running with JARVIS AI"
echo "  Type 'jarvis <question>' in MATHIS OS to talk to AI"
echo "═══════════════════════════════════════════════════════"
echo ""

# Wait for QEMU
wait $QEMU_PID

# Cleanup
kill $BRIDGE_PID 2>/dev/null
echo "👋 Goodbye!"
