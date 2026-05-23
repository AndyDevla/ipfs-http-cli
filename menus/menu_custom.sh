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
