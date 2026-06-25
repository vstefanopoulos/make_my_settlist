#!/usr/bin/env bash
set -euo pipefail

# Keywords
PIANO_KEYWORDS=("Piano" "Lead sheet" "Keyboard" "Organ" "Orgel" "Concert" "Piano Muse" "Keys" "Full Score")
BASS_KEYWORDS=("bass guitar" "lead sheet" "piano" "Keyboard" "Organ" "Orgel" "Concert" "Piano Muse" "Keys" "Full Score")

usage() {
    echo "Usage: $(basename "$0") (-piano|-bass) [-target <absolute_folder_to_copy_new_pdfs>] [absolute_folder_path]"
    echo "       If no folder path is given, the current working directory is used."
    exit 1
}

# Parse flags
use_piano=false
use_bass=false
target_dir=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -piano) use_piano=true; shift ;;
        -bass)  use_bass=true;  shift ;;
        -target)
            if [[ -z "${2:-}" ]]; then echo "Error: -target requires an argument."; exit 1; fi
            target_dir="$2"; shift 2 ;;
        -*) echo "Unknown flag: $1"; usage ;;
        *) break ;;
    esac
done

if ! $use_piano && ! $use_bass; then
    echo "Error: specify either -piano or -bass flag."
    exit 1
fi
if $use_piano && $use_bass; then
    echo "Error: specify only one of -piano or -bass."
    exit 1
fi

if $use_piano; then
    keywords=("${PIANO_KEYWORDS[@]}")
else
    keywords=("${BASS_KEYWORDS[@]}")
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

    $found && return 0 || return 1
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

echo "PDFs copied to: $output_folder"
