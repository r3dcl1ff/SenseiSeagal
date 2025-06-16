#!/usr/bin/env bash
# =============================================================
#  Sensei Seagal – Rapid Recon Edition
#  -------------------------------------------------------------
#  A high‑speed network enumeration script with Jamaican‑Seagal
#  vibes, BOMBOCLAAT! Adjust RATE / RETRIES / TEMPLATE below to trade speed
#  for stealth on fragile networks.
# =============================================================
set -euo pipefail

# ───────────────  Giving swag to dem bois  ───────────────
RED='\e[31m'; NC='\e[0m'
print_banner() {
  echo -e "${RED}======================================${NC}"
  echo -e "${RED}       Sensei Seagal @RedflareCyber   ${NC}"
  echo -e "${RED}======================================${NC}"
  echo -e "${RED}Strap in, bredren! Ryback rollin' full throttle!${NC}"
}

# ───────────────  Progress Bar see whats cookin'  ───────────────
print_progress() {
  local cur=$1 total=$2 label=$3
  local perc=$(( cur * 100 / total ))
  local filled=$(( perc / 5 ))
  local bar
  bar=$(printf '#%.0s' $(seq 1 $filled))
  bar+=$(printf '.%.0s' $(seq 1 $((20-filled)) ))
  printf "${RED}%-18s [%s] %3d%%${NC}\n" "$label" "$bar" "$perc"
}

# ───────────────  Prompt for Targets, smash 'em all  ───────────────
print_banner
read -rp "Wagwan Bossy?Enter target (CIDR/range) or path to targets file: " TARGET_IN
[[ -z $TARGET_IN ]] && { echo -e "${RED}No target—abortin', mon!${NC}" >&2; exit 1; }
read -rp "Wanna run intrusive vuln scripts? (y/N): " RUN_VULNS
read -rp "Finna run host‑enumeration (hostnames/services)? (y/N): " RUN_HOSTS

# ───────────────  Directory Layout, keep dat loot like a japanese pirate  ───────────────
mkdir -p ips loot/httpx
SERVICES=(ftp ssh telnet smtp httpx kerberos pop3 rpc netbios smb msrpc snmp ldap modbus mssql nfs mysql rdp vnc redis mongodb)
for svc in "${SERVICES[@]}"; do mkdir -p "loot/$svc"; done
mkdir -p loot/vulns loot/hosts

# ───────────────  Speed Profile,we finish fasta den a rastaclaat ninja  ───────────────
RATE=500    # packets/sec — lower this to be less invasive
RETRIES=1   # probe retransmissions
TEMPLATE=4  # Nmap timing template (0‑slow … 5‑fast)
NMAP_OPTS="-T${TEMPLATE} --max-retries ${RETRIES} --min-rate ${RATE} -Pn --open"

