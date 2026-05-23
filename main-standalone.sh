#!/bin/bash

# ──────────────────────────────
#  Colors — using $'...' so escape codes work without echo -e
# ──────────────────────────────
GREEN=$'\033[1;32m'
CYAN=$'\033[1;36m'
YELLOW=$'\033[1;33m'
RED=$'\033[1;31m'
RESET=$'\033[0m'

# ──────────────────────────────
#  Load config.conf
# ──────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.conf"

if [ ! -f "$CONFIG_FILE" ]; then
  clear
  echo "${YELLOW}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║          ⚙️  config.conf not found            ║"
  echo "╚══════════════════════════════════════════════╝"
  echo "${RESET}"
  echo "  Create a ${CYAN}config.conf${RESET} file next to the script to avoid"
  echo "  entering credentials every time. Example:"
  echo
  echo "  ${CYAN}IPFS_API_URL=\"https://yourdomain.net\""
  echo "  IPFS_USER=\"user\""
  echo "  IPFS_PASS=\"password\"${RESET}"
  echo
  read -p "  Enter credentials manually now? (y/n): " _manual
  if [[ "$_manual" =~ ^[Yy]$ ]]; then
    echo
    read -p "  Domain or IP (e.g. yourdomain.net): " _raw_url
    # Strip any existing protocol prefix, then add https://
    _raw_url="${_raw_url#http://}"
    _raw_url="${_raw_url#https://}"
    IPFS_API_URL="https://${_raw_url}"
    read -p "  Username: " IPFS_USER
    read -s -p "  Password: " IPFS_PASS
    echo
  else
    echo "${YELLOW}Exiting.${RESET}"
    exit 0
  fi
else
  source "$CONFIG_FILE"
  for var in IPFS_API_URL IPFS_USER IPFS_PASS; do
    if [ -z "${!var}" ]; then
      echo "${RED}❌ Error: $var is not defined in config.conf${RESET}"
      exit 1
    fi
  done
fi

# ──────────────────────────────
#  Default add parameters
# ──────────────────────────────
ADD_DEFAULTS="preserve-mode=true&preserve-mtime=true&cid-version=1"

# ──────────────────────────────
#  API helpers
# ──────────────────────────────

# Pure bash URL-encode — preserves / so IPFS paths stay intact
urlencode() {
  local s="$1" out="" i c
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9/._~:-]) out+="$c" ;;
      *) printf -v c '%%%02X' "'$c"; out+="$c" ;;
    esac
  done
  printf '%s' "$out"
}

# POST to API, raw output
api() {
  local endpoint="$1"; shift
  curl -s -X POST \
    -u "$IPFS_USER:$IPFS_PASS" \
    "$@" \
    "${IPFS_API_URL}/api/v0/${endpoint}"
}

# POST to API, pretty JSON
apij() {
  local endpoint="$1"; shift
  local resp
  resp=$(api "$endpoint" "$@")
  if [ -n "$resp" ]; then
    echo "$resp" | jq . 2>/dev/null || echo "$resp"
  fi
}

# Check response for errors
check_err() {
  local resp="$1"
  [ -z "$resp" ] && return 0
  local err
  err=$(echo "$resp" | jq -r '.Message // empty' 2>/dev/null)
  if [ -n "$err" ]; then
    echo "${RED}❌ Error: $err${RESET}"
    return 1
  fi
  return 0
}

# ──────────────────────────────
#  Upload directory via multipart
# ──────────────────────────────
add_dir_api() {
  local dir="$1"
  local extra_params="${2:-}"
  local parent
  parent=$(dirname "$dir")
  local -a form=()

  while IFS= read -r d; do
    local relpath="${d#$parent/}/"
    form+=(-F "file=;type=application/x-directory;filename=${relpath}")
  done < <(find "$dir" -mindepth 0 -type d | sort)

  while IFS= read -r f; do
    local relpath="${f#$parent/}"
    form+=(-F "file=@${f};filename=${relpath}")
  done < <(find "$dir" -type f | sort)

  curl -s -X POST \
    -u "$IPFS_USER:$IPFS_PASS" \
    "${form[@]}" \
    "${IPFS_API_URL}/api/v0/add?recursive=true&quieter=true&progress=true&${ADD_DEFAULTS}${extra_params}"
}

# ──────────────────────────────
#  UI utilities
# ──────────────────────────────
pause() { echo; read -p "Press Enter to continue..."; }
ask()   { read -p "$1" "$2"; }

header() {
  clear
  echo "${CYAN}"
  echo "╔══════════════════════════════════════════════╗"
  echo "║           🪐  IPFS Node Manager              ║"
  echo "╚══════════════════════════════════════════════╝"
  echo "  API: ${GREEN}${IPFS_API_URL}${CYAN}   User: ${GREEN}${IPFS_USER}${RESET}"
  echo
}

