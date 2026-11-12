#!/bin/bash

###################################### 
#
# Check/repair/install the wpa_supplicant setup on UDM hardware
#
####################################### 
# Backup folder structure
# $backupPath
#  - $libpcspkg
#  - $wpapkg
#  - CA.pem
#  - Client.pem
#  - PrivateKey.pem
#  - wpa_supplicant.conf(Can be created if not found)
####################################### 

## USER VARIABLES ##

# FULL PATH to "backup" folder
backupPath="/root/config"

# Names of install deb files
libpcspkg="libpcsclite1_1.9.1-1_arm64.deb"
wpapkg="wpasupplicant_2.9.0-21_arm64.deb"

# Internet (ONT) interface MAC address (Pulled from cert extraction process)
# Exmaple: inetONTmac="00:00:00:00:00:00"
inetONTmac=""

# Certficate variables
CA_filename="CA.pem"
Client_filename="Client.pem"
PrivateKey_filename="PrivateKey.pem"

# FULL PATH for wpa_supplicant.conf
confPath="/etc/wpa_supplicant/conf"

# FULL PATH for cert storage
certPath="/etc/wpa_supplicant/conf"

# FULL PATH for deb package storage
debPath="/etc/wpa_supplicant/packages"

####################################### 
##    DO NOT EDIT BELOW THIS LINE    ##
####################################### 
# Load external variable file
. ${backupPath}/var-wtf-wpa.txt &> /dev/null
wtf_ver="3.0"

# Package sets
deb11_pkgs=(libpcsclite1_1.9.1-1_arm64.deb wpasupplicant_2.9.0-21_arm64.deb)
deb13_pkgs=(libpcsclite1_2.3.3-1_arm64.deb wpasupplicant_2.10-24_arm64.deb)
os_major=$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID%%.*}")
[[ "${os_major}" =~ ^[0-9]+$ ]] || os_major=0
pkg_gen=0
if (( os_major >= 13 )) || dpkg -s libssl3t64 &> /dev/null; then
	pkg_gen=13
	libpcspkg="${deb13_pkgs[0]}"
	wpapkg="${deb13_pkgs[1]}"
elif (( os_major == 11 )) || dpkg -s libssl1.1 &> /dev/null; then
	pkg_gen=11
fi

# Certificate compatibility
ssl_ciphers="DEFAULT@SECLEVEL=0"
conf_changed=""

# Authentication wait
wpa_auth_wait=90
ctrl_line="ctrl_interface=/run/wpa_supplicant"
wpasupp_install=""

full_filename=$(basename -- "$0")
short_filename="${full_filename%.*}"
log_filename="log-${short_filename}.log"

log() {
	# write formatted status messages to $log_filename
	local flag="$1"; shift
	stamp=$(date '+[%F %T]')
	case $flag in
		I) echo "$stamp - INFO: ${*}" >> "$log_filename" ;;
		IF) echo "$stamp - INFO: Found - ${*}" >> "$log_filename" ;;
		IC) echo "$stamp - INFO: Copied - ${*}" >> "$log_filename" ;;
		IP) echo "$stamp - INFO: Parsed - ${*}" >> "$log_filename" ;;
		E) echo "$stamp - ERROR: ${*}" >> "$log_filename" ;;
		ENF) echo "$stamp - ERROR: Not found - ${*}" >> "$log_filename" ;;
		B) echo "$stamp - ${*}"  >> "$log_filename" ;;
	esac
}

log-stream() {
  # used to capture stream output from command responses
  [[ ! -t 0 ]] && while read -r line; do echo "$(date '+[%F %T]') - STREAM: $line" >> "$log_filename"; done
}

display-help()
{
	# Display Help
	script_name=$(basename -- "$0")
	printf "%b %s\\n"
	printf "   %b\\n\\n" "WTF wpa_supplicant script ${CYAN}${wtf_ver}${NC}"
	printf "   %b\\n\\n" "Syntax: ${CYAN}${full_filename} [-i|c|f]${NC}"
	printf "   %b %s\\n\\n" "options:" ""
	printf "   %8s   %s\\n" "-i" "Install/repair & configure the wpa_supplicant service"
	printf "   %8s   %s\\n\\n" "" "Example: ${CYAN}${full_filename} -i${NC}"
	printf "   %8s   %s\\n" "-c" "Does a quick status check of the wpa_supplicant service"
	printf "   %8s   %s\\n\\n" "" "Example: ${CYAN}${full_filename} -c${NC}"
	printf "   %8s   %s\\n" "-f" "forces configuration file rebuild and re-copies your certificates"
	printf "   %8s   %s\\n" "" "Example: ${CYAN}${full_filename} -f${NC}"
	printf "   %8s   %s\\n\\n" "" "Useful for rebuilding after configuration/certificate changes"
	printf "   %8s   %s\\n\\n" "<none>" "Print this Help"
}
# Output colors
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
SILVER=$(tput setaf 7)
NC=$(tput sgr0)
TICK="[${GREEN}✓${NC}]"
CROSS="[${RED}✗${NC}]"
INFO="[i]"

#######################################
# Show a formatted banner with message
# ARGUMENTS:
#   Message to be displayed
# OUTPUTS:
#   Writes formatted string to stdout
####################################### 
banner () {
	local string=$1
	printf "%b \e[4m%s\e[0m\\n" "${INFO}" "${string}" && log B "*** $string ***"
}

