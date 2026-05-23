# ══════════════════════════════════════════════
#  2. FILES
# ══════════════════════════════════════════════
menu_files() {
  while true; do
    header
    echo "${YELLOW}[ FILES ]${RESET}"
    echo "  1) Upload file to IPFS only"
    echo "  2) Upload directory to IPFS only"
    echo "  3) Add file → IPFS + MFS"
    echo "  4) Add directory → IPFS + MFS"
    echo "  5) Download from MFS to local"
    echo "  6) Download content by CID"
    echo "  7) View content by CID (cat)"
    echo "  8) List CID links (ls)"
    echo "  9) DAG stats"
    echo " 10) Export DAG as .car"
    echo " 11) Import .car"
    echo "  0) Back"
    echo
    ask "Option: " opt
    case $opt in
      1)
        local _last_dir="/home"
        ask "  wrap-with-directory? (y/n) [y]: " wrap_ans
        [[ -z "$wrap_ans" || "$wrap_ans" =~ ^[Yy]$ ]] && wrap="true" || wrap="false"
        ask "  only-hash (dry run, no upload)? (y/n) [n]: " hash_ans
        [[ "$hash_ans" =~ ^[Yy]$ ]] && ohash="true" || ohash="false"
        while true; do
          seleccionar_ruta "file" "$_last_dir"
          [ -z "$RUTA_SELECCIONADA" ] && break
          _last_dir=$(dirname "$RUTA_SELECCIONADA")
          local file_name
          file_name=$(basename "$RUTA_SELECCIONADA")
          echo "${GREEN}Uploading: $RUTA_SELECCIONADA${RESET}"
          local resp
          resp=$(curl -s -X POST \
            -u "$IPFS_USER:$IPFS_PASS" \
            -F "file=@${RUTA_SELECCIONADA};filename=${file_name}" \
            "${IPFS_API_URL}/api/v0/add?quieter=true&progress=true&${ADD_DEFAULTS}&wrap-with-directory=${wrap}&only-hash=${ohash}")
          local cid
          cid=$(echo "$resp" | tail -1 | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid" ]; then
            echo "${RED}❌ Upload failed:${RESET}"; echo "$resp" | jq . 2>/dev/null
          else
            echo "${GREEN}✅ CID: $cid${RESET}"
          fi
          echo
          ask "Continue uploading files? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      2)
        local _last_dir="/home"
        ask "  only-hash (dry run, no upload)? (y/n) [n]: " hash_ans
        [[ "$hash_ans" =~ ^[Yy]$ ]] && ohash="&only-hash=true" || ohash=""
        while true; do
          seleccionar_ruta "directory" "$_last_dir"
          [ -z "$RUTA_SELECCIONADA" ] && break
          _last_dir=$(dirname "$RUTA_SELECCIONADA")
          echo "${GREEN}Uploading directory: $RUTA_SELECCIONADA${RESET}"
          echo "${YELLOW}(may take several minutes for large directories)${RESET}"
          local resp
          resp=$(add_dir_api "$RUTA_SELECCIONADA" "$ohash")
          local cid
          cid=$(echo "$resp" | tail -1 | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid" ]; then
            echo "${RED}❌ Upload failed:${RESET}"; echo "$resp" | jq . 2>/dev/null
          else
            echo "${GREEN}✅ CID: $cid${RESET}"
          fi
          echo
          ask "Continue uploading directories? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      3)
        local _last_dir="/home"
        while true; do
          seleccionar_ruta "file" "$_last_dir"
          [ -z "$RUTA_SELECCIONADA" ] && break
          _last_dir=$(dirname "$RUTA_SELECCIONADA")
          local file_name
          file_name=$(basename "$RUTA_SELECCIONADA")
          seleccionar_mfs "$file_name"
          [ -z "$MFS_SELECCIONADO" ] && break
          echo "${GREEN}Uploading: $RUTA_SELECCIONADA${RESET}"
          local resp
          resp=$(curl -s -X POST \
            -u "$IPFS_USER:$IPFS_PASS" \
            -F "file=@${RUTA_SELECCIONADA};filename=${file_name}" \
            "${IPFS_API_URL}/api/v0/add?quieter=true&progress=true&${ADD_DEFAULTS}")
          local cid
          cid=$(echo "$resp" | tail -1 | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid" ]; then
            echo "${RED}❌ Upload failed:${RESET}"; echo "$resp" | jq . 2>/dev/null
            echo; ask "Continue uploading files? (y/n): " _again
            [[ "$_again" =~ ^[Yy]$ ]] || break; continue
          fi
          echo "${GREEN}CID: $cid${RESET}"
          local cp_resp
          cp_resp=$(api "files/cp?arg=$(urlencode "/ipfs/$cid")&arg=$(urlencode "$MFS_SELECCIONADO")")
          check_err "$cp_resp" && echo "${GREEN}✅ Saved to MFS: $MFS_SELECCIONADO${RESET}"
          echo
          ask "Continue uploading files? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      4)
        local _last_dir="/home"
        while true; do
          seleccionar_ruta "directory" "$_last_dir"
          [ -z "$RUTA_SELECCIONADA" ] && break
          _last_dir=$(dirname "$RUTA_SELECCIONADA")
          local dir_name
          dir_name=$(basename "$RUTA_SELECCIONADA")
          seleccionar_mfs "$dir_name"
          [ -z "$MFS_SELECCIONADO" ] && break
          ask "Add without pin? (y/n): " nopin
          local extra=""
          [[ "$nopin" =~ ^[Yy]$ ]] && extra="&pin=false"
          echo "${GREEN}Uploading directory: $RUTA_SELECCIONADA${RESET}"
          echo "${YELLOW}(may take several minutes for large directories)${RESET}"
          local resp
          resp=$(add_dir_api "$RUTA_SELECCIONADA" "$extra")
          local cid
          cid=$(echo "$resp" | tail -1 | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid" ]; then
            echo "${RED}❌ Upload failed:${RESET}"; echo "$resp" | jq . 2>/dev/null
            echo; ask "Continue uploading directories? (y/n): " _again
            [[ "$_again" =~ ^[Yy]$ ]] || break; continue
          fi
          echo "${GREEN}CID: $cid${RESET}"
          local cp_resp
          cp_resp=$(api "files/cp?arg=$(urlencode "/ipfs/$cid")&arg=$(urlencode "$MFS_SELECCIONADO")")
          check_err "$cp_resp" && echo "${GREEN}✅ Saved to MFS: $MFS_SELECCIONADO${RESET}"
          echo
          ask "Continue uploading directories? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      5)
        local _last_mfs="/"
        while true; do
          seleccionar_mfs_origen "$_last_mfs"
          [ -z "$MFS_ORIGEN" ] && break
          _last_mfs=$(dirname "$MFS_ORIGEN")
          [ -z "$_last_mfs" ] && _last_mfs="/"
          local cid_src
          cid_src=$(api "files/stat?arg=$(urlencode "$MFS_ORIGEN")" \
            | jq -r '.Hash // empty' 2>/dev/null)
          if [ -z "$cid_src" ]; then
            echo "${RED}❌ Could not get CID for $MFS_ORIGEN${RESET}"
            pause; break
          fi
          echo "${CYAN}  MFS source: $MFS_ORIGEN${RESET}"
          echo "${CYAN}  CID:        $cid_src${RESET}"
          echo
          seleccionar_ruta "directory"
          [ -z "$RUTA_SELECCIONADA" ] && break
          local base_name
          base_name=$(basename "$MFS_ORIGEN")
          local dest="$RUTA_SELECCIONADA/$base_name"
          mkdir -p "$dest"
          echo "${GREEN}Downloading to: $dest${RESET}"
          local tmpdir
          tmpdir=$(mktemp -d)
          curl -s -X POST \
            -u "$IPFS_USER:$IPFS_PASS" \
            "${IPFS_API_URL}/api/v0/get?arg=$(urlencode "/ipfs/$cid_src")" \
            | tar -x -C "$tmpdir"
          local extracted
          extracted=$(ls "$tmpdir" 2>/dev/null | head -1)
          if [ -n "$extracted" ]; then
            local src_path="$tmpdir/$extracted"
            if [ -d "$src_path" ]; then cp -r "$src_path/." "$dest"
            else mv "$src_path" "$dest"; fi
            echo "${GREEN}✅ Saved to: $dest${RESET}"
          else
            echo "${RED}❌ Could not extract content${RESET}"
          fi
          rm -rf "$tmpdir"
          echo
          ask "Continue downloading? (y/n): " _again
          [[ "$_again" =~ ^[Yy]$ ]] || break
        done
        pause ;;

      6)
        ask "CID to download: " cid
        seleccionar_ruta "directory"
        [ -z "$RUTA_SELECCIONADA" ] && pause && continue
        local tmpdir
        tmpdir=$(mktemp -d)
        echo "${GREEN}Downloading CID: $cid${RESET}"
        curl -s -X POST \
          -u "$IPFS_USER:$IPFS_PASS" \
          "${IPFS_API_URL}/api/v0/get?arg=$(urlencode "$cid")" \
          | tar -x -C "$tmpdir"
        local extracted
        extracted=$(ls "$tmpdir" 2>/dev/null | head -1)
        if [ -n "$extracted" ]; then
          mv "$tmpdir/$extracted" "$RUTA_SELECCIONADA/"
          echo "${GREEN}✅ Saved to: $RUTA_SELECCIONADA/$extracted${RESET}"
        else
          echo "${RED}❌ Could not extract content${RESET}"
        fi
        rm -rf "$tmpdir"
        pause ;;

      7)
        ask "CID or path: " cid
        api "cat?arg=$(urlencode "$cid")"
        echo; pause ;;

      8)
        ask "CID or path: " cid
        apij "ls?arg=$(urlencode "$cid")"
        pause ;;

      9)
        ask "CID: " cid
        apij "dag/stat?arg=$(urlencode "$cid")"
        pause ;;

      10)
        ask "Root CID: " cid
        ask "Output file (.car): " out
        curl -s -X POST \
          -u "$IPFS_USER:$IPFS_PASS" \
          "${IPFS_API_URL}/api/v0/dag/export?arg=$(urlencode "$cid")" > "$out"
        echo "${GREEN}✅ Exported to: $out${RESET}"
        pause ;;

      11)
        ask ".car file path: " car_file
        curl -s -X POST \
          -u "$IPFS_USER:$IPFS_PASS" \
          -F "file=@${car_file}" \
          "${IPFS_API_URL}/api/v0/dag/import" | jq .
        pause ;;

      0) break ;;
      *) echo "${RED}Invalid option${RESET}"; sleep 1 ;;
    esac
  done
}
