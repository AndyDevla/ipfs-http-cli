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
