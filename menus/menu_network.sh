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