# ──────────────────────────────
#  Local file/directory browser
#  Usage: seleccionar_ruta <mode> [start_dir]
# ──────────────────────────────
seleccionar_ruta() {
  local mode="${1:-file}"
  local dir="${2:-/home}"
  RUTA_SELECCIONADA=""

  while true; do
    clear
    echo "${CYAN}╔══════════════════════════════════════════════╗"
    echo "║         📂  Select ${mode}                    ║"
    echo "╚══════════════════════════════════════════════╝${RESET}"
    echo "${YELLOW}  Location: ${GREEN}$dir${RESET}"
    echo

    local items=()
    items+=("..")
    while IFS= read -r d; do
      items+=("📁 $(basename "$d")/")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
    if [[ "$mode" == "file" ]]; then
      while IFS= read -r f; do
        items+=("📄 $(basename "$f")")
      done < <(find "$dir" -maxdepth 1 -mindepth 1 -type f 2>/dev/null | sort)
    fi

    for i in "${!items[@]}"; do
      printf "  %3d) %s\n" "$((i+1))" "${items[$i]}"
    done

    echo
    [[ "$mode" == "directory" ]] && echo "  ${GREEN}S) Select this directory: $dir${RESET}"
    echo "  0) Cancel"
    echo
    ask "Option: " sel

    [[ "$sel" == "0" ]] && RUTA_SELECCIONADA="" && return 1

    if [[ "$mode" == "directory" && ("$sel" == "s" || "$sel" == "S") ]]; then
      RUTA_SELECCIONADA="$dir"; return 0
    fi

    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#items[@]} )); then
      echo "${RED}Invalid option${RESET}"; sleep 1; continue
    fi

    local chosen="${items[$((sel-1))]}"
    [[ "$chosen" == ".." ]] && dir="$(dirname "$dir")" && continue

    if [[ "$chosen" == 📁* ]]; then
      local name
      name=$(echo "$chosen" | sed 's/^📁 //' | sed 's|/$||')
      dir="$dir/$name"; continue
    fi

    if [[ "$chosen" == 📄* ]]; then
      local name
      name=$(echo "$chosen" | sed 's/^📄 //')
      RUTA_SELECCIONADA="$dir/$name"; return 0
    fi
  done
}

