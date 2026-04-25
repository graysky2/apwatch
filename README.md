# airlog.sh

A shell script that connects to an OpenWrt access point over SSH and displays all associated Wi-Fi stations, grouped by network (ESSID) and band, with signal quality and negotiated TX rate.

## Sample output

```
  device                    sig    dBm      TX rate

lightsout2.4 [2.4GHz]
  tstat.livingroom ....... ▂▅█   -58 dBm  65 Mbps
  cam.doorbell ........... ▂▅█   -43 dBm  104 Mbps

Amtrack [5GHz]
  tv.bedroom ............. ▂▅_   -75 dBm  468 Mbps
  tv.livingroom .......... ▂▅█   -65 dBm  1080 Mbps

Central [5GHz]
  tv.kidroom ............. ▂__   -84 dBm  648 Mbps

Crosstown [5GHz]
  phone.company .......... ▂▅█   -62 dBm  2401 Mbps
  laptop.company ......... ▂▅█   -59 dBm  2401 Mbps

Lexington [5GHz]
  phone.wife ............. ▂▅█   -47 dBm  1200 Mbps
  phone.kid .............. ▂▅█   -59 dBm  2401 Mbps
  phone.mine ............. ▂▅█   -58 dBm  2401 Mbps
  laptop.wife ............ ▂▅█   -60 dBm  2401 Mbps

guest [5GHz]
  (no stations)

lightsout [5GHz]
  camera.window .......... ▂▅_   -74 dBm  780 Mbps
  camera.backdoor ........ ▂▅█   -65 dBm  780 Mbps
```

**Signal bars:**

| Bar   | Range        | Meaning  |
|-------|--------------|----------|
| `▂▅█` | > −67 dBm   | Strong   |
| `▂▅_` | −67 to −80 dBm | Moderate |
| `▂__` | < −80 dBm   | Weak     |

When run in a terminal, bar and dBm values are colored green / yellow / red respectively. TX rate is dimmed. Network names are bold.

The `---` TX rate indicates the driver did not report a negotiated rate for that station, which is normal for idle or low-traffic clients on some chipsets.

Networks are sorted alphabetically within each band. Stations are sorted alphabetically within each network. 2.4 GHz networks always appear before 5 GHz.

---

## Dependencies

**Client machine** (where you run the script):
- `bash`
- `awk` (any POSIX-compatible: gawk, mawk, nawk)
- `ssh`

**Access point** (remote):
- OpenWrt with `iwinfo` installed (included by default on most OpenWrt builds)
- `/etc/ethers` populated for friendly device names (optional — falls back to MAC address)

---

## Configuration

### SSH access

The only required configuration is pointing the script at your access point. Edit the `SSH_HOST` variable at the top of the script:

```bash
SSH_HOST="192.168.1.1"       # by IP
# or
SSH_HOST="my-router.lan"     # by hostname
```

If you connect as `root` (standard on OpenWrt), a `~/.ssh/config` entry on the client avoids being prompted for credentials on every run:

```
Host my-router.lan
    User root
    IdentityFile ~/.ssh/id_ed25519
```

### Device names — `/etc/ethers` on the access point

Without `/etc/ethers`, associated stations display by MAC address. Populate it to get friendly names instead.

Each line is a MAC address followed by a hostname, separated by whitespace:

```
# /etc/ethers
DC:A6:32:00:11:22  pi5.home
F4:5C:89:AA:BB:CC  laptop.mine
3C:22:FB:DD:EE:FF  iphone.wife
00:11:22:33:44:55  printer.office
```

Changes take effect on the next run of `airlog` — no service restart needed.

---

## Usage

```bash
chmod +x airlog.sh
./airlog.sh
```

Or place it somewhere on your `$PATH`:

```bash
cp airlog.sh ~/bin
airlog
```

Output is colorized automatically when writing to a terminal, and plain text when piped or redirected.

---