#######################################
# Formats script terminal output
# ARGUMENTS:
#   Message type, category, string
# OUTPUTS:
#   Writes formatted string to stdout
####################################### 
output () {
	local flag="$1"
	local category="$2"
	local string="$3"
	case $flag in
		T) printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "${category}:" "${GREEN}${string}${NC}" ;;
		TS) printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "${category}:" "${SILVER}${string}${NC}" ;;
		C) printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "${category}:" "${RED}${string}${NC}" ;;
		I) printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "${category}:" "${NC}${string}${NC}" ;;
		IY) printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "${category}:" "${CYAN}${string}${NC}" ;;
	esac
}

#######################################
# Varifies required variables are set
# RETURN:
#   Status message, exits script if fails
#######################################
check-variable () {
	local varName="$1"
	local varCheck="$2"
	if [ ! -z "${varCheck}" ]; then
		output TS "${varName}" "${varCheck}"; log IF "${varName}: ${varCheck}"
	else
		output C "${varName}" "${varCheck} not set/found - EXITING"; log ENF "${varName}"; exit 1
	fi
}

#######################################
# Identify unifi hardware
# OUTPUTS:
# 	hw_model
# RETURN:
#   Status message, exits script if fails
#######################################
check-hw () {
	if command -V ubnt-device-info 1> /dev/null 2> >(log-stream); then
		local model
		model=$(ubnt-device-info model)
		output IY "Model" "${model}"; log I "Hardware - ${model}"
	else
    	output C "check-hw" "\e[4m UNSUPPORTED HARDWARE - EXITING"; log E "UNSUPPORTED HARDWARE - EXITING"; exit 1
	fi
}

#######################################
# Tries to determine the WAN interface by parsing /data/udapi-config/udapi-net-cfg.json
# OUTPUTS:
#   udapi_wan_int
# RETURN:
#   Status message, exits script if fails
#######################################
parse-wan-int () {
# Checks ubios-udapi-server.state to determine the WAN port
	if [ -f /data/udapi-config/ubios-udapi-server/ubios-udapi-server.state ]; then
		# Parses udapi-net-cfg.json, sorts by .metric and picks the lowest.
		# Fix from @arthurlockman - https://github.com/WhiskeyTang0F0xtr0t/unifi/pull/11
		udapi_wan_int=$(jq -r '.services.wanFailover.wanInterfaces | min_by(.metric) | .interface' /data/udapi-config/udapi-net-cfg.json | awk -F"." '{print $1}')
		if [ -z "${udapi_wan_int}" ] || [ "${udapi_wan_int}" == "null" ]; then
			output C "WAN Int" "No WAN interface found in udapi-net-cfg. Exiting"; log E "No WAN interface found in udapi-net-cfg. Exiting"
			exit 1
		fi
		output IY "WAN Int" "${udapi_wan_int}" && log I "WAN Interface: ${udapi_wan_int}"
	else
		output C "WAN Int" "Could not determine WAN interface from udapi-net-cfg - EXITING"; log E "Could not determine WAN interface from udapi-net-cfg - EXITING"
		exit 1
	fi
}

#######################################
# Checks the WAN interface in the override.conf file
# OUTPUTS:
#   conf-wan-int
# RETURN:
#   Status message, exits script if fails
#######################################
parse-conf-wan-int () {
# Checks WAN port in the override.conf
	if [ -f /etc/systemd/system/wpa_supplicant.service.d/override.conf ]; then
		# Parses override.conf and extracts the wan interface in the command string
		conf_wan_int=$(grep -oP '(?<=-i).*?(?= -c)' < /etc/systemd/system/wpa_supplicant.service.d/override.conf)
		output IY "CONF Int" "${conf_wan_int}" && log I "Override WAN Interface: ${conf_wan_int}"
	else
		output C "CONF Int" "override.conf not found"; log E "override.conf not found"
		conf_wan_int=""
	fi
}

#######################################
# Tries to determine the WAN interface by parsing /data/udapi-config/udapi-net-cfg.json
# OUTPUTS:
#   conf-wan-int
# RETURN:
#   Status message, exits script if fails
#######################################
compare-wan-int () {
# Checks WAN port in the override.conf
if [ "${conf_wan_int}" == "${udapi_wan_int}" ]; then
		output T "Compare Int" "Matched" && log I "Compare WAN Interface: MATCHED"
  else
		output C "Compare Int" "Active WAN interface does not match override.conf"; log E "Active WAN interface does not match override.conf"
		output C "Compare Int" "Please run the script with the -f flag to force a configuration rebuild - EXITING"; log E "Please run the script with the -f flag to force a configuration rebuild - EXITING"
		exit 1
fi
}

#######################################
# Checks if backupPath exists
# Globals:
#   backupPath
# Outputs:
#   Status message, exits script if fails
#######################################
check-for-path () {
	local checkPathType="$1"
	local checkPath="$2"
	local checkPathOption="$3"
	if [ -d "${checkPath}" ]; then
	   output T "${checkPathType}" "${checkPath}"; log IF "${checkPathType}: ${checkPath}"
	else
		output C "${checkPathType}" "${checkPath}"; log ENF "${checkPathType}: ${backupPath}"
		if [ "$checkPathType" == 'Backup Path' ]; then
			output I "Backup Path" "Please check your backupPath variable and try again. - EXITING"; exit 1
		fi
		if [ "$checkPathOption" == 'restore' ]; then
			create-path "${checkPathType}" "${checkPath}"
		fi
	fi
}

#######################################
# Creates path based on passed parameters
# Outputs:
#   Status message, exits script if fails
#######################################
create-path () {
	local createPathType="$1"
	local createPath="$2"
  output I "${createPathType}" "Attempting to create ${createPath}"; log ENF "Attempting to create ${createPathType} ${createPath}"
  if mkdir -p "${createPath}" &> /dev/null; then
    output T "${createPathType}" "${createPath}"; log I "Created ${createPath}"
  else
    output C "${createPathType}" "Could not create ${createPath}! - EXITING"; log E "Could not create ${createPathType} ${createPath} - EXITING"
    exit 1
  fi
}