# ──────────────────────────────
#  MFS browser — choose destination
#  Usage: seleccionar_mfs <default_name> [start_dir]
# ──────────────────────────────
seleccionar_mfs() {
  local default_name="${1:-}"
  local dir="${2:-/}"
  MFS_SELECCIONADO=""

  while true; do
    clear
    echo "${CYAN}╔══════════════════════════════════════════════╗"
    echo "║         🗂️  MFS Destination                  ║"
    echo "╚══════════════════════════════════════════════╝${RESET}"
    echo "${YELLOW}  MFS location: ${GREEN}$dir${RESET}"
    echo

    local items=()
    items+=("..")
    local entries
    entries=$(api "files/ls?arg=$(urlencode "$dir")" | jq -r '.Entries[]?.Name // empty' 2>/dev/null)
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      local full="${dir%/}/$entry"
      full="${full//\/\//\/}"
      local tipo
      tipo=$(api "files/stat?arg=$(urlencode "$full")" | jq -r '.Type // "file"' 2>/dev/null)
      if [ "$tipo" = "directory" ]; then
        items+=("📁 $entry/")
      else
        items+=("📄 $entry")
      fi
    done <<< "$entries"

    for i in "${!items[@]}"; do
      printf "  %3d) %s\n" "$((i+1))" "${items[$i]}"
    done

    echo
    echo "  ${GREEN}S) Save here → ${dir%/}/$default_name${RESET}"
    echo "  ${YELLOW}M) Type path manually${RESET}"
    echo "  0) Cancel"
    echo
    ask "Option: " sel

    [[ "$sel" == "0" ]] && MFS_SELECCIONADO="" && return 1

    if [[ "$sel" == "s" || "$sel" == "S" ]]; then
      local base="$dir"
      [[ "$base" != /* ]] && base="/$base"
      if [ "$base" = "/" ]; then
        MFS_SELECCIONADO="/$default_name"
      else
        MFS_SELECCIONADO="${base%/}/$default_name"
      fi
      MFS_SELECCIONADO="${MFS_SELECCIONADO//\/\//\/}"
      return 0
    fi

    if [[ "$sel" == "m" || "$sel" == "M" ]]; then
      ask "Full MFS path: " manual_path
      MFS_SELECCIONADO="$manual_path"; return 0
    fi

    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#items[@]} )); then
      echo "${RED}Invalid option${RESET}"; sleep 1; continue
    fi

    local chosen="${items[$((sel-1))]}"

    if [[ "$chosen" == ".." ]]; then
      [ "$dir" != "/" ] && dir="$(dirname "${dir%/}")"
      [ -z "$dir" ] && dir="/"
      continue
    fi

    if [[ "$chosen" == 📁* ]]; then
      local name
      name=$(echo "$chosen" | sed 's/^📁 //' | sed 's|/$||')
      dir="${dir%/}/$name"
      dir="${dir//\/\//\/}"
      continue
    fi
  done
}

# ──────────────────────────────
#  MFS browser — choose source
#  Usage: seleccionar_mfs_origen [start_dir]
# ──────────────────────────────
seleccionar_mfs_origen() {
  local dir="${1:-/}"
  MFS_ORIGEN=""

  while true; do
    clear
    echo "${CYAN}╔══════════════════════════════════════════════╗"
    echo "║         🗂️  Select MFS Source                ║"
    echo "╚══════════════════════════════════════════════╝${RESET}"
    echo "${YELLOW}  MFS location: ${GREEN}$dir${RESET}"
    echo

    local items=()
    items+=("..")
    local entries
    entries=$(api "files/ls?arg=$(urlencode "$dir")" | jq -r '.Entries[]?.Name // empty' 2>/dev/null)
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      local full="${dir%/}/$entry"
      full="${full//\/\//\/}"
      local tipo
      tipo=$(api "files/stat?arg=$(urlencode "$full")" | jq -r '.Type // "file"' 2>/dev/null)
      if [ "$tipo" = "directory" ]; then
        items+=("📁 $entry/")
      else
        items+=("📄 $entry")
      fi
    done <<< "$entries"

    for i in "${!items[@]}"; do
      printf "  %3d) %s\n" "$((i+1))" "${items[$i]}"
    done

    echo
    echo "  ${GREEN}S) Select this directory: $dir${RESET}"
    echo "  0) Cancel"
    echo
    ask "Option: " sel

    [[ "$sel" == "0" ]] && MFS_ORIGEN="" && return 1

    if [[ "$sel" == "s" || "$sel" == "S" ]]; then
      MFS_ORIGEN="$dir"; return 0
    fi

    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#items[@]} )); then
      echo "${RED}Invalid option${RESET}"; sleep 1; continue
    fi

    local chosen="${items[$((sel-1))]}"

    if [[ "$chosen" == ".." ]]; then
      [ "$dir" != "/" ] && dir="$(dirname "${dir%/}")"
      [ -z "$dir" ] && dir="/"
      continue
    fi

    if [[ "$chosen" == 📁* ]]; then
      local name
      name=$(echo "$chosen" | sed 's/^📁 //' | sed 's|/$||')
      dir="${dir%/}/$name"
      dir="${dir//\/\//\/}"
      continue
    fi

    if [[ "$chosen" == 📄* ]]; then
      local name
      name=$(echo "$chosen" | sed 's/^📄 //')
      MFS_ORIGEN="${dir%/}/$name"
      MFS_ORIGEN="${MFS_ORIGEN//\/\//\/}"
      return 0
    fi
  done
}

# ══════════════════════════════════════════════
#  1. NODE INFO
# ══════════════════════════════════════════════
menu_node() {
  while true; do
    header
    echo "${YELLOW}[ NODE INFO ]${RESET}"
    echo "  1) Node identity (id)"
    echo "  2) IPFS version"
    echo "  3) Repository stats"
    echo "  4) Bandwidth live (stats bw — 1s)"
    echo "  5) Bitswap stats"
    echo "  6) System info (diag sys)"
    echo "  7) Active commands (diag cmds)"
    echo "  0) Back"
    echo
    ask "Option: " opt
    case $opt in
      1) apij "id"; pause ;;
      2) apij "version"; pause ;;
      3) apij "repo/stat?human=true"; pause ;;
      4)
        local _running=1
        trap '_running=0' INT
        while [ "$_running" -eq 1 ]; do
          clear
          echo "${YELLOW}  📡 Bandwidth — Ctrl+C to stop${RESET}"
          echo
          api "stats/bw" | jq '{
            "Total In  (bytes)": .TotalIn,
            "Total Out (bytes)": .TotalOut,
            "Rate In   (b/s)":   .RateIn,
            "Rate Out  (b/s)":   .RateOut
          }' 2>/dev/null
          sleep 1
        done
        trap - INT
        echo "${YELLOW}Stopped.${RESET}"
        pause ;;
      5) apij "stats/bitswap?verbose=true&human=true"; pause ;;
      6) apij "diag/sys"; pause ;;
      7) apij "diag/cmds"; pause ;;
      0) break ;;
      *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  2. FILES
# ══════════════════════════════════════════════
menu_files() {
  while true; do
    header
    echo "${YELLOW}[ FILES ]${RESET}"
    echo "  1) Upload file to IPFS only"
    echo "  2) Upload directory to IPFS only"
    echo "  3) Add file → IPFS + MFS"
    echo "  4) Add directory → IPFS + MFS"
    echo "  5) Download from MFS to local"
    echo "  6) Download content by CID"
    echo "  7) View content by CID (cat)"
    echo "  8) List CID links (ls)"
    echo "  9) DAG stats"
    echo " 10) Export DAG as .car"
    echo " 11) Import .car"
    echo "  0) Back"
    echo
    ask "Option: " opt
    case $opt in
      1)
        local _last_dir="/home"
        ask "  wrap-with-directory? (y/n) [y]: " wrap_ans
        [[ -z "$wrap_ans" || "$wrap_ans" =~ ^[Yy]$ ]] && wrap="true" || wrap="false"
        ask "  only-hash (dry run, no upload)? (y/n) [n]: " hash_ans
        [[ "$hash_ans" =~ ^[Yy]$ ]] && ohash="true" || ohash="false"
        while true; do
          seleccionar_ruta "file" "$_last_dir"
          [ -z "$RUTA_SELECCIONADA" ] && break
          _last_dir=$(dirname "$RUTA_SELECCIONADA")
          local file_name
          file_name=$(basename "$RUTA_SELECCIONADA")
          echo "${GREEN}Uploading: $RUTA_SELECCIONADA${RESET}"
          local resp
          resp=$(curl -s -X POST \
            -u "$IPFS_USER:$IPFS_PASS" \
            -F "file=@${RUTA_SELECCIONADA};filename=${file_name}" \
            "${IPFS_API_URL}/api/v0/add?quieter=true&progress=true&${ADD_DEFAULTS}&wrap-with-directory=${wrap}&only-hash=${ohash}")
          local cid
          cid=$(echo "$resp" | tail -1 | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid" ]; then
            echo "${RED}❌ Upload failed:${RESET}"; echo "$resp" | jq . 2>/dev/null
          else
            echo "${GREEN}✅ CID: $cid${RESET}"
          fi
          echo
          ask "Continue uploading files? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      2)
        local _last_dir="/home"
        ask "  only-hash (dry run, no upload)? (y/n) [n]: " hash_ans
        [[ "$hash_ans" =~ ^[Yy]$ ]] && ohash="&only-hash=true" || ohash=""
        while true; do
          seleccionar_ruta "directory" "$_last_dir"
          [ -z "$RUTA_SELECCIONADA" ] && break
          _last_dir=$(dirname "$RUTA_SELECCIONADA")
          echo "${GREEN}Uploading directory: $RUTA_SELECCIONADA${RESET}"
          echo "${YELLOW}(may take several minutes for large directories)${RESET}"
          local resp
          resp=$(add_dir_api "$RUTA_SELECCIONADA" "$ohash")
          local cid
          cid=$(echo "$resp" | tail -1 | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid" ]; then
            echo "${RED}❌ Upload failed:${RESET}"; echo "$resp" | jq . 2>/dev/null
          else
            echo "${GREEN}✅ CID: $cid${RESET}"
          fi
          echo
          ask "Continue uploading directories? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      3)
        local _last_dir="/home"
        while true; do
          seleccionar_ruta "file" "$_last_dir"
          [ -z "$RUTA_SELECCIONADA" ] && break
          _last_dir=$(dirname "$RUTA_SELECCIONADA")
          local file_name
          file_name=$(basename "$RUTA_SELECCIONADA")
          seleccionar_mfs "$file_name"
          [ -z "$MFS_SELECCIONADO" ] && break
          echo "${GREEN}Uploading: $RUTA_SELECCIONADA${RESET}"
          local resp
          resp=$(curl -s -X POST \
            -u "$IPFS_USER:$IPFS_PASS" \
            -F "file=@${RUTA_SELECCIONADA};filename=${file_name}" \
            "${IPFS_API_URL}/api/v0/add?quieter=true&progress=true&${ADD_DEFAULTS}")
          local cid
          cid=$(echo "$resp" | tail -1 | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid" ]; then
            echo "${RED}❌ Upload failed:${RESET}"; echo "$resp" | jq . 2>/dev/null
            echo; ask "Continue uploading files? (y/n): " _again
            [[ "$_again" =~ ^[Yy]$ ]] || break; continue
          fi
          echo "${GREEN}CID: $cid${RESET}"
          local cp_resp
          cp_resp=$(api "files/cp?arg=$(urlencode "/ipfs/$cid")&arg=$(urlencode "$MFS_SELECCIONADO")")
          check_err "$cp_resp" && echo "${GREEN}✅ Saved to MFS: $MFS_SELECCIONADO${RESET}"
          echo
          ask "Continue uploading files? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      4)
        local _last_dir="/home"
        while true; do
          seleccionar_ruta "directory" "$_last_dir"
          [ -z "$RUTA_SELECCIONADA" ] && break
          _last_dir=$(dirname "$RUTA_SELECCIONADA")
          local dir_name
          dir_name=$(basename "$RUTA_SELECCIONADA")
          seleccionar_mfs "$dir_name"
          [ -z "$MFS_SELECCIONADO" ] && break
          ask "Add without pin? (y/n): " nopin
          local extra=""
          [[ "$nopin" =~ ^[Yy]$ ]] && extra="&pin=false"
          echo "${GREEN}Uploading directory: $RUTA_SELECCIONADA${RESET}"
          echo "${YELLOW}(may take several minutes for large directories)${RESET}"
          local resp
          resp=$(add_dir_api "$RUTA_SELECCIONADA" "$extra")
          local cid
          cid=$(echo "$resp" | tail -1 | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid" ]; then
            echo "${RED}❌ Upload failed:${RESET}"; echo "$resp" | jq . 2>/dev/null
            echo; ask "Continue uploading directories? (y/n): " _again
            [[ "$_again" =~ ^[Yy]$ ]] || break; continue
          fi
          echo "${GREEN}CID: $cid${RESET}"
          local cp_resp
          cp_resp=$(api "files/cp?arg=$(urlencode "/ipfs/$cid")&arg=$(urlencode "$MFS_SELECCIONADO")")
          check_err "$cp_resp" && echo "${GREEN}✅ Saved to MFS: $MFS_SELECCIONADO${RESET}"
          echo
          ask "Continue uploading directories? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      5)
        local _last_mfs="/"
        while true; do
          seleccionar_mfs_origen "$_last_mfs"
          [ -z "$MFS_ORIGEN" ] && break
          _last_mfs=$(dirname "$MFS_ORIGEN")
          [ -z "$_last_mfs" ] && _last_mfs="/"
          local cid_src
          cid_src=$(api "files/stat?arg=$(urlencode "$MFS_ORIGEN")" \
            | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid_src" ]; then
            echo "${RED}❌ Could not get CID for $MFS_ORIGEN${RESET}"
            pause; break
          fi
          echo "${CYAN}  MFS source: $MFS_ORIGEN${RESET}"
          echo "${CYAN}  CID:        $cid_src${RESET}"
          echo
          seleccionar_ruta "directory"
          [ -z "$RUTA_SELECCIONADA" ] && break
          local base_name
          base_name=$(basename "$MFS_ORIGEN")
          local dest="$RUTA_SELECCIONADA/$base_name"
          mkdir -p "$dest"
          echo "${GREEN}Downloading to: $dest${RESET}"
          local tmpdir
          tmpdir=$(mktemp -d)
          curl -s -X POST \
            -u "$IPFS_USER:$IPFS_PASS" \
            "${IPFS_API_URL}/api/v0/get?arg=$(urlencode "/ipfs/$cid_src")" \
            | tar -x -C "$tmpdir"
          local extracted
          extracted=$(ls "$tmpdir" 2>/dev/null | head -1)
          if [ -n "$extracted" ]; then
            local src_path="$tmpdir/$extracted"
            if [ -d "$src_path" ]; then cp -r "$src_path/." "$dest"
            else mv "$src_path" "$dest"; fi
            echo "${GREEN}✅ Saved to: $dest${RESET}"
          else
            echo "${RED}❌ Could not extract content${RESET}"
          fi
          rm -rf "$tmpdir"
          echo
          ask "Continue downloading? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      6)
        ask "CID to download: " cid
        seleccionar_ruta "directory"
        [ -z "$RUTA_SELECCIONADA" ] && pause && continue
        local tmpdir
        tmpdir=$(mktemp -d)
        echo "${GREEN}Downloading CID: $cid${RESET}"
        curl -s -X POST \
          -u "$IPFS_USER:$IPFS_PASS" \
          "${IPFS_API_URL}/api/v0/get?arg=$(urlencode "$cid")" \
          | tar -x -C "$tmpdir"
        local extracted
        extracted=$(ls "$tmpdir" 2>/dev/null | head -1)
        if [ -n "$extracted" ]; then
          mv "$tmpdir/$extracted" "$RUTA_SELECCIONADA/"
          echo "${GREEN}✅ Saved to: $RUTA_SELECCIONADA/$extracted${RESET}"
        else
          echo "${RED}❌ Could not extract content${RESET}"
        fi
        rm -rf "$tmpdir"
        pause ;;

      7)
        ask "CID or path: " cid
        api "cat?arg=$(urlencode "$cid")"
        echo; pause ;;

      8)
        ask "CID or path: " cid
        apij "ls?arg=$(urlencode "$cid")"
        pause ;;

      9)
        ask "CID: " cid
        apij "dag/stat?arg=$(urlencode "$cid")"
        pause ;;

      10)
        ask "Root CID: " cid
        ask "Output file (.car): " out
        curl -s -X POST \
          -u "$IPFS_USER:$IPFS_PASS" \
          "${IPFS_API_URL}/api/v0/dag/export?arg=$(urlencode "$cid")" > "$out"
        echo "${GREEN}✅ Exported to: $out${RESET}"
        pause ;;

      11)
        ask ".car file path: " car_file
        curl -s -X POST \
          -u "$IPFS_USER:$IPFS_PASS" \
          -F "file=@${car_file}" \
          "${IPFS_API_URL}/api/v0/dag/import" | jq .
        pause ;;

      0) break ;;
      *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  3. MFS
# ══════════════════════════════════════════════
menu_mfs() {
  while true; do
    header
    echo "${YELLOW}[ MFS — Mutable File System ]${RESET}"
    echo "  1) Browse MFS (interactive)"
    echo "  2) Create directory (files mkdir)"
    echo "  3) Copy CID to MFS (files cp)"
    echo "  4) Move file/directory (files mv)"
    echo "  5) Delete file/directory (files rm)"
    echo "  6) File/directory info (files stat)"
    echo "  7) Read file content (files read)"
    echo "  8) Flush MFS (files flush)"
    echo "  0) Back"
    echo
    ask "Option: " opt
    case $opt in
      1)
        seleccionar_mfs_origen
        pause ;;

      2)
        ask "Path to create: " path
        local resp
        resp=$(api "files/mkdir?arg=$(urlencode "$path")&parents=true")
        check_err "$resp" && echo "${GREEN}✅ Directory created: $path${RESET}"
        pause ;;

      3)
        # Prefix selection
        echo
        echo "  CID prefix:"
        echo "  1) /ipfs/"
        echo "  2) /ipns/"
        echo "  3) Type full path manually"
        echo
        ask "Option: " prefix_opt
        local cid
        case $prefix_opt in
          1) ask "CID hash: " _hash; cid="/ipfs/$_hash" ;;
          2) ask "IPNS name or hash: " _hash; cid="/ipns/$_hash" ;;
          *) ask "Full path: " cid ;;
        esac
        echo
        echo "  1) File  2) Directory"
        ask "Type: " cp_type
        echo "${CYAN}  Navigate to destination directory in MFS:${RESET}"
        seleccionar_mfs_origen
        [ -z "$MFS_ORIGEN" ] && pause && continue
        local dir_dest="$MFS_ORIGEN"
        local stat_type
        stat_type=$(api "files/stat?arg=$(urlencode "$dir_dest")" \
          | jq -r '.Type // "file"' 2>/dev/null)
        [ "$stat_type" != "directory" ] && dir_dest=$(dirname "$dir_dest")
        [[ "$dir_dest" != /* ]] && dir_dest="/$dir_dest"
        dir_dest="${dir_dest//\/\//\/}"
        if [[ "$cp_type" == "1" ]]; then
          ask "File name (with extension): " dest_name
        else
          ask "Directory name: " dest_name
        fi
        local dest_final
        [ "$dir_dest" = "/" ] \
          && dest_final="/$dest_name" \
          || dest_final="${dir_dest%/}/$dest_name"
        local resp
        resp=$(api "files/cp?arg=$(urlencode "$cid")&arg=$(urlencode "$dest_final")")
        check_err "$resp" && echo "${GREEN}✅ Copied to MFS: $dest_final${RESET}"
        pause ;;

      4)
        echo "${CYAN}  Select source in MFS:${RESET}"
        seleccionar_mfs_origen
        [ -z "$MFS_ORIGEN" ] && pause && continue
        local src_path="$MFS_ORIGEN"
        local src_name
        src_name=$(basename "$src_path")
        echo "${CYAN}  Select destination in MFS:${RESET}"
        seleccionar_mfs "$src_name"
        [ -z "$MFS_SELECCIONADO" ] && pause && continue
        local resp
        resp=$(api "files/mv?arg=$(urlencode "$src_path")&arg=$(urlencode "$MFS_SELECCIONADO")")
        check_err "$resp" && echo "${GREEN}✅ Moved: $src_path → $MFS_SELECCIONADO${RESET}"
        pause ;;

      5)
        local _last_mfs="/"
        while true; do
          echo "${CYAN}  Select file or directory to delete:${RESET}"
          seleccionar_mfs_origen "$_last_mfs"
          [ -z "$MFS_ORIGEN" ] && break
          _last_mfs=$(dirname "$MFS_ORIGEN")
          [ -z "$_last_mfs" ] && _last_mfs="/"
          echo "${RED}⚠️  About to delete: $MFS_ORIGEN${RESET}"
          ask "Confirm? (y/n): " confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            local item_type
            item_type=$(api "files/stat?arg=$(urlencode "$MFS_ORIGEN")" \
              | jq -r '.Type // "file"' 2>/dev/null)
            local resp
            if [ "$item_type" = "directory" ]; then
              resp=$(api "files/rm?arg=$(urlencode "$MFS_ORIGEN")&recursive=true")
            else
              resp=$(api "files/rm?arg=$(urlencode "$MFS_ORIGEN")")
            fi
            check_err "$resp" && echo "${GREEN}✅ Deleted: $MFS_ORIGEN${RESET}"
          else
            echo "${YELLOW}Cancelled.${RESET}"
          fi
          echo
          ask "Delete another item? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      6)
        seleccionar_mfs_origen
        [ -z "$MFS_ORIGEN" ] && pause && continue
        apij "files/stat?arg=$(urlencode "$MFS_ORIGEN")"
        pause ;;

      7)
        seleccionar_mfs_origen
        [ -z "$MFS_ORIGEN" ] && pause && continue
        api "files/read?arg=$(urlencode "$MFS_ORIGEN")"
        echo; pause ;;

      8)
        ask "Path to flush (Enter = /): " path
        path="${path:-/}"
        apij "files/flush?arg=$(urlencode "$path")"
        pause ;;

      0) break ;;
      *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  4. PINS
# ══════════════════════════════════════════════
menu_pins() {
  while true; do
    header
    echo "${YELLOW}[ PINS ]${RESET}"
    echo "  1) List pins"
    echo "  2) Add pin"
    echo "  3) Remove pin"
    echo "  4) Verify pins"
    echo "  0) Back"
    echo
    ask "Option: " opt
    case $opt in
      1)
        echo "  a) All  b) Recursive  c) Direct  d) Indirect"
        ask "Type (Enter = all): " tipo
        case $tipo in
          b) apij "pin/ls?type=recursive" ;;
          c) apij "pin/ls?type=direct" ;;
          d) apij "pin/ls?type=indirect" ;;
          *) apij "pin/ls" ;;
        esac
        pause ;;
      2)
        ask "CID to pin: " cid
        apij "pin/add?arg=$(urlencode "$cid")"
        pause ;;
      3)
        ask "CID to unpin: " cid
        apij "pin/rm?arg=$(urlencode "$cid")"
        pause ;;
      4)
        apij "pin/verify"
        pause ;;
      0) break ;;
      *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  5. NETWORK
# ══════════════════════════════════════════════
menu_network() {
  while true; do
    header
    echo "${YELLOW}[ NETWORK / SWARM ]${RESET}"
    echo "  1) Connected peers (swarm peers)"
    echo "  2) Node addresses (swarm addrs local)"
    echo "  3) Connect to peer"
    echo "  4) Disconnect peer"
    echo "  5) Find peer in DHT (routing findpeer)"
    echo "  6) Find CID providers (routing findprovs)"
    echo "  7) Ping a peer"
    echo "  8) List bootstrap peers"
    echo "  0) Back"
    echo
    ask "Option: " opt
    case $opt in
      1) apij "swarm/peers"; pause ;;
      2) apij "swarm/addrs/local"; pause ;;
      3)
        ask "Peer multiaddr: " peer
        apij "swarm/connect?arg=$(urlencode "$peer")"
        pause ;;
      4)
        ask "Peer multiaddr: " peer
        apij "swarm/disconnect?arg=$(urlencode "$peer")"
        pause ;;
      5)
        ask "PeerID: " peer
        apij "routing/findpeer?arg=$(urlencode "$peer")"
        pause ;;
      6)
        ask "CID: " cid
        api "routing/findprovs?arg=$(urlencode "$cid")" | jq .
        pause ;;
      7)
        ask "PeerID: " peer
        api "ping?arg=$(urlencode "$peer")&count=5" | jq .
        pause ;;
      8)
        apij "bootstrap/list"
        pause ;;
      0) break ;;
      *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  6. REPOSITORY
# ══════════════════════════════════════════════
menu_repo() {
  while true; do
    header
    echo "${YELLOW}[ REPOSITORY ]${RESET}"
    echo "  1) Repository stats"
    echo "  2) Garbage collection (repo gc)"
    echo "  3) Verify integrity (repo verify)"
    echo "  4) List local CIDs (refs local)"
    echo "  0) Back"
    echo
    ask "Option: " opt
    case $opt in
      1) apij "repo/stat?human=true"; pause ;;
      2)
        echo "${RED}⚠️  This will remove unpinned blocks with no MFS reference${RESET}"
        ask "Confirm? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          echo "${YELLOW}Running GC...${RESET}"
          api "repo/gc" | jq -r 'select(.Key) | "Removed: \(.Key["/"])"' 2>/dev/null
          echo "${GREEN}✅ GC complete${RESET}"
        fi
        pause ;;
      3)
        echo "${YELLOW}Verifying repository integrity...${RESET}"
        apij "repo/verify"
        pause ;;
      4)
        echo "${YELLOW}Local CIDs:${RESET}"
        api "refs/local" | jq -r '.Ref' 2>/dev/null
        pause ;;
      0) break ;;
      *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  7. IPNS
# ══════════════════════════════════════════════
menu_ipns() {
  while true; do
    header
    echo "${YELLOW}[ IPNS / KEYS ]${RESET}"
    echo "  1) Publish MFS path to IPNS"
    echo "  2) Resolve IPNS name"
    echo "  3) Refresh key list"
    echo "  4) Generate new key"
    echo "  5) Delete key"
    echo "  0) Back"
    echo
    echo "${CYAN}  Available keys:${RESET}"
    api "key/ls" | jq -r '.Keys[] | "    \(.Id)  \(.Name)"' 2>/dev/null
    echo
    ask "Option: " opt
    case $opt in
      1)
        echo "${CYAN}  Select file or directory from MFS to publish:${RESET}"
        seleccionar_mfs_origen
        [ -z "$MFS_ORIGEN" ] && pause && continue
        local cid_pub
        cid_pub=$(api "files/stat?arg=$(urlencode "$MFS_ORIGEN")" \
          | jq -r '.Hash // empty' 2>/dev/null)
        if [ -z "$cid_pub" ]; then
          echo "${RED}❌ Could not get CID for $MFS_ORIGEN${RESET}"
          pause; continue
        fi
        clear; header
        echo "${CYAN}  MFS path: $MFS_ORIGEN${RESET}"
        echo "${CYAN}  CID:      $cid_pub${RESET}"
        echo
        echo "${YELLOW}  Available keys:${RESET}"
        api "key/ls" | jq -r '.Keys[] | "    \(.Id)  \(.Name)"' 2>/dev/null
        echo
        ask "Key name (Enter = self): " key_name
        key_name="${key_name:-self}"
        apij "name/publish?arg=$(urlencode "/ipfs/$cid_pub")&key=$(urlencode "$key_name")"
        pause ;;
      2)
        ask "IPNS name or PeerID: " name
        apij "name/resolve?arg=$(urlencode "$name")"
        pause ;;
      3)
        echo "${GREEN}List refreshed.${RESET}"; sleep 1 ;;
      4)
        ask "New key name: " name
        apij "key/gen?arg=$(urlencode "$name")"
        pause ;;
      5)
        ask "Key name to delete: " name
        apij "key/rm?arg=$(urlencode "$name")"
        pause ;;
      0) break ;;
      *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
  done
}

# ══════════════════════════════════════════════
#  8. CUSTOM COMMAND
# ══════════════════════════════════════════════
menu_custom() {
  while true; do
    header
    echo "${YELLOW}[ CUSTOM RPC COMMAND ]${RESET}"
    echo "  Type the RPC endpoint and parameters."
    echo "  Example: ${CYAN}files/stat?arg=/self${RESET}"
    echo "  Example: ${CYAN}swarm/peers${RESET}"
    echo "  Example: ${CYAN}pin/ls?type=recursive${RESET}"
    echo "  Example: ${CYAN}name/resolve?arg=/ipns/k51...${RESET}"
    echo "  Type '0' to go back."
    echo
    ask "api/v0/ > " cmd
    [ "$cmd" = "0" ] && break
    apij "$cmd"
    pause
  done
}

# ══════════════════════════════════════════════
#  MAIN MENU
# ══════════════════════════════════════════════
while true; do
  header
  echo "  1) Node info"
  echo "  2) Files (add / get / cat)"
  echo "  3) MFS (browse / cp / mv / rm)"
  echo "  4) Pins"
  echo "  5) Network / Swarm"
  echo "  6) Repository & GC"
  echo "  7) IPNS & Keys"
  echo "  8) Custom command"
  echo
  echo "  0) Exit"
  echo
  ask "Option: " opt
  case $opt in
    1) menu_node ;;
    2) menu_files ;;
    3) menu_mfs ;;
    4) menu_pins ;;
    5) menu_network ;;
    6) menu_repo ;;
    7) menu_ipns ;;
    8) menu_custom ;;
    0) echo "${GREEN}Goodbye.${RESET}"; exit 0 ;;
    *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
  esac
done