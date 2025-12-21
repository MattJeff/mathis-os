#!/bin/bash
# Check that all .asm files end in section .text

echo "Checking section hygiene..."
errors=0

for f in $(find boot/kernel -name "*.asm" -type f); do
    # Skip template and data_all
    [[ "$f" == *"TEMPLATE"* ]] && continue
    [[ "$f" == *"data_all"* ]] && continue

    # Get last section declaration
    last_section=$(grep -n "^section \." "$f" 2>/dev/null | tail -1)

    if [[ -n "$last_section" ]]; then
        if [[ ! "$last_section" == *".text"* ]]; then
            echo "ERROR: $f ends in ${last_section##*:}"
            ((errors++))
        fi
    fi
done

if [[ $errors -eq 0 ]]; then
    echo "All files OK"
else
    echo "$errors file(s) need fixing"
    exit 1
fi