#######################################
# Checks if file exists based on passed parameters
# Arguments:
#   FileType FilePath FileName FileOption
# Outputs:
#   Status message
####################################### 
check-for-file () {
	local checkFileType="$1"
	local checkFilePath="$2"
	local checkFileName="$3"
	local checkFileOption="$4"
	if [ -f "${checkFilePath}"/"${checkFileName}" ]; then
		output T "${checkFileType}" "${checkFileName}"; log IF "${checkFileType}: ${checkFilePath}/${checkFileName}"
	else
		output C "${checkFileType}" "${checkFileName} not found"; log ENF "${checkFileType}: ${checkFilePath}/${checkFileName}"
		if [ "$checkFileOption" == 'restore' ]; then
			restore-file "${checkFileType}" "${checkFilePath}" "${checkFileName}"
		fi
	fi
}

#######################################
# Copies file based on passed parameters
# Globals:
#   backupPath
# Arguments:
#   FileType FilePath FileName
# Outputs:
#   Status message
#######################################
restore-file () {
	local restoreFileType="$1"
	local restoreFilePath="$2"
	local restoreFileName="$3"
	output I "${restoreFileType}" "Restoring ${restoreFileName}"; log IF "Restoring ${restoreFileName}"
	if cp "${backupPath}"/"${restoreFileName}" "${restoreFilePath}"/ &> /dev/null; then
		output T "${restoreFileType}" "${restoreFileName}"; log IC "${restoreFileType} ${restoreFilePath}/${restoreFileName}"
	else
		if [ "$restoreFileType" == 'wpa_conf' ]; then
			output C "${restoreFileType}" "Could not copy ${restoreFileName} from ${backupPath}"; log E "Could not copy ${restoreFileName} from ${backupPath}"
			create-wpasupp-conf
		elif [ "$restoreFileType" == 'override' ]; then
			output C "${restoreFileType}" "${restoreFileName} not found in ${restoreFilePath}"; log E "${restoreFileName} not found in ${restoreFilePath}"
			create-overide-conf
		else
			output C "${restoreFileType}" "Could not copy ${restoreFileName} from ${backupPath}"; log E "Could not copy ${restoreFileName} from ${backupPath}"
			output I "${restoreFileType}" "Please check your files and try again."
			exit 1
		fi
	fi
}

#######################################
# Creates  wpa_supplicant.conf in confPath using known variables
# Globals:
#   confPath,backupPath,certPath,CA,Client,inetONTmac,PrivateKey
# Outputs:
#   Status message, ${confPath}/wpa_supplicant.conf if needed
####################################### 
create-wpasupp-conf () {
	output I "wpa_conf" "Building wpa_supplicant.conf from known variables"; log I "Building wpa_supplicant.conf from known variables"
	# Attempts to create ${confPath}/wpa_supplicant.conf from known variables
	printf 'openssl_ciphers='"${ssl_ciphers}"'\n'"${ctrl_line}"'\neapol_version=1\nap_scan=0\nfast_reauth=1\nnetwork={\n''        ca_cert="'"${certPath}"/"${CA_filename}"'"\n''        client_cert="'"${certPath}"/"${Client_filename}"'"\n''        eap=TLS\n        eapol_flags=0\n''        identity="'"${inetONTmac}"'" # Internet (ONT) interface MAC address must match this value\n        key_mgmt=IEEE8021X\n        phase1="allow_canned_success=1"\n        private_key="'"${certPath}"/"${PrivateKey_filename}"'"\n''}\n' > "${confPath}"'/wpa_supplicant.conf' && output T "wpa_conf:" "${confPath}/wpa_supplicant.conf - Created"; log I "${confPath}/wpa_supplicant.conf - Created"
}

#######################################
# Checks if wpa_supplicant service is installed
# RETURN:
#   Status message with version
#######################################
check-wpa-supp-installed () {
# Check if wpa_supplicant is installed with dpkg
	if dpkg -s wpasupplicant 1> /dev/null 2> >(log-stream) ; then
		wpa_supp_ver=$(dpkg -s wpasupplicant | grep -i '^Version' | cut -d' ' -f2)
		output T "Installed" "${wpa_supp_ver}"; log I "wpa_supplicant installed: ${wpa_supp_ver}"
	else
		output C "Installed" "NOT INSTALLED"; log E "wpa_supplicant not installed"; return 1
	fi
}

#######################################
# Checks if wpa_supplicant service is active
# RETURN:
#   Status message
####################################### 
check-wpa-supp-active () {
# Check if wpa_supplicant is active with systemctl
	if systemctl is-active wpa_supplicant 1> /dev/null 2> >(log-stream); then
	   output T "Active" "Yes"; log I "wpa_supplicant is active"
	else
	   output C "Active" "No"; log E "wpa_supplicant is not active"; return 1
	fi
}

#######################################
# Checks if wpa_supplicant service is enabled
# RETURN:
#   Status message
####################################### 
check-wpa-supp-enabled () {
# Check if wpa_supplicant is active with systemctl
	if systemctl is-enabled wpa_supplicant 1> /dev/null 2> >(log-stream); then
	   output T "Enabled" "Yes"; log I "wpa_supplicant is enabled"
	else
	   output C "Enabled" "No"; log E "wpa_supplicant is not enabled"; return 1
	fi
}

