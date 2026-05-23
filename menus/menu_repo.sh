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
