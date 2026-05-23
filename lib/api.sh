ADD_DEFAULTS="preserve-mode=true&preserve-mtime=true&cid-version=1"

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

api() {
  local endpoint="$1"; shift
  curl -s -X POST \
    -u "$IPFS_USER:$IPFS_PASS" \
    "$@" \
    "${IPFS_API_URL}/api/v0/${endpoint}"
}

apij() {
  local endpoint="$1"; shift
  local resp
  resp=$(api "$endpoint" "$@")
  if [ -n "$resp" ]; then
    echo "$resp" | jq . 2>/dev/null || echo "$resp"
  fi
}

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
