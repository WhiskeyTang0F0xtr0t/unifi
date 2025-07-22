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
wtf_ver="2.3"
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
    	output C "\e[4m UNSUPPORTED HARDWARE - EXITING"; log E "UNSUPPORTED HARDWARE - EXITING"; exit 1
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
		# Parses udapi-net-cfg.json and for first interface in wanFailover yaml object
		udapi_wan_int=$(jq -r '.services.wanFailover.wanInterfaces.[0].interface' /data/udapi-config/udapi-net-cfg.json | awk -F"." '{print $1}')
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
	printf 'eapol_version=1\nap_scan=0\nfast_reauth=1\nnetwork={\n''        ca_cert="'"${certPath}"/"${CA_filename}"'"\n''        client_cert="'"${certPath}"/"${Client_filename}"'"\n''        eap=TLS\n        eapol_flags=0\n''        identity="'"${inetONTmac}"'" # Internet (ONT) interface MAC address must match this value\n        key_mgmt=IEEE8021X\n        phase1="allow_canned_success=1"\n        private_key="'"${certPath}"/"${PrivateKey_filename}"'"\n''}\n' > "${confPath}"'/wpa_supplicant.conf' && output T "wpa_conf:" "${confPath}/wpa_supplicant.conf - Created"; log I "${confPath}/wpa_supplicant.conf - Created"
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
	if systemctl enable --now wpa_supplicant 1> /dev/null 2> >(log-stream); then
		output T "systemctl" "wpa_supplicant started & enabled"; log I "Started & enabled wpasupplicant"
		output I "systemctl" "Waiting for 5 seconds for service to sync"; log I "Waiting for 5 seconds for service to sync" && sleep 5
	else
		output C "systemctl" "wpa_supplicant service could not be enabled - EXITING"; log E "wpa_supplicant service could not be enabled - EXITING"
		exit 1
	fi
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
	if dpkg -i ${backupPath}/"${pkgName}" 1> /dev/null 2> >(log-stream); then
		output T "dpkg" "Install successful: ${pkgName}"; log I "Install successful: ${pkgName}"
	else
		output C "dpkg" "Install failed: ${pkgName} - EXITING"; log E "Install failed: ${pkgName} - EXITING"
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
install-wpa-supp () {
	install-pkg "${libpcspkg}"
	install-pkg "${wpapkg}"
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
# Creates override.conf
# Globals:
#   udapi_wan_int,confPath
# Outputs:
#   Status message, error output and exits script if failed
####################################### 
create-overide-conf () {
	if [ -d /etc/systemd/system/wpa_supplicant.service.d ]; then
		output I "override.conf:" "Creating override.conf in service Drop-In path"; log I "Creating override.conf in service Drop-In path"
		printf "[Unit]\nDescription=wpa_supplicant service for AT&T router bypass\nStartLimitIntervalSec=30s\nStartLimitBurst=5\n\n[Service]\nRestart=on-failure\nRestartSec=5s\n\nExecStart=\nExecStart=/sbin/wpa_supplicant -u -s -Dwired -i${udapi_wan_int} -c${confPath}/wpa_supplicant.conf\n" > /etc/systemd/system/wpa_supplicant.service.d/override.conf && output T "override.conf" "override.conf created in Drop-In path"; log I "override.conf created in Drop-In path" || { output C "override.conf" "Could not create the override.conf file. EXITING" ; log E "Could not create the override.conf file. EXITING" ; exit 1; }
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
	for i in {1..3}; do
	   if nc -z -w 2 google.com 80; then
	       output T "netcat" "${NC}Attempt ${i}/3: ${GREEN}SUCCESSFUL${NC}" && log I "Attempt ${i}/3: netcat google.com:80 SUCCESSFUL"
	       break
	   else
	       output C "netcat" "${NC}Attempt ${i}/3: ${RED}FAILED${NC}" && log E "Attempt ${i}/3: netcat google.com:80 FAILED"
	   fi
	done
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

banner "Checking wpa_supplicant service"
if check-wpa-supp-installed && check-wpa-supp-active && check-wpa-supp-enabled ; then
   sleep 0
else
   banner "Installing required packages"
   install-wpa-supp
   wpa-supp-enable
fi

banner "Installing recovery service"
recovery-install

banner "Testing connection to google.com:80"
netcat-test

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

banner "Testing connection to google.com:80"
netcat-test

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
