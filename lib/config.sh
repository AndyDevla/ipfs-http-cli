prompt_for_credentials() {
  echo
  echo "  Please enter your IPFS credentials."
  local raw_url
  while true; do
    read -p "  Domain or IP (e.g. yourdomain.net): " raw_url
    raw_url="${raw_url#http://}"
    raw_url="${raw_url#https://}"
    raw_url="${raw_url%/}"
    [ -n "$raw_url" ] && break
    echo "    Value required."
  done
  IPFS_API_URL="https://${raw_url}"

  while true; do
    read -p "  Username: " IPFS_USER
    [ -n "$IPFS_USER" ] && break
    echo "    Value required."
  done

  while true; do
    read -s -p "  Password: " IPFS_PASS
    echo
    [ -n "$IPFS_PASS" ] && break
    echo "    Value required."
  done

  save_config
}

save_config() {
  cat > "$CONFIG_FILE" <<EOF
IPFS_API_URL="${IPFS_API_URL}"
IPFS_USER="${IPFS_USER}"
IPFS_PASS="${IPFS_PASS}"
EOF
}

load_config() {
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
    prompt_for_credentials
    source "$CONFIG_FILE"
  else
    source "$CONFIG_FILE"
    local missing_vars=()
    for var in IPFS_API_URL IPFS_USER IPFS_PASS; do
      [ -z "${!var}" ] && missing_vars+=("$var")
    done
    if [ ${#missing_vars[@]} -gt 0 ]; then
      echo "${YELLOW}  Some credentials are missing: ${missing_vars[*]}. Please re-enter them.${RESET}"
      prompt_for_credentials
      source "$CONFIG_FILE"
    fi
  fi
}