#######################################
# Enables wpa_supplicant service
# Outputs:
#   Status message, error output and exits script if failed
####################################### 
wpa-supp-enable () {
# Start and enable the wpa_supplicant service with systemctl
	if systemctl enable wpa_supplicant 1> /dev/null 2> >(log-stream) && systemctl restart wpa_supplicant 1> /dev/null 2> >(log-stream); then
		output T "systemctl" "wpa_supplicant started & enabled"; log I "Started & enabled wpasupplicant"
	else
		output C "systemctl" "wpa_supplicant service could not be enabled - EXITING"; log E "wpa_supplicant service could not be enabled - EXITING"
		exit 1
	fi
}

#######################################
# Package version check
#######################################
check-pkg-current () {
	local pair name want have
	(( pkg_gen == 0 )) && return 0
	for pair in "libpcsclite1:${libpcspkg}" "wpasupplicant:${wpapkg}"; do
		name="${pair%%:*}"
		want=$(dpkg-deb -f "${backupPath}/${pair#*:}" Version 2>/dev/null) || continue
		have=$(dpkg-query -W -f='${Version}' "${name}" 2>/dev/null)
		if [ -z "${have}" ] || dpkg --compare-versions "${have}" lt "${want}"; then
			output C "Packages" "${name} ${have:-missing}, upgrading to ${want}"
			log E "${name} ${have:-missing}, upgrading to ${want}"
			return 1
		fi
	done
	log I "Packages up to date for Debian ${os_major}"
}

#######################################
# Deb store cleanup
#######################################
manage-debs () {
	local f shown=""
	(( pkg_gen == 0 )) && return 0
	if (( pkg_gen == 13 )); then
		for f in "${deb11_pkgs[@]}"; do
			if [ -f "${backupPath}/${f}" ] || [ -f "${debPath}/${f}" ]; then
				[ -z "${shown}" ] && banner "Cleaning up old deb packages" && shown="yes"
				rm -f "${backupPath}/${f}" "${debPath}/${f}"
				output T "deb_pkg" "Removed old Debian 11 package ${f}"; log I "Removed old Debian 11 package ${f}"
			fi
		done
	else
		for f in "${deb13_pkgs[@]}"; do
			if [ ! -f "${backupPath}/${f}" ]; then
				[ -z "${shown}" ] && banner "Checking Debian 13 upgrade packages" && shown="yes"
				output I "deb_pkg" "${f} missing from ${backupPath}"; log ENF "${f}"
			elif [ ! -f "${debPath}/${f}" ]; then
				[ -z "${shown}" ] && banner "Checking Debian 13 upgrade packages" && shown="yes"
				cp "${backupPath}/${f}" "${debPath}/" && output T "deb_pkg" "${f} stored"; log IC "${f}"
			fi
		done
	fi
}

#######################################
# Certificate compatibility
#######################################
ensure-conf-globals () {
	local f line key shown=""
	for f in "${confPath}/wpa_supplicant.conf" "${backupPath}/wpa_supplicant.conf"; do
		[ -f "${f}" ] || continue
		for line in "openssl_ciphers=${ssl_ciphers}" "${ctrl_line}"; do
			key="${line%%=*}"
			grep -q "^[[:space:]]*${key}=" "${f}" && continue
			[ -z "${shown}" ] && banner "Updating wpa_supplicant.conf" && shown="yes"
			if { printf '%s\n' "${line}"; cat "${f}"; } > "${f}.new" && cat "${f}.new" > "${f}"; then
				rm -f "${f}.new"
				output T "${key}" "Added to ${f}"; log I "Added ${line} to ${f}"
				conf_changed="yes"
			else
				rm -f "${f}.new"
				output C "${key}" "Could not update ${f}"; log E "Could not update ${f}"
			fi
		done
	done
}

#######################################
# Installs deb pkg passed as parameter
# Globals:
#   backupPath
# Outputs:
#   Status message, error output and exits script if failed
####################################### 
install-pkg () {
	local pkgName="$1"
	output I "Installing" "${pkgName}"
	local dpkg_err
	if dpkg_err=$(DEBIAN_FRONTEND=noninteractive dpkg --force-confold -i "${backupPath}/${pkgName}" 2>&1 1> /dev/null); then
		output T "dpkg" "Install successful: ${pkgName}"; log I "Install successful: ${pkgName}"
	elif grep -qi 'dependency problems' <<< "${dpkg_err}" && DEBIAN_FRONTEND=noninteractive apt-get install -f -y &> /dev/null; then
		output T "apt" "Dependencies resolved for ${pkgName}"; log I "Dependencies resolved for ${pkgName}"
	else
		echo "${dpkg_err}" | log-stream
		output C "dpkg" "Install failed: ${pkgName} - EXITING"; log E "Install failed: ${pkgName} - EXITING"
		printf "%s\n" "${dpkg_err}" | sed 's/^/        /'
		exit 1
	fi
}

#######################################
# Installs wpa_supplicant service, creates override.conf
# Globals:
#   wpasupp_install,libpcspkg,wpapkg
# Outputs:
#   Status message, installs wpa_supplicant service, error output and exits script if failed
####################################### 
install-from-apt () {
	local apt_err
	output I "apt" "No bundled debs for Debian ${os_major}, using apt"; log I "Using apt"
	if apt_err=$(DEBIAN_FRONTEND=noninteractive apt-get install -y wpasupplicant 2>&1 1> /dev/null); then
		output T "apt" "wpasupplicant installed"; log I "apt install successful"
	else
		echo "${apt_err}" | log-stream
		output C "apt" "Install failed. Exiting"; log E "apt install failed"
		printf "%s\n" "${apt_err}" | sed 's/^/        /'
		exit 1
	fi
}

