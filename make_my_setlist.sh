#!/usr/bin/env bash
set -euo pipefail

PDFMERGE_URL="https://github.com/vstefanopoulos/make_my_settlist/releases/latest/download/pdfmerge"

# Keywords
PIANO_KEYWORDS=("Piano" "Lead sheet" "Keyboard" "Organ" "Orgel" "Concert" "Piano Muse" "Keys" "Full Score")
BASS_KEYWORDS=("bass guitar" "lead sheet" "piano" "Keyboard" "Organ" "Orgel" "Concert" "Piano Muse" "Keys" "Full Score")
GUITAR_KEYWORDS=("guitar" "lead sheet" "piano" "Keyboard" "Organ" "Orgel" "Concert" "Piano Muse" "Keys" "Full Score")
ALTO_KEYWORDS=("alto" "lead sheet" "piano" "Keyboard" "Organ" "Orgel" "Concert" "Piano Muse" "Keys" "Full Score")
TENOR_KEYWORDS=("tenor" "lead sheet" "piano" "Keyboard" "Organ" "Orgel" "Concert" "Piano Muse" "Keys" "Full Score")
TROMBONE_KEYWORDS=("trombone" "bone" "lead sheet" "piano" "Keyboard" "Organ" "Orgel" "Concert" "Piano Muse" "Keys" "Full Score")

usage() {
    echo "Usage: $(basename "$0") (-piano|-bass|-guitar|-alto|-tenor|-trombone) [-target <absolute_folder_to_copy_new_pdfs>] [-concat] [absolute_folder_path]"
    echo "       If no folder path is given, the current working directory is used."
    echo "       -concat  merge all collected PDFs into a single PDF using macOS PDFKit"
    exit 1
}

# Parse flags
use_piano=false
use_bass=false
use_guitar=false
use_alto=false
use_tenor=false
use_trombone=false
use_concat=false
target_dir=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -piano)    use_piano=true;    shift ;;
        -bass)     use_bass=true;     shift ;;
        -guitar)   use_guitar=true;   shift ;;
        -alto)     use_alto=true;     shift ;;
        -tenor)    use_tenor=true;    shift ;;
        -trombone) use_trombone=true; shift ;;
        -concat)   use_concat=true;   shift ;;
        -target)
            if [[ -z "${2:-}" ]]; then echo "Error: -target requires an argument."; exit 1; fi
            target_dir="$2"; shift 2 ;;
        -*) echo "Unknown flag: $1"; usage ;;
        *) break ;;
    esac
done

instrument_count=0
$use_piano    && ((instrument_count++)) || true
$use_bass     && ((instrument_count++)) || true
$use_guitar   && ((instrument_count++)) || true
$use_alto     && ((instrument_count++)) || true
$use_tenor    && ((instrument_count++)) || true
$use_trombone && ((instrument_count++)) || true

if [[ $instrument_count -eq 0 ]]; then
    echo "Error: specify one of -piano, -bass, -guitar, -alto, -tenor, or -trombone."
    exit 1
fi
if [[ $instrument_count -gt 1 ]]; then
    echo "Error: specify only one instrument flag."
    exit 1
fi

if $use_piano; then
    keywords=("${PIANO_KEYWORDS[@]}")
elif $use_bass; then
    keywords=("${BASS_KEYWORDS[@]}")
elif $use_guitar; then
    keywords=("${GUITAR_KEYWORDS[@]}")
elif $use_alto; then
    keywords=("${ALTO_KEYWORDS[@]}")
elif $use_tenor; then
    keywords=("${TENOR_KEYWORDS[@]}")
else
    keywords=("${TROMBONE_KEYWORDS[@]}")
fi

input_path="${1:-$PWD}"

