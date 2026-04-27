#!/usr/bin/env bash
SSH_HOST="serenity-AP.lan"
TMPFILE="/tmp/ap.txt"

if ! ssh "$SSH_HOST" '
    echo "###ETHERS###"
    cat /etc/ethers
    echo "###IWINFO###"
    iwinfo_out=$(iwinfo)
    printf "%s\n" "$iwinfo_out"
    printf "%s\n" "$iwinfo_out" | awk "/^phy[0-9]/ {print \$1}" | while read -r iface; do
        printf "###IFACE:%s###\n" "$iface"
        iwinfo "$iface" assoclist 2>/dev/null
    done
' > "$TMPFILE"; then
    echo "Error: SSH connection to $SSH_HOST failed" >&2
    exit 1
fi

[ -t 1 ] && use_color=1 || use_color=0

awk -v USE_COLOR="$use_color" '
BEGIN {
    if (USE_COLOR) {
        BOLD   = "\033[1m"
        DIM    = "\033[2m"
        GREEN  = "\033[32m"
        YELLOW = "\033[33m"
        RED    = "\033[31m"
        RESET  = "\033[0m"
    }
}

/^###ETHERS###$/ { section = "ethers"; next }
/^###IWINFO###$/ { section = "iwinfo"; cur_iface = ""; next }
/^###IFACE:/ {
    iface = $0
    sub(/^###IFACE:/, "", iface)
    sub(/###$/, "",    iface)
    section = "iface"
    cur = iface
    if (!(cur in seen)) {
        iface_order[++iface_count] = cur
        seen[cur] = 1
        station_count[cur] = 0
    }
    next
}

section == "ethers" {
    if ($0 ~ /^[[:space:]]*#/ || NF < 2) next
    ethers[toupper($1)] = $2
}

section == "iwinfo" {
    if (/^phy[0-9]/) {
        cur_iface = $1
        s = $0
        if (match(s, /ESSID: "/)) {
            s = substr(s, RSTART + 8)   # skip past ESSID: "
            sub(/".*/, "", s)           # strip closing quote and tail
            essid[cur_iface] = (s == "" || s == "unknown") ? "" : s
        }
    } else if (cur_iface != "" && /GHz\)/) {
        s = $0
        if (match(s, /[0-9]+\.[0-9]+ GHz/)) {
            freq_str = substr(s, RSTART)
            sub(/ GHz.*/, "", freq_str)
            freq_num = freq_str + 0
        iface_band[cur_iface] = (freq_num < 3.0) ? "2.4GHz" : (freq_num < 5.9) ? "5GHz" : "6GHz"
        }
    }
}

section == "iface" && /^[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:/ {
    mac  = toupper($1)
    rssi = $2 + 0
    s = $0
    sub(/.*\(SNR /, "", s)
    sub(/\).*/, "",    s)
    snr = s + 0
    n = ++station_count[cur]
    smac[cur,  n] = mac
    srssi[cur, n] = rssi
    ssnr[cur,  n] = snr
    stx[cur,   n] = 0
    cur_station    = n
}

section == "iface" && /[[:space:]]TX:/ && cur_station > 0 {
    s = $0
    sub(/.*TX:[[:space:]]*/, "", s)
    sub(/[[:space:]].*/, "", s)
    stx[cur, cur_station] = int(s + 0)
}

function dot_pad(name, width,    pad, i) {
    pad = ""
    for (i = length(name); i < width - 1; i++) pad = pad "."
    return name " " pad
}

function get_band(iface) {
    if (iface in iface_band) return iface_band[iface]
    return "5GHz"   # fallback: phy numbering is unreliable on tri-band; 5GHz is safest default
}

function print_iface(iface,    display, band, header, j, k, mac, rssi, name, bar, padded,
                               n, names, order, tmp) {
    display = (essid[iface] != "") ? essid[iface] : iface
    band    = get_band(iface)
    header  = display " [" band "]"
    printf "\n%s%s%s\n", BOLD, header, RESET
    n = station_count[iface]
    if (n == 0) {
        printf "  %s(no stations)%s\n", DIM, RESET
        return
    }
    # Resolve display names and build index array for sorting
    for (j = 1; j <= n; j++) {
        mac      = smac[iface, j]
        names[j] = (mac in ethers) ? ethers[mac] : mac
        order[j] = j
    }
    # Bubble sort order[] by names[] alphabetically
    for (j = 1; j <= n; j++) {
        for (k = j+1; k <= n; k++) {
            if (names[order[j]] > names[order[k]]) {
                tmp = order[j]; order[j] = order[k]; order[k] = tmp
            }
        }
    }
    for (j = 1; j <= n; j++) {
        idx   = order[j]
        mac   = smac[iface,  idx]
        rssi  = srssi[iface, idx]
        tx    = stx[iface,   idx]
        name  = names[idx]
        if      (rssi > -67) { bar = GREEN "▂▅█" RESET; clr = GREEN  }
        else if (rssi > -80) { bar = YELLOW "▂▅_" RESET; clr = YELLOW }
        else                 { bar = RED "▂__" RESET;    clr = RED    }
        txstr  = (tx > 0) ? (tx " Mbps") : "---"
        padded = dot_pad(name, NAME_WIDTH)
        printf "  %s %s  %s%4d dBm%s  %s%s%s\n", padded, bar, clr, rssi, RESET, DIM, txstr, RESET
    }
    # Clear local arrays to avoid bleed between calls
    for (j = 1; j <= n; j++) { delete names[j]; delete order[j] }
}

END {
    NAME_WIDTH = 24
    # Single column header at top
    printf "\n  %s%-*s  sig    dBm      TX rate%s\n", DIM, NAME_WIDTH, "device", RESET
    # Bubble-sort iface_order alphabetically by display name (ESSID or iface fallback)
    for (i = 1; i <= iface_count; i++)
        disp[i] = (essid[iface_order[i]] != "") ? essid[iface_order[i]] : iface_order[i]
    for (i = 1; i <= iface_count; i++) {
        for (j = i+1; j <= iface_count; j++) {
            if (disp[i] > disp[j]) {
                tmp = iface_order[i]; iface_order[i] = iface_order[j]; iface_order[j] = tmp
                tmp = disp[i];        disp[i]        = disp[j];        disp[j]        = tmp
            }
        }
    }
    # 2.4 GHz first, then 5 GHz, then 6 GHz — alphabetical within each band
    for (i = 1; i <= iface_count; i++) {
        if (get_band(iface_order[i]) == "2.4GHz") print_iface(iface_order[i])
    }
    for (i = 1; i <= iface_count; i++) {
        if (get_band(iface_order[i]) == "5GHz") print_iface(iface_order[i])
    }
    for (i = 1; i <= iface_count; i++) {
        if (get_band(iface_order[i]) == "6GHz") print_iface(iface_order[i])
    }
}
' "$TMPFILE"