install-wpa-supp () {
	if (( pkg_gen == 0 )); then
		install-from-apt
	else
		install-pkg "${libpcspkg}"
		install-pkg "${wpapkg}"
	fi
	if [ -f /etc/systemd/system/wpa_supplicant.service.d/override.conf ]; then
	  output T "override.conf" "FOUND"; log IF "/etc/systemd/system/wpa_supplicant.service.d/override.conf"
	else
		create-overide-conf
	fi
	output I "systemctl" "Reloading systemd manager configuration"; log I "Reloading systemd manager configuration"
	systemctl daemon-reload && output T "systemctl" "systemd manager configuration reloaded"; log I "systemd manager configuration reloaded" || { output C "systemctl" "systemd manager configuration could not be reloaded. EXITING" ; log E "systemd manager configuration could not be reloaded. EXITING" ; exit 1; }
}

#######################################
# Restart wpa_supplicant service after configuration has been changed
# Globals:
#   
# Outputs:
#   Status message, systemctl daemon, restarts wpa_supplicant service, error output
####################################### 
restart-wpa-supp () {
	banner "Restart wpa_supplicant service"
	output I "systemctl" "Reloading systemd manager configuration"; log I "Reloading systemd manager configuration"
	if systemctl daemon-reload 1> /dev/null 2> >(log-stream); then
	   output T "systemctl" "systemd manager configuration reloaded" && log I "systemd manager configuration reloaded"
	else
	   output C "systemctl" "systemd manager configuration could not be reloaded."; log E "systemd manager configuration could not be reloaded."
	fi
	if systemctl is-active wpa_supplicant 1> /dev/null 2> >(log-stream); then
	   output T "wpa_supplicant" "${NC}Active: ${GREEN}Yes${NC}" && log I "wpa_supplicant is active"
	   output I "wpa_supplicant" "Restarting wpa_supplicant service"; log I "Restarting wpa_supplicant service"
	   if systemctl restart wpa_supplicant 1> /dev/null 2> >(log-stream); then
	      output T "wpa_supplicant" "Restart successful" && log I "wpa_supplicant service restart successful"
	   else
	      output C "wpa_supplicant" "wpa_supplicant service could not be restarted"; log E "wpa_supplicant service could not be restarted."
	fi
	else
	   output C "wpa_supplicant" "${NC}Active: ${RED}No${NC}"; log E "wpa_supplicant is not active and cannot be restarted"; return 1
	fi
}

#######################################
# Override interface check
#######################################
fix-override-int () {
	local f=/etc/systemd/system/wpa_supplicant.service.d/override.conf cur
	[ -f "${f}" ] || return 0
	cur=$(grep -oP '(?<=-i).*?(?= -c)' < "${f}")
	[ "${cur}" == "${udapi_wan_int}" ] && return 0
	output C "override.conf" "Uses ${cur:-no interface} but the WAN is ${udapi_wan_int}. Rebuilding"; log E "override.conf uses ${cur:-no interface}, WAN is ${udapi_wan_int}"
	rm -f "${f}"
	create-overide-conf
}

#######################################
# Running service check
#######################################
check-service-args () {
	local pid
	pid=$(systemctl show -p MainPID --value wpa_supplicant 2>/dev/null)
	[ -n "${pid}" ] && [ "${pid}" != "0" ] || return 0
	if ! tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null | grep -q -- "-i${udapi_wan_int}"; then
		output C "wpa_supplicant" "Running service is not using ${udapi_wan_int}. Restarting"; log E "Running service is not using ${udapi_wan_int}"
		conf_changed="yes"
	fi
}

#######################################
# Authentication log
#######################################
wpa-since () {
	systemctl show -p ActiveEnterTimestamp --value wpa_supplicant 2>/dev/null
}

wpa-log () {
	local since out uptime f
	since=$(wpa-since)
	[ -n "${since}" ] && out=$(journalctl -u wpa_supplicant -S "${since}" -o cat --no-pager 2>/dev/null)
	if [ -z "${out}" ] && [ -n "${since}" ]; then
		uptime=$(( $(date +%s) - $(date -d "${since}" +%s 2>/dev/null || date +%s) ))
		if (( uptime >= 15 )); then
			out=$(journalctl -u wpa_supplicant -n 300 -o cat --no-pager 2>/dev/null)
			if [ -z "${out}" ]; then
				for f in /var/log/syslog /var/log/messages; do
					[ -r "${f}" ] && out=$(grep 'wpa_supplicant' "${f}" | tail -300) && [ -n "${out}" ] && break
				done
			fi
		fi
	fi
	printf '%s\n' "${out}"
}