# Validate input path
if [[ ! -d "$input_path" ]] || [[ "$input_path" != /* ]]; then
    echo "Error: Provide a valid absolute folder path."
    exit 1
fi

# Determine output folder
base_name="$(basename "$input_path")"
date_str="$(date '+%Y-%m-%d')"
if [[ -z "$target_dir" ]]; then
    base_output_dir="$HOME/Desktop"
else
    base_output_dir="$target_dir"
fi
output_folder="${base_output_dir}/${base_name}_${date_str}"

mkdir -p "$output_folder"

# Copy top-level PDFs (no prefix)
copy_top_level_pdfs() {
    local src_dir="$1"
    local dest_dir="$2"
    while IFS= read -r -d '' file; do
        name="$(basename "$file")"
        cp "$file" "${dest_dir}/${name}"
    done < <(find "$src_dir" -maxdepth 1 -not -type d -iname "*.pdf" -print0 2>/dev/null)
}

# List PDFs in a directory (non-recursive)
list_pdfs() {
    local dir="$1"
    find "$dir" -maxdepth 1 -not -type d -iname "*.pdf" -print0 2>/dev/null
}

# Count PDFs in a directory
count_pdfs() {
    local dir="$1"
    find "$dir" -maxdepth 1 -not -type d -iname "*.pdf" 2>/dev/null | wc -l | tr -d ' '
}

# Match keywords against a filename (case-insensitive)
matches_keywords() {
    local filename_lower
    filename_lower="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    for kw in "${keywords[@]}"; do
        local kw_lower
        kw_lower="$(echo "$kw" | tr '[:upper:]' '[:lower:]')"
        if [[ "$filename_lower" == *"$kw_lower"* ]]; then
            return 0
        fi
    done
    return 1
}

# Copy matching PDFs from a folder, prefixed with the 1st-level folder name.
# Returns 0 (found) or 1 (not found).
copy_matching_pdfs() {
    local folder_path="$1"
    local out_folder="$2"
    local prefix="$3"

    local pdf_count
    pdf_count="$(count_pdfs "$folder_path")"
    if [[ "$pdf_count" -eq 0 ]]; then
        return 1
    fi

    local found=false
    while IFS= read -r -d '' file; do
        local name
        name="$(basename "$file")"
        if [[ "$pdf_count" -eq 1 ]] || matches_keywords "$name"; then
            cp "$file" "${out_folder}/${prefix} ${name}"
            found=true
        fi
    done < <(list_pdfs "$folder_path")

    # Last resort: if no keyword match, look for a PDF whose base name is contained in the folder name
    if ! $found; then
        local folder_lower
        folder_lower="$(echo "$prefix" | tr '[:upper:]' '[:lower:]')"
        while IFS= read -r -d '' file; do
            local name
            name="$(basename "$file")"
            local name_lower
            name_lower="$(echo "${name%.*}" | tr '[:upper:]' '[:lower:]')"
            if [[ "$folder_lower" == *"$name_lower"* ]]; then
                cp "$file" "${out_folder}/${prefix} ${name}"
                found=true
                break
            fi
        done < <(list_pdfs "$folder_path")
    fi

    $found && return 0 || return 1
}

# Downloads the pdfmerge binary from GitHub Releases, runs it, then deletes it.
# The binary is a universal Swift/PDFKit CLI — no dependencies required on the user's machine.
merge_pdfs() {
    local src_dir="$1"
    local output_pdf="$2"
    local tmp_bin
    tmp_bin="$(mktemp)"

    echo "Downloading pdfmerge..."
    if ! curl -fsSL "$PDFMERGE_URL" -o "$tmp_bin"; then
        rm -f "$tmp_bin"
        echo "Error: failed to download pdfmerge. Check your internet connection."
        exit 1
    fi

    chmod +x "$tmp_bin"
    xattr -d com.apple.quarantine "$tmp_bin" 2>/dev/null || true

    "$tmp_bin" "$src_dir" "$output_pdf"
    rm -f "$tmp_bin"
}

# --- Main logic ---

copy_top_level_pdfs "$input_path" "$output_folder"

while IFS= read -r -d '' subfolder; do
    entry_name="$(basename "$subfolder")"
    if copy_matching_pdfs "$subfolder" "$output_folder" "$entry_name"; then
        continue
    fi

    # Try 2nd-level subfolders
    found_in_second=false
    while IFS= read -r -d '' second_subfolder; do
        if copy_matching_pdfs "$second_subfolder" "$output_folder" "$entry_name"; then
            found_in_second=true
        fi
    done < <(find "$subfolder" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

    if ! $found_in_second; then
        echo "No Results found on folder: $entry_name"
    fi
done < <(find "$input_path" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

if $use_concat; then
    merged_pdf="${base_output_dir}/${base_name}_${date_str}.pdf"
    merge_pdfs "$output_folder" "$merged_pdf"
    rm -rf "$output_folder"
    echo "Merged PDF: $merged_pdf"
else
    echo "PDFs copied to: $output_folder"
fi
