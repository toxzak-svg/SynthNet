#!/bin/bash
# Simple compilation script to verify contract syntax

echo "Compiling AIAgentResumeSBT contract..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Create output directory if it doesn't exist
OUTPUT_DIR="/tmp/contracts-build"
mkdir -p "$OUTPUT_DIR"

npx solcjs contracts/AIAgentResumeSBT.sol \
  --base-path . \
  --include-path node_modules \
  --optimize \
  --optimize-runs 200 \
  --bin \
  --abi \
  --output-dir "$OUTPUT_DIR"

if [ $? -eq 0 ]; then
    echo "✓ Contract compiled successfully!"
    echo ""
    echo "Generated artifacts:"
    ls -lh "$OUTPUT_DIR"/*AIAgentResumeSBT* 2>/dev/null
    echo ""
    echo "Contract size:"
    wc -c "$OUTPUT_DIR"/*AIAgentResumeSBT*.bin 2>/dev/null | grep -v total
    exit 0
else
    echo "✗ Compilation failed!"
    exit 1
fi
