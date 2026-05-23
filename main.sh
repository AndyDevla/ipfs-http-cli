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

source lib/api.sh
source lib/config.sh

# ──────────────────────────────
#  UI utilities
# ──────────────────────────────
pause() { echo; read -p "Press Enter to continue..."; }
ask()   { read -p "$1" "$2"; }

header() {
  clear
  echo "${CYAN}"
  echo "    ╔══════════════════════════════════════════════╗"
  echo "    ║           🪐  IPFS Node Manager              ║"
  echo "    ╚══════════════════════════════════════════════╝"
  echo ""
  echo "      API: ${GREEN}${IPFS_API_URL}${CYAN}"
  echo "      User: ${GREEN}${IPFS_USER}${RESET}"
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
#  MENUS
# ══════════════════════════════════════════════
source menus/menu_node.sh
source menus/menu_files.sh
source menus/menu_mfs.sh
source menus/menu_pins.sh
source menus/menu_network.sh
source menus/menu_repo.sh
source menus/menu_ipns.sh
source menus/menu_custom.sh
load_config
# ══════════════════════════════════════════════
#  MAIN MENU
# ══════════════════════════════════════════════
while true; do
  header
  echo "          1. Node info"
  echo "          2. Files (add / get / cat)"
  echo "          3. MFS (files ls / cp / rm...)"
  echo "          4. Pins"
  echo "          5. Network / Swarm"
  echo "          6. Repository & GC"
  echo "          7. IPNS & keys"
  echo "          8. Custom command"
  echo
  echo "          0 -> Exit"
  echo
  ask "                       Option: " opt
  case $opt in
    1) menu_node ;;
    2) menu_files ;;
    3) menu_mfs ;;
    4) menu_pins ;;
    5) menu_network ;;
    6) menu_repo ;;
    7) menu_ipns ;;
    8) menu_custom ;;
    0) echo ""; exit 0 ;;
    *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
  esac
done