#######################################
# Authentication state
#######################################
wpa-auth-state () {
	local ctrl log_state
	if [ -z "$(wpa-since)" ] || ! systemctl is-active --quiet wpa_supplicant; then
		echo "inactive"; return
	fi
	log_state=$(wpa-log | awk '
		/Failed to initialize SSL|passphrase needed|Failed to set TLS connection parameters/ {tls=1}
		/CTRL-EVENT-CONNECTED/ {st="connected"; tls=0; next}
		/CTRL-EVENT-(DISCONNECTED|EAP-FAILURE)/ {st="failed"}
		/CTRL-EVENT-EAP-(STARTED|SUCCESS)/ {st="pending"}
		END { if (st != "connected" && tls) print "fatal"; else print (st == "" ? "none" : st) }')
	if [ -n "${udapi_wan_int}" ] && command -v wpa_cli > /dev/null; then
		ctrl=$(wpa_cli -i "${udapi_wan_int}" status 2>/dev/null)
		if grep -q '^wpa_state=' <<< "${ctrl}"; then
			if grep -q '^wpa_state=COMPLETED' <<< "${ctrl}" || grep -q '^suppPortStatus=Authorized' <<< "${ctrl}"; then echo "connected"
			elif [ "${log_state}" == "fatal" ]; then echo "fatal"
			elif grep -q '^EAP state=FAILURE' <<< "${ctrl}" || [ "${log_state}" == "failed" ]; then echo "failed"
			else echo "pending"; fi
			return
		fi
	fi
	if [ "${log_state}" == "none" ]; then
		if ip -4 -o addr show dev "${udapi_wan_int}" scope global 2>/dev/null | grep -q inet; then echo "connected"; else echo "pending"; fi
	else
		echo "${log_state}"
	fi
}

#######################################
# Authentication diagnosis
#######################################
diagnose-wpa () {
	local logs hint=""
	logs=$(wpa-log)
	if [ "$(cat "/sys/class/net/${udapi_wan_int}/carrier" 2>/dev/null)" == "0" ]; then
		hint="No link on ${udapi_wan_int}. Check the cable."
	elif grep -qE 'Failed to initialize SSL|passphrase needed|Failed to set TLS connection parameters' <<< "${logs}"; then
		hint="Key or certificate would not load. Check ${PrivateKey_filename} and ${Client_filename}."
		grep -q '^[[:space:]]*openssl_ciphers=' "${confPath}/wpa_supplicant.conf" 2>/dev/null || hint="${hint} Add openssl_ciphers to wpa_supplicant.conf."
	elif grep -qiE 'certificate verify failed|unable to get local issuer|md too weak|ca md too' <<< "${logs}"; then
		hint="Server certificate rejected. Check ${CA_filename}."
	elif grep -qiE 'Failed to initialize driver|Could not set interface|No such device|Could not read interface' <<< "${logs}"; then
		hint="Cannot use ${udapi_wan_int}. Check override.conf."
	elif grep -q 'CTRL-EVENT-EAP-FAILURE' <<< "${logs}"; then
		hint="Gateway rejected the login. Check the identity MAC and certificates."
	elif [ -z "$(tr -d '[:space:]' <<< "${logs}")" ]; then
		hint="No log lines found."
	else
		hint="No result yet."
	fi
	output C "Diagnosis" "${hint}"; log E "${hint}"
}

#######################################
# Authentication wait
#######################################
wait-wpa-auth () {
	local state prev="" waited=0
	banner "Checking wpa_supplicant authentication"
	while true; do
		state=$(wpa-auth-state)
		case "${state}" in
			connected)
				if (( waited == 0 )); then
					output T "wpa_supplicant" "Already authenticated"; log I "wpa_supplicant already authenticated"
				else
					output T "wpa_supplicant" "Authenticated after ${waited} seconds"; log I "wpa_supplicant authenticated after ${waited} seconds"
				fi
				return 0 ;;
			inactive)
				output C "wpa_supplicant" "Service is not running"; log E "wpa_supplicant service is not running"
				return 1 ;;
			fatal)
				output C "wpa_supplicant" "Key or certificate failed to load"; log E "wpa_supplicant TLS setup failed"
				diagnose-wpa
				return 1 ;;
		esac
		if (( waited >= wpa_auth_wait )); then
			output C "wpa_supplicant" "Not authenticated after ${wpa_auth_wait} seconds"; log E "wpa_supplicant not authenticated after ${wpa_auth_wait} seconds"
			diagnose-wpa
			return 1
		fi
		if [ "${state}" != "${prev}" ]; then
			output I "wpa_supplicant" "Waiting for authentication, ${state}, up to ${wpa_auth_wait} seconds"; log I "Waiting for authentication, state ${state}"
			prev="${state}"
		fi
		sleep 2; waited=$((waited + 2))
	done
}

#######################################
# Creates override.conf
# Globals:
#   udapi_wan_int,confPath
# Outputs:
#   Status message, error output and exits script if failed
####################################### 
create-overide-conf () {
	if [ -d /etc/systemd/system/wpa_supplicant.service.d ]; then
		output I "override.conf:" "Creating override.conf in service Drop-In path"; log I "Creating override.conf in service Drop-In path"
		printf "[Unit]\nDescription=wpa_supplicant service for AT&T router bypass\nStartLimitIntervalSec=30s\nStartLimitBurst=5\n\n[Service]\nRestart=on-failure\nRestartSec=5s\n\nExecStart=\nExecStart=/sbin/wpa_supplicant -u -s -Dwired -i${udapi_wan_int} -c${confPath}/wpa_supplicant.conf\n" > /etc/systemd/system/wpa_supplicant.service.d/override.conf && output T "override.conf" "override.conf created in Drop-In path"; log I "override.conf created in Drop-In path"; conf_changed="yes" || { output C "override.conf" "Could not create the override.conf file. EXITING" ; log E "Could not create the override.conf file. EXITING" ; exit 1; }
	else
		output C "override.conf" "Path: /etc/systemd/system/wpa_supplicant.service.d NOT FOUND. EXITING" ; log E "Path: /etc/systemd/system/wpa_supplicant.service.d NOT FOUND. EXITING" ; exit 1
	fi
}

#######################################
# Checks internet connectivity using netstat
# Outputs:
#   Status message
####################################### 
netcat-test () {
# Test for internet connectivity with netcat to google.com:80
	local reached=""
	for i in {1..3}; do
	   if nc -z -w 2 google.com 80; then
	       reached="yes"
	       output T "netcat" "${NC}Attempt ${i}/3: ${GREEN}SUCCESSFUL${NC}" && log I "Attempt ${i}/3: netcat google.com:80 SUCCESSFUL"
	       break
	   else
	       output C "netcat" "${NC}Attempt ${i}/3: ${RED}FAILED${NC}" && log E "Attempt ${i}/3: netcat google.com:80 FAILED"
	       (( i < 3 )) && sleep 3
	   fi
	done
	if [ -z "${reached}" ] && nc -z -w 2 1.1.1.1 53; then
	   output I "netcat" "DNS is not resolving"; log E "DNS is not resolving"
	fi
}

