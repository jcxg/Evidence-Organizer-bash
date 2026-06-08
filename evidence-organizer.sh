#!/usr/bin/env bash
# ============================================================
# evidence-organizer.sh — Pentest Evidence Organizer
# ============================================================

set -euo pipefail

SOURCE="${1:?Usage: $0 <source_dir> <output_dir> [tags...]}"
OUTPUT="${2:?Usage: $0 <source_dir> <output_dir> [tags...]}"
shift 2
EXTRA_TAGS=("$@")

SUPPORTED_EXT="txt|md|log|out|nmap|gnmap|png|jpg|jpeg|gif|pdf|xml|json|html|csv"

extract_ip() {
    grep -oE '([0-9]{1,3}[._]){3}[0-9]{1,3}' <<< "$1" | \
        sed 's/_/./g' | \
        awk -F. '$1<=255 && $2<=255 && $3<=255 && $4<=255 {print; exit}'
}

extract_port() {
    grep -oP '(?<=p|port|:)(\d{2,5})(?=[_\-\s]|$)' <<< "${1,,}" | \
        awk '$1>=1 && $1<=65535 {print; exit}'
}

port_to_service() {
    case "$1" in
        21) echo ftp;;   22) echo ssh;;    23) echo telnet;;
        25) echo smtp;;  53) echo dns;;    80) echo http;;
        139|445) echo smb;; 389) echo ldap;; 443) echo https;;
        1433) echo mssql;; 3306) echo mysql;; 3389) echo rdp;;
        5432) echo postgres;; 5985) echo winrm;; 6379) echo redis;;
        8080) echo http-alt;; 8443) echo https-alt;;
        27017) echo mongodb;; *) echo svc;;
    esac
}

extract_finding() {
    local name="${1,,}"
    local -A kw=(
        [sqli]="sqli"         [sql]="sqli"          [xss]="xss"
        [rce]="rce"           [exec]="rce"           [cmd]="rce"
        [lfi]="lfi"           [rfi]="rfi"            [traversal]="path-traversal"
        [privesc]="privesc"   [priv_esc]="privesc"   [sudo]="privesc"
        [suid]="privesc"      [escalat]="privesc"
        [kerberoast]="kerberoasting"                 [asrep]="asreproasting"
        [ntlm]="ntlm-relay"  [relay]="ntlm-relay"   [smb]="smb"
        [cred]="credential"  [spray]="password-spray" [brute]="brute-force"
        [hash]="hash-crack"  [crack]="hash-crack"
        [nmap]="recon"       [scan]="recon"          [enum]="recon"
        [banner]="recon"     [version]="recon"
        [shell]="shell"      [revshell]="shell"      [beacon]="c2"
        [exfil]="exfiltration" [ssrf]="ssrf"         [xxe]="xxe"
        [ssti]="ssti"        [upload]="file-upload"  [idor]="idor"
        [bypass]="broken-authn" [deser]="deserialization"
        [mitm]="mitm"        [pivot]="pivoting"
        [note]="note"        [log]="log"             [output]="output"
    )
    for kw_key in "${!kw[@]}"; do
        [[ "$name" == *"$kw_key"* ]] && echo "${kw[$kw_key]}" && return
    done
    echo "misc"
}
-
organize_file() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")

    # Skip sidecar files
    [[ "$filename" == *.meta.json ]] && return

    local host port service finding folder dest
 
    host=$(extract_ip "$filename")
    [[ -z "$host" ]] && host=$(extract_ip "$(basename "$(dirname "$filepath")")")
    [[ -z "$host" ]] && host="unknown-host"

    port=$(extract_port "$filename")
    finding=$(extract_finding "${filename%.*}")

    if [[ -n "$port" ]]; then
        service=$(port_to_service "$port")
        folder="${OUTPUT}/${host}/${port}-${service}/${finding}"
    else
        folder="${OUTPUT}/${host}/${finding}"
    fi

    mkdir -p "$folder"

    local safe_host="${host//./_}"
    local port_part=""
    [[ -n "$port" ]] && port_part="_p${port}"
    dest="${folder}/${safe_host}${port_part}_${finding}_${filename}"

    local counter=1
    local base_dest="$dest"
    local ext="${filename##*.}"
    while [[ -e "$dest" ]]; do
        dest="${base_dest%.${ext}}_${counter}.${ext}"
        ((counter++))
    done

    cp "$filepath" "$dest"

    local tags_arr=("${EXTRA_TAGS[@]:-}" "$finding")
    local tags_json
    tags_json=$(printf '"%s",' "${tags_arr[@]}" | sed 's/,$//')
    cat > "${dest}.meta.json" << JSON
{
  "original_path": "${filepath}",
  "organized_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "host": "${host}",
  "port": "${port:-null}",
  "service": "${service:-null}",
  "finding_type": "${finding}",
  "tags": [${tags_json}]
}
JSON

    printf "  \033[32m✓\033[0m %-45s → %s\n" "$filename" "${dest#${OUTPUT}/}"
}

main() {
    echo ""
    echo "  🔍 Evidence Organizer"
    echo "  ─────────────────────────────────────────"
    printf "  Source : %s\n" "$SOURCE"
    printf "  Output : %s\n" "$OUTPUT"
    [[ ${#EXTRA_TAGS[@]} -gt 0 ]] && printf "  Tags   : %s\n" "${EXTRA_TAGS[*]}"
    echo "  ─────────────────────────────────────────"
    echo ""

    mkdir -p "$OUTPUT"

    local count=0
    while IFS= read -r -d '' filepath; do
        organize_file "$filepath"
        ((count++))
    done < <(find "$SOURCE" -type f -regextype posix-extended \
        -iregex ".*\.(${SUPPORTED_EXT})" -print0)

    echo ""
    printf "  \033[32m✓ Organized %d files into %s\033[0m\n" "$count" "$OUTPUT"
    echo ""
    echo "  Hosts discovered:"
    find "$OUTPUT" -mindepth 1 -maxdepth 1 -type d | sort | while read -r d; do
        local n
        n=$(find "$d" -type f ! -name "*.meta.json" | wc -l)
        printf "    \033[36m%-20s\033[0m %d files\n" "$(basename "$d")" "$n"
    done
    echo ""
}

main