# ───────────────  Helper Functions, disredard if you're Casey Ryback  ───────────────
run_nse() {
  local svc="$1" ports="$2" arr_name="$3"
  local -n arr="$arr_name"       
  local total=${#arr[@]} dir="loot/$svc"
  for i in "${!arr[@]}"; do
    local idx=$(( i + 1 )) scr="${arr[$i]}"
    echo -e "${RED}[$svc] $scr …${NC}"
    nmap $NMAP_OPTS -p "$ports" --script "$scr" -iL ips/ips_full.txt \
         -oN "$dir/${scr%.nse}.txt" &>/dev/null
    print_progress $idx $total "$svc"
  done
  nmap $NMAP_OPTS -p "$ports" -iL ips/ips_full.txt -oG "$dir/tmp.grep" &>/dev/null
  grep Up "$dir/tmp.grep" | cut -d ' ' -f2 > "$dir/ip_clean.txt"; rm "$dir/tmp.grep"
  print_progress 1 1 "$svc clean"
}

run_nse_udp() {
  local svc="$1" ports="$2" arr_name="$3"
  local -n arr="$arr_name"
  local total=${#arr[@]} dir="loot/$svc"
  for i in "${!arr[@]}"; do
    local idx=$(( i + 1 )) scr="${arr[$i]}"
    echo -e "${RED}[$svc‑UDP] $scr …${NC}"
    nmap $NMAP_OPTS -sU -p "$ports" --script "$scr" -iL ips/ips_full.txt \
         -oN "$dir/${scr%.nse}.txt" &>/dev/null
    print_progress $idx $total "$svc‑u"
  done
  nmap $NMAP_OPTS -sU -p "$ports" -iL ips/ips_full.txt -oG "$dir/tmp.grep" &>/dev/null
  grep Up "$dir/tmp.grep" | cut -d ' ' -f2 > "$dir/ip_clean.txt"; rm "$dir/tmp.grep"
  print_progress 1 1 "$svc clean"
}

# ───────────────  1) Ping Sweep like a 10th Degree Black Belt ───────────────
echo -e "${RED}Kickin' ping sweep—lightnin' fast!${NC}"
if [[ -f $TARGET_IN ]]; then
  nmap $NMAP_OPTS -sn -iL "$TARGET_IN" -oG ping.raw &>/dev/null
else
  nmap $NMAP_OPTS -sn "$TARGET_IN" -oG ping.raw &>/dev/null
fi
grep Up ping.raw | cut -d ' ' -f2 > ips/ips_full.txt; rm ping.raw
LIVE=$(wc -l < ips/ips_full.txt)
[[ $LIVE -eq 0 ]] && { echo -e "${RED}No live hosts—nothin' to scan, mon!${NC}"; exit 0; }
print_progress 1 1 "Ping"

# ───────────────  2) Host Enumeration (Optional, only if the mission allows it)  ───────────────
if [[ ${RUN_HOSTS,,} == y* ]]; then
  echo -e "${RED}Collectin' OS & hostnames…${NC}"
  nmap $NMAP_OPTS -O -sV -iL ips/ips_full.txt -oN loot/hosts/hostname_os.txt &>/dev/null
  print_progress 1 1 "Host‑enum"
fi

# ───────────────  3) Check common services and F them up like Jah ───────────────
ftp_scripts=(ftp-anon.nse tftp-version.nse ftp-vsftpd-backdoor.nse ftp-syst.nse ftp-vuln-cve2010-4221.nse ftp-proftpd-backdoor.nse)
ssh_scripts=(ssh-publickey-acceptance.nse ssh-auth-methods.nse ssh-run.nse sshv1.nse ssh-hostkey.nse)
telnet_scripts=(telnet-ntlm-info.nse telnet-encryption.nse)
smtp_scripts=(smtp-enum-users.nse smtp-vuln-cve2011-1764.nse smtp-ntlm-info.nse netbus-info.nse smtp-strangeport.nse smtp-open-relay.nse smtp-commands.nse smtp-vuln-cve2011-1720.nse)

run_nse ftp    "21,2121" ftp_scripts
run_nse ssh    "22,2222" ssh_scripts
run_nse telnet "23,2323" telnet_scripts
run_nse smtp   "25,2525" smtp_scripts

# ───────────────  4) HTTPX Quick Check, might want to use the list for Burp or enumerate with -server and -td flag  ───────────────
echo -e "${RED}HTTPX fly‑by…${NC}"
PORTS_WEB="80,81,82,88,443,4443,4433,8080,8000,7000,7070,6379,9000"
cat ips/ips_full.txt | httpx -silent -mc 200 -p "$PORTS_WEB" -o loot/httpx/httpx.txt
print_progress 1 1 "httpx"

# ───────────────  5) Finish the Job Soke Seagal!!  ───────────────
kerb_scripts=(krb5-enum-users.nse)
pop3_scripts=(pop3-ntlm-info.nse pop3-capabilities.nse)
rpc_scripts=(nfs-statfs.nse rpcap-info.nse rpc-grind.nse nfs-showmount.nse)
netbios_scripts=(nbns-interfaces.nse nbstat.nse broadcast-netbios-master-browser.nse)
smb_scripts=(smb-vuln-conficker.nse smb-os-discovery.nse samba-vuln-cve-2012-1182.nse smb-vuln-cve-2017-7494.nse smb-vuln-ms08-067.nse smb-vuln-webexec.nse smb-double-pulsar-backdoor.nse smb-enum-groups.nse smb-security-mode.nse smb-protocols.nse smb2-capabilities.nse smb-enum-users.nse smb-vuln-ms06-025.nse smb-enum-sessions.nse smb-enum-processes.nse smb-ls.nse smb-psexec.nse smb2-time.nse smb-server-stats.nse smb-enum-shares.nse smb2-vuln-uptime.nse smb-print-text.nse smb-system-info.nse smb-mbenum.nse)
msrpc_scripts=(msrpc-enum.nse rpcap-info.nse)
snmp_scripts=(snmp-ios-config.nse snmp-interfaces.nse snmp-sysdescr.nse snmp-win32-services.nse snmp-netstat.nse snmp-info.nse snmp-win32-shares.nse snmp-processes.nse)
ldap_scripts=(ldap-rootdse.nse ldap-search.nse ldap-novell-getpass.nse)

run_nse kerberos "88"      kerb_scripts
run_nse pop3    "110,995"  pop3_scripts
run_nse rpc     "111"      rpc_scripts
run_nse netbios "137,138"  netbios_scripts
run_nse smb     "139,445"  smb_scripts
run_nse msrpc   "135"      msrpc_scripts
run_nse snmp    "161"      snmp_scripts
run_nse ldap    "389"      ldap_scripts

# ───────────────  6) Modbus UDP, Sensei likes hot Jamaican poonani  ───────────────
modbus_scripts=(modbus-discover.nse enip-info.nse)
run_nse_udp modbus "502" modbus_scripts

# ───────────────  7) Check dem NFS shares for all da goodies  ───────────────
mssql_scripts=(ms-sql-hasdbaccess.nse ms-sql-info.nse ms-sql-ntlm-info.nse ms-sql-config.nse ms-sql-empty-password.nse ms-sql-query.nse)
nfs_scripts=(nfs-statfs.nse nfs-ls.nse nfs-showmount.nse)
mysql_scripts=(mysql-audit.nse mysql-vuln-cve2012-2122.nse mysql-info.nse mysql-users.nse mysql-query.nse mysql-empty-password.nse mysql-databases.nse mysql-variables.nse mysql-enum.nse mysql-dump-hashes.nse)
rdp_scripts=(rdp-ntlm-info.nse rdp-vuln-ms12-020.nse rdp-enum-encryption.nse)
vnc_scripts=(vnc-info.nse realvnc-auth-bypass.nse)
redis_scripts=(redis-info.nse)
mongodb_scripts=(mongodb-databases.nse mongodb-info.nse)

run_nse mssql  "1433"      mssql_scripts
run_nse nfs    "2049"      nfs_scripts
run_nse mysql  "3306"      mysql_scripts
run_nse rdp    "3389"      rdp_scripts
run_nse vnc    "5800,5900" vnc_scripts
run_nse redis  "6379"      redis_scripts
run_nse mongodb "27017"    mongodb_scripts

# ───────────────  8) Optional Vuln Sweep, fatality like MF Scorpion  ───────────────
if [[ ${RUN_VULNS,,} == y* ]]; then
  echo -e "${RED}Vuln sweep—no mercy now!${NC}"
  nmap $NMAP_OPTS --script vuln -iL ips/ips_full.txt -oN loot/vulns/vuln_all.txt &>/dev/null
  print_progress 1 1 "vuln"
fi

# ───────────────  Time to chillax and enjoy the poonani  ───────────────
echo -e "${RED}Mission complete, mon—coconut water and chill!${NC}"