#######################################
# Checks if wtf-wpa.service is enabled
# Outputs:
#   Status message
####################################### 
check-recovery-enabled () {
	if systemctl is-enabled wtf-wpa.service 1> /dev/null 2> >(log-stream); then
		output T "Enabled" "Yes"; log I "wtf-wpa.service is enabled"
	else
		output C "Enabled" "No"; log E "wtf-wpa.service is not enabled"; return 1
	fi
}

#######################################
# Enables wtf-wpa.service
# Outputs:
#   Status message
####################################### 
recovery-enable () {
  ## Enable wtf-wpa.service
	if systemctl enable wtf-wpa.service 1> /dev/null 2> >(log-stream); then
		output T "systemctl" "wtf-wpa.service enabled"; log I "wtf-wpa.service enabled"
	else
		output C "systemctl" "wtf-wpa.service service could not be enabled"; log E "wtf-wpa.service service could not be enabled"
	fi
}

#######################################
# Creates an "auto recovery" service "wtf-wpa.service"
# Outputs:
#   Status message
####################################### 
recovery-install () {
  ## Check if wtf-wpa.service is enabled. 
  if ! check-recovery-enabled; then
  	output I "wtf-wpa.service:" "Creating wtf-wpa.service config"; log I "Creating wtf-wpa.service config"
  	printf '[Unit]\nDescription=Reinstall and start/enable wpa_supplicant\nAssertPathExistsGlob='${backupPath}'/wpasupplicant*arm64.deb\nAssertPathExistsGlob='${backupPath}'/libpcsclite1*arm64.deb\nConditionPathExists=!/sbin/wpa_supplicant\nConditionPathExists='${backupPath}'/wtf-wpa.sh\n\n[Service]\nType=oneshot\nExecStart='${backupPath}'/wtf-wpa.sh -r\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/wtf-wpa.service&& output T "wtf-wpa.service" "/etc/systemd/system/wtf-wpa.service - Created"; log I "/etc/systemd/system/wtf-wpa.service - Created"
  	systemctl daemon-reload && output T "systemctl" "systemd manager configuration reloaded"; log I "systemd manager configuration reloaded" || { output C "systemctl:" "systemd manager configuration could not be reloaded. EXITING" ; log E "systemd manager configuration could not be reloaded. EXITING" ; exit 1; }
  	recovery-enable
	fi
}

main-install () {
clear
rm "$log_filename" 1> /dev/null 2> >(log-stream)
banner "Logging to: $log_filename"
banner "Script Version: $wtf_ver"
banner "INSTALLATION MODE"

banner "Checking for variables"
check-for-file "var-file" "${backupPath}" "var-wtf-wpa.txt"
check-variable backupPath "${backupPath}"
check-variable libpcspkg "${libpcspkg}"
check-variable wpapkg "${wpapkg}"
check-variable inetONTmac "${inetONTmac}"
check-variable backupPath "${backupPath}"
check-variable CA_filename "${CA_filename}"
check-variable Client_filename "${Client_filename}"
check-variable PrivateKey_filename "${PrivateKey_filename}"
check-variable confPath "${confPath}"
check-variable certPath "${certPath}"
check-variable debPath "${debPath}"

banner "Checking Hardware"
check-hw
parse-wan-int

banner "Checking for required directories"
check-for-path 'Backup Path' "${backupPath}"
check-for-path debPath "${debPath}" restore
check-for-path certPath "${certPath}" restore
check-for-path confPath "${confPath}" restore
check-for-path override /etc/systemd/system/wpa_supplicant.service.d restore

banner "Checking for required deb packages"
check-for-file "deb_pkg" "${debPath}" "${libpcspkg}" restore
check-for-file "deb_pkg" "${debPath}" "${wpapkg}" restore

banner "Checking for required certificates"
check-for-file "CA" "${certPath}" "${CA_filename}" restore
check-for-file "Client" "${certPath}" "${Client_filename}" restore
check-for-file "PrivateKey" "${certPath}" "${PrivateKey_filename}" restore

banner "Checking for wpa_supplicant conf files"
check-for-file "wpa_conf" "${confPath}" "wpa_supplicant.conf" restore
check-for-file "override" "/etc/systemd/system/wpa_supplicant.service.d" "override.conf" restore
fix-override-int
ensure-conf-globals

banner "Checking wpa_supplicant service"
if check-wpa-supp-installed && check-pkg-current && check-wpa-supp-active && check-wpa-supp-enabled ; then
   check-service-args
   [ -n "${conf_changed}" ] && restart-wpa-supp
else
   banner "Installing/upgrading required packages"
   install-wpa-supp
   wpa-supp-enable
fi

manage-debs

banner "Installing recovery service"
recovery-install

if wait-wpa-auth; then
   banner "Testing connection to google.com:80"
   netcat-test
else
   output I "netcat" "Skipped, not authenticated"; log E "Connection test skipped, not authenticated"
fi

banner "Process complete"
exit
}

