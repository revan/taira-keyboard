#!/usr/bin/env bash
# Revert files in the working tree whose only diff vs HEAD is a regenerated
# timestamp. Covers KiCad gerbers, drill files, and schematic PDFs.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Gerber timestamp lines:
#   G04 #@! TF.CreationDate,2026-05-18T00:06:31-04:00*
#   G04 Created by KiCad (PCBNEW 10.0.2) date 2026-05-18 00:06:31*
gerber_pattern='^(\+\+\+|---|[+-]G04 #@! TF\.CreationDate|[+-]G04 Created by KiCad)'

# Drill timestamp lines:
#   ; DRILL file KiCad 10.0.2 date 2026-05-18T00:06:31
#   ; #@! TF.CreationDate,2026-05-18T00:06:31-04:00
drill_pattern='^(\+\+\+|---|[+-]; DRILL file KiCad|[+-]; #@! TF\.CreationDate)'

revert_if_only_timestamps() {
    local file=$1 pattern=$2 leftover
    leftover=$(git diff -U0 -- "$file" | grep -E '^[+-]' | grep -vE "$pattern" || true)
    if [ -z "$leftover" ]; then
        git checkout HEAD -- "$file"
        echo "reverted (timestamp-only): $file"
    fi
}

revert_pdf_if_schematic_unchanged() {
    local file=$1 dir base schematic
    dir=$(dirname "$file")
    base=$(basename "$file" .pdf)
    schematic="$dir/$base.kicad_sch"
    if [ -f "$schematic" ] && git diff --quiet HEAD -- "$schematic"; then
        git checkout HEAD -- "$file"
        echo "reverted (schematic unchanged): $file"
    fi
}

while IFS= read -r file; do
    [ -z "$file" ] && continue
    case "$file" in
        *.gtl|*.gbl|*.gto|*.gbo|*.gts|*.gbs|*.gtp|*.gbp|*.gm1)
            revert_if_only_timestamps "$file" "$gerber_pattern"
            ;;
        *.drl)
            revert_if_only_timestamps "$file" "$drill_pattern"
            ;;
        *.pdf)
            revert_pdf_if_schematic_unchanged "$file"
            ;;
    esac
done < <(git diff --name-only HEAD)
