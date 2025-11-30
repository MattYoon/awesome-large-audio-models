#!/usr/bin/env bash
set -euo pipefail

readme_file="README.md"
out_dir="pdfs"

if [[ ! -f "$readme_file" ]]; then
  echo "README.md not found in $(pwd)" >&2
  exit 1
fi

mkdir -p "$out_dir"

normalize_url() {
  local url="$1"
  if [[ "$url" =~ ^https?://arxiv\.org/abs/([0-9.]+)(v[0-9]+)?$ ]]; then
    local id="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    echo "https://arxiv.org/pdf/${id}.pdf"
    return
  fi

  if [[ "$url" =~ ^https?://arxiv\.org/pdf/([^?#]+)\.pdf ]]; then
    local path="${BASH_REMATCH[1]}"
    echo "https://arxiv.org/pdf/${path}.pdf"
    return
  fi

  echo "$url"
}

mapfile -t raw_urls < <(grep -oP '\[PDF\]\(\K[^)]+' "$readme_file" | sort -u)

pdf_urls=()
for url in "${raw_urls[@]}"; do
  [[ "$url" =~ ^https?:// ]] || continue
  normalized=$(normalize_url "$url")

  skip=false
  for existing in "${pdf_urls[@]:-}"; do
    if [[ "$existing" == "$normalized" ]]; then
      skip=true
      break
    fi
  done

  if [[ "$skip" == false ]]; then
    pdf_urls+=("$normalized")
  fi

done

if [[ ${#pdf_urls[@]} -eq 0 ]]; then
  echo "No PDF links found in $readme_file" >&2
  exit 0
fi

for url in "${pdf_urls[@]}"; do
  clean_url="${url%%\#*}"

  if [[ ! "$clean_url" =~ \.pdf($|[?#]) ]]; then
    echo "Skipping non-PDF link: $url" >&2
    continue
  fi

  filename=$(basename "${clean_url%%\?*}")
  if [[ -z "$filename" || "$filename" == "/" ]]; then
    filename="download.pdf"
  fi

  target="$out_dir/$filename"
  if [[ -e "$target" ]]; then
    base="${filename%.*}"
    ext="${filename##*.}"
    i=1
    while [[ -e "$out_dir/${base}_${i}.${ext}" ]]; do
      ((i++))
    done
    target="$out_dir/${base}_${i}.${ext}"
  fi

  echo "Downloading $clean_url -> $target"
  if ! curl -A "Mozilla/5.0" -L --fail --retry 3 -o "$target" "$clean_url"; then
    echo "Failed to download $clean_url" >&2
    rm -f "$target"
  fi
done
