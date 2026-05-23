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
