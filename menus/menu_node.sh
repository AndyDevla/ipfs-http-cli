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
