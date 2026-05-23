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