main-files () {
clear

rm "$log_filename" 1> /dev/null 2> >(log-stream)
banner "Logging to: $log_filename"
banner "Script Version: $wtf_ver"
banner "FORCE REBUILD MODE"

banner "Checking for variables"
check-for-file "var-file" "${backupPath}" "var-wtf-wpa.txt"
check-variable backupPath "${backupPath}"
check-variable libpcspkg "${libpcspkg}"
check-variable wpapkg "${wpapkg}"
check-variable inetONTmac "${inetONTmac}"
check-variable backupPath "${backupPath}"
check-variable CA_filename "${CA_filename}"
check-variable Client_filename "${Client_filename}"
check-variable PrivateKey_filename "${PrivateKey_filename}"
check-variable confPath "${confPath}"
check-variable certPath "${certPath}"
check-variable debPath "${debPath}"

banner "Checking Hardware"
check-hw
parse-wan-int
parse-conf-wan-int

banner "Checking for required directories"
check-for-path 'Backup Path' "${backupPath}"
check-for-path debPath "${debPath}" restore
check-for-path certPath "${certPath}" restore
check-for-path confPath "${confPath}" restore
check-for-path override /etc/systemd/system/wpa_supplicant.service.d restore

banner "Updating required certificates"
restore-file "CA" "${certPath}" "${CA_filename}"
restore-file "Client" "${certPath}" "${Client_filename}"
restore-file "PrivateKey" "${certPath}" "${PrivateKey_filename}"

banner "Updating wpa_supplicant conf files"
restore-file "wpa_conf" "${confPath}" "wpa_supplicant.conf"
restore-file "override" "/etc/systemd/system/wpa_supplicant.service.d" "override.conf"
ensure-conf-globals

banner "Do you want to restart the wpa_supplicant service?"
read -p "[y/N]" promptRestart
if [[ "$promptRestart" =~ ^(y|Y)$ ]]; then
   restart-wpa-supp
else
   banner "wpa_supplicant service not restarted"
fi

banner "Process complete"
exit
}


main-recovery () {
clear

log_filename="/root/recovery-${short_filename}.log"

rm "$log_filename" 1> /dev/null 2> >(log-stream)
banner "Logging to: $log_filename"
banner "Script Version: $wtf_ver"
banner "RECOVERY MODE"
banner "Checking Hardware"
check-hw
parse-wan-int
parse-conf-wan-int

banner "Checking for required directories"
check-for-path 'Backup Path' "${backupPath}"
check-for-path debPath "${debPath}" restore
check-for-path certPath "${certPath}" restore
check-for-path confPath "${confPath}" restore
check-for-path override /etc/systemd/system/wpa_supplicant.service.d restore

banner "Checking for required deb packages"
check-for-file "deb_pkg" "${debPath}" "${libpcspkg}" restore
check-for-file "deb_pkg" "${debPath}" "${wpapkg}" restore

banner "Checking for required certificates"
check-for-file "CA" "${certPath}" "${CA_filename}" restore
check-for-file "Client" "${certPath}" "${Client_filename}" restore
check-for-file "PrivateKey" "${certPath}" "${PrivateKey_filename}" restore

banner "Checking for wpa_supplicant conf files"
check-for-file "wpa_conf" "${confPath}" "wpa_supplicant.conf" restore
check-for-file "override" "/etc/systemd/system/wpa_supplicant.service.d" "override.conf" restore

banner "Checking wpa_supplicant service"
if check-wpa-supp-installed && check-wpa-supp-active && check-wpa-supp-enabled ; then
   sleep 0
else
   banner "Installing required packages"
   install-wpa-supp
   wpa-supp-enable
fi

#This shouldn't be needed, but is here just in case the switch is invoked directly by the user
banner "Installing recovery service"
recovery-install

banner "Process complete"
exit
}

main-check () {
clear
rm "$log_filename" 1> /dev/null 2> >(log-stream)
banner "Logging to: $log_filename"
banner "Script Version: $wtf_ver"
banner "VERIFICATION MODE"

banner "Checking for variables"
check-for-file "var-file" "${backupPath}" "var-wtf-wpa.txt"
check-variable backupPath "${backupPath}"
check-variable libpcspkg "${libpcspkg}"
check-variable wpapkg "${wpapkg}"
check-variable inetONTmac "${inetONTmac}"
check-variable backupPath "${backupPath}"
check-variable CA_filename "${CA_filename}"
check-variable Client_filename "${Client_filename}"
check-variable PrivateKey_filename "${PrivateKey_filename}"
check-variable confPath "${confPath}"
check-variable certPath "${certPath}"
check-variable debPath "${debPath}"

banner "Checking Hardware"
check-hw
parse-wan-int
parse-conf-wan-int
compare-wan-int

banner "Checking for required directories"
check-for-path 'Backup Path' "${backupPath}"
check-for-path debPath "${debPath}"
check-for-path certPath "${certPath}"
check-for-path confPath "${confPath}"
check-for-path override /etc/systemd/system/wpa_supplicant.service.d

banner "Checking for required deb packages"
check-for-file "deb_pkg" "${debPath}" "${libpcspkg}"
check-for-file "deb_pkg" "${debPath}" "${wpapkg}"

banner "Checking for required certificates"
check-for-file "CA" "${certPath}" "${CA_filename}"
check-for-file "Client" "${certPath}" "${Client_filename}"
check-for-file "PrivateKey" "${certPath}" "${PrivateKey_filename}"

banner "Checking for wpa_supplicant conf files"
check-for-file "wpa_conf" "${confPath}" "wpa_supplicant.conf"
check-for-file "override" "/etc/systemd/system/wpa_supplicant.service.d" "override.conf"

banner "Checking wpa_supplicant service"
check-wpa-supp-installed
check-wpa-supp-active
check-wpa-supp-enabled

banner "Checking recovery service"
check-recovery-enabled

if wait-wpa-auth; then
   banner "Testing connection to google.com:80"
   netcat-test
else
   output I "netcat" "Skipped, not authenticated"; log E "Connection test skipped, not authenticated"
fi

banner "Process complete"
exit
}

####################################### 
## Main script
####################################### 

# Get the options
while getopts "icfr" option; do
	case $option in
		i) wpasupp_install="install"
			main-install;;
		c) main-check;;
		f) main-files;;
		r) wpasupp_install="install"
			main-recovery;;
		\?) echo "Error: Invalid option"
			display-help
			exit;;
	esac
done

display-help
