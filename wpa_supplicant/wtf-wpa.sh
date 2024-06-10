#!/bin/bash

###################################### 
# wtf-wpa v1.1
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
inetONTmac="00:00:00:00:00:00"

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
wpasupp_install=""

full_filename=$(basename -- "$0")
short_filename="${full_filename%.*}"
log_file="${short_filename}.log"

log() {
	# write formatted status messages to $log_file
	local flag="$1"; shift
	stamp=$(date '+[%F %T]')
	case $flag in
		I) echo "$stamp - INFO: ${*}" >> "$log_file" ;;
		IF) echo "$stamp - INFO: Found - ${*}" >> "$log_file" ;;
		IC) echo "$stamp - INFO: Copied - ${*}" >> "$log_file" ;;
		IP) echo "$stamp - INFO: Parsed - ${*}" >> "$log_file" ;;
		E) echo "$stamp - ERROR: ${*}" >> "$log_file" ;;
		ENF) echo "$stamp - ERROR: Not found - ${*}" >> "$log_file" ;;
		B) echo "$stamp - ${*}"  >> "$log_file" ;;
	esac
}

log_stream() {
  # used to capture stream output from command responses
  [[ ! -t 0 ]] && while read -r line; do echo "$(date '+[%F %T]') - STREAM: $line" >> "$log_file"; done
}

display-help()
{
	# Display Help
	script_name=$(basename -- "$0")
	printf "%b %s\\n"
	printf "   %b\\n\\n" "WTF wpa [ install/repair | check ]"
	printf "   %b\\n\\n" "Syntax: ${CYAN}${full_filename} [-i|c]${NC}"
	printf "   %b %s\\n\\n" "options:" ""
	printf "   %8s   %s\\n" "-i" "Install/repair & configure the wpa_supplicant service"
	printf "   %8s   %s\\n\\n" "" "Example: ${CYAN}${full_filename} -i${NC}"
	printf "   %8s   %s\\n" "-c" "Does a quick status check of the wpa_supplicant service"
	printf "   %8s   %s\\n\\n" "" "Example: ${CYAN}${full_filename} -c${NC}"
	printf "   %8s   %s\\n\\n" "<none>" "Print this Help"
}

# Output colors
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
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
# Identify unifi hardware
# OUTPUTS:
# 	hw_model
# RETURN:
#   Status message, exits script if fails
#######################################
check-hw () {
	if command -V ubnt-device-info 1> /dev/null 2> >(log_stream); then
		local model
		model=$(ubnt-device-info model)
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Model:" "${CYAN}${model}${NC}"; log I "Hardware - ${model}"
	else
    printf "   %b %s\\n" "${CROSS}" "\e[4m${RED}UNSUPPORTED HARDWARE - EXITING${NC}"; log E "UNSUPPORTED HARDWARE - EXITING"; exit 1
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
		# Parses udapi-net-cfg.json and etracts first interface in wanFailover yaml object
		udapi_wan_int=$(jq -r '.services.wanFailover.wanInterfaces.[0].interface' /data/udapi-config/udapi-net-cfg.json)
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "WAN Int:" "${CYAN}${udapi_wan_int}${NC}" && log I "WAN Interface: ${udapi_wan_int}"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "WAN Int:" "${RED}Could not determine WAN interface from udapi-net-cfg - EXITING${NC}"; log E "Could not determine WAN interface from udapi-net-cfg - EXITING"
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
	if [ -d "${checkPath}" ]; then
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "${checkPathType}:" "${GREEN}${checkPath}${NC}"; log IF "${checkPathType}: ${checkPath}"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "${checkPathType}:" "${RED}${checkPath}${NC}"; log ENF "${checkPathType}: ${backupPath}"
		if [ "$checkPathType" == 'Backup Path' ]; then
			printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "Backup Path:" "Please check your files and try again. - EXITING${NC}"; exit 1
		else
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
  printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "${createPathType}" "Attempting to create ${createPath}"; log ENF "Attempting to create ${createPathType} ${createPath}"
  if mkdir -p "${createPath}" &> /dev/null; then
    printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "${createPathType}" "${GREEN}${createPath}${NC}"; log I "Created ${createPath}"
  else
    printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "${createPathType}" "${RED}Could not create ${createPath}! - EXITING${NC}"; log E "Could not create ${createPathType} ${createPath} - EXITING"
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
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "${checkFileType}:" "${GREEN}${checkFileName}${NC}"; log IF "${checkFileType}: ${checkFilePath}/${checkFileName}"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "${checkFileType}:" "${RED}${checkFileName} not found${NC}"; log ENF "${checkFileType}: ${checkFilePath}/${checkFileName}"
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
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "${restoreFileType}:" "Copying ${restoreFileName} from ${backupPath}"; log IF "Copying ${restoreFileName} from ${backupPath}"
	if cp "${backupPath}"/"${restoreFileName}" "${restoreFilePath}"/ &> /dev/null; then
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "${restoreFileType}:" "${GREEN}${restoreFileName}${NC}"; log IC "${restoreFileType} ${restoreFilePath}/${restoreFileName}"
	else
		if [ "$restoreFileType" == 'wpa_conf' ]; then
			create-wpasupp-conf
		else
			printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "${restoreFileType}:" "Could not copy ${restoreFileName} from ${backupPath}"; log E "Could not copy ${restoreFileName} from ${backupPath}"
			printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "${restoreFileType}:" "Please check your files and try again."
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
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "wpa_conf:" "Building wpa_supplicant.conf from known variables"; log I "Building wpa_supplicant.conf from known variables"
	# Attempts to create ${confPath}/wpa_supplicant.conf from known variables
	printf 'eapol_version=1\nap_scan=0\nfast_reauth=1\nnetwork={\n''        ca_cert="'"${certPath}"/"${CA_filename}"'"\n''        client_cert="'"${certPath}"/"${Client_filename}"'"\n''        eap=TLS\n        eapol_flags=0\n''        identity="'"${inetONTmac}"'" # Internet (ONT) interface MAC address must match this value\n        key_mgmt=IEEE8021X\n        phase1="allow_canned_success=1"\n        private_key="'"${certPath}"/"${PrivateKey_filename}"'"\n''}\n' > "${confPath}"'/wpa_supplicant.conf' && printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "wpa_conf:" "${confPath}/wpa_supplicant.conf - Created"; log I "${confPath}/wpa_supplicant.conf - Created"
}

#######################################
# Checks if wpa_supplicant service is installed
# RETURN:
#   Status message with version
####################################### 
check-wpa-supp-installed () {
# Check if wpa_supplicant is installed with dpkg
	if dpkg -s wpasupplicant 1> /dev/null 2> >(log_stream) ; then
		wpa_supp_ver=$(dpkg -s wpasupplicant | grep -i '^Version' | cut -d' ' -f2)
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Installed:" "${GREEN}${wpa_supp_ver}${NC}"; log I "wpa_supplicant installed: ${wpa_supp_ver}"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "Installed:" "${RED}NOT INSTALLED${NC}"; log E "wpa_supplicant not installed"; return 1
	fi
}

#######################################
# Checks if wpa_supplicant service is active
# RETURN:
#   Status message
####################################### 
check-wpa-supp-active () {
# Check if wpa_supplicant is active with systemctl
	if systemctl is-active wpa_supplicant 1> /dev/null 2> >(log_stream); then
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Active:" "${GREEN}Yes${NC}" && log I "wpa_supplicant is active"
	else
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "Active:" "${RED}No${NC}"; log E "wpa_supplicant is not active"
	fi
}

#######################################
# Checks if wpa_supplicant service is enabled
# RETURN:
#   Status message
####################################### 
check-wpa-supp-enabled () {
# Check if wpa_supplicant is active with systemctl
	if systemctl is-enabled wpa_supplicant 1> /dev/null 2> >(log_stream); then
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Enabled:" "${GREEN}Yes${NC}" && log I "wpa_supplicant is enabled"
	else
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "Enabled:" "${RED}No${NC}"; log E "wpa_supplicant is not enabled"
	fi
}

#######################################
# Enables wpa_supplicant service
# Outputs:
#   Status message, error output and exits script if failed
####################################### 
wpa-supp-enable () {
# Start and enable the wpa_supplicant service with systemctl
	if systemctl enable --now wpa_supplicant 1> /dev/null 2> >(log_stream); then
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "systemctl:" "${GREEN}wpa_supplicant started & enabled${NC}"; log I "Started & enabled wpasupplicant"
		printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "systemctl:" "Waiting for 5 seconds for service to sync"; log I "Waiting for 5 seconds for service to sync" && sleep 5
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "systemctl:" "${RED}wpa_supplicant service could not be enabled - EXITING${NC}"; log E "wpa_supplicant service could not be enabled - EXITING"
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
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "Installing:" "${pkgName}"
	if dpkg -i ${backupPath}/"${pkgName}" 1> /dev/null 2> >(log_stream); then
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "dpkg" "Install successful: ${GREEN}${pkgName}${NC}"; log I "Install successful: ${pkgName}"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "dpkg" "Install failed: ${RED}${pkgName} - EXITING${NC}"; log E "Install failed: ${pkgName} - EXITING"
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
	  printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "override.conf:" "${GREEN}FOUND${NC}"; log IF "/etc/systemd/system/wpa_supplicant.service.d/override.conf"
	else
		create-overide-conf
	fi
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "systemctl" "Reloading systemd manager configuration"; log I "Reloading systemd manager configuration"
	systemctl daemon-reload && printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "systemctl" "systemd manager configuration reloaded"; log I "systemd manager configuration reloaded" || { printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "systemctl" "${RED}systemd manager configuration could not be reloaded. EXITING${NC}" ; log E "systemd manager configuration could not be reloaded. EXITING" ; exit 1; }
}

#######################################
# Creates override.conf
# Globals:
#   udapi_wan_int,confPath
# Outputs:
#   Status message, error output and exits script if failed
####################################### 
create-overide-conf () {
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "override.conf:" "Creating override.conf in service Drop-In path"; log I "Creating override.conf in service Drop-In path"
	printf "[Service]\nExecStart=\nExecStart=/sbin/wpa_supplicant -u -s -Dwired -i${udapi_wan_int} -c${confPath}/wpa_supplicant.conf\n" > /etc/systemd/system/wpa_supplicant.service.d/override.conf && printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "override.conf:" "override.conf created in Drop-In path$"; log I "override.conf created in Drop-In path" || { printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "override.conf:" "${RED}Could not create the override.conf file. EXITING${NC}" ; log E "Could not create the override.conf file. EXITING" ; exit 1; }
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
	       printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "netcat:" "Attemp ${i}/3: ${GREEN}SUCCESSFUL${NC}" && log I "Attemp ${i}/3: netcat google.com:80 SUCCESSFUL"
	       break
	   else
	       printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "netcat:" "Attemp ${i}/3: ${RED}FAILED${NC}" && log E "Attemp ${i}/3: netcat google.com:80 FAILED"
	   fi
	done
}

#######################################
# Creates an "auto recovery" service for wpa_supplicant
# Outputs:
#   Status message
####################################### 
check-recovery-enabled () {
	if systemctl is-enabled wtf-wpa.service 1> /dev/null 2> >(log_stream); then
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "systemctl:" "${GREEN}wtf-wpa.service already enabled${NC}"; log I "wtf-wpa.service is already enabled"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "systemctl:" "${RED}wtf-wpa.service is not enabled${NC}"; log E "wtf-wpa.service is not enabled"; return 1
	fi
}

#######################################
# Creates an "auto recovery" service for wpa_supplicant
# Outputs:
#   Status message
####################################### 
recovery-enable () {
  ## Enable wtf-wpa.service
	if systemctl enable wtf-wpa.service 1> /dev/null 2> >(log_stream); then
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "systemctl:" "${GREEN}wtf-wpa.service enabled${NC}"; log I "wtf-wpa.service enabled"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "systemctl:" "${RED}wtf-wpa.service service could not be enabled${NC}"; log E "wtf-wpa.service service could not be enabled"
	fi
}

#######################################
# Creates an "auto recovery" service for wpa_supplicant
# Outputs:
#   Status message
####################################### 
recovery-install () {
  ## Check if wtf-wpa.service is enabled. 
  if check-recovery-enabled; then
    printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Enabled:" "${GREEN}Yes${NC}" && log I "wtf-wpa.service is enabled"
	else
    printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "Enabled:" "${RED}No${NC}"; log E "wtf-wpa.service is not enabled"
  	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "wtf-wpa.service:" "Creating wtf-wpa.service config"; log I "Creating wtf-wpa.service config"
  	printf '[Unit]\nDescription=Re-run wtf-wpa.sh if the wpa_supplicant binary has been removed\nConditionPathExists=!/sbin/wpa_supplicant\n\n[Service]\nType=oneshot\nExecStart='${backupPath}'/wtf-wpa.sh -i\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/wtf-wpa.service && printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "wtf-wpa.service:" "/etc/systemd/system/wtf-wpa.service - Created"; log I "/etc/systemd/system/wtf-wpa.service - Created"
  	systemctl daemon-reload && printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "systemctl:" "systemd manager configuration reloaded"; log I "systemd manager configuration reloaded" || { printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "systemctl:" "${RED}systemd manager configuration could not be reloaded. EXITING${NC}" ; log E "systemd manager configuration could not be reloaded. EXITING" ; exit 1; }
	fi
	recovery-enable
}


main-install () {
clear
rm "$log_file" 1> /dev/null 2> >(log_stream)
banner "Logging to: $log_file"

banner "Installation Mode"
banner "Checking Hardware Version"
check-hw
parse-wan-int

banner "Checking for required directories"
check-for-path 'Backup Path' "${backupPath}"
check-for-path debPath "${debPath}"
check-for-path certPath "${certPath}"
check-for-path confPath "${confPath}"

banner "Checking for required deb packages"
check-for-file "deb_pkg" "${debPath}" "${libpcspkg}" restore
check-for-file "deb_pkg" "${debPath}" "${wpapkg}" restore

banner "Checking for required certificates"
check-for-file "CA" "${certPath}" "${CA_filename}" restore
check-for-file "Client" "${certPath}" "${Client_filename}" restore
check-for-file "PrivateKey" "${certPath}" "${PrivateKey_filename}" restore

banner "Checking for wpa_supplicant.conf"
check-for-file "wpa_conf" "${confPath}" "wpa_supplicant.conf" restore

banner "Checking wpa_supplicant service"
# Check status of wpa_supplicant service
if check-wpa-supp-installed ; then
   check-wpa-supp-active && wpa-supp-enable
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

main-check () {
clear
rm "$log_file" 1> /dev/null 2> >(log_stream)
banner "Logging to: $log_file"

banner "Verification Mode"
banner "Checking Hardware Version"
check-hw
parse-wan-int

banner "Checking for required directories"
check-for-path 'Backup Path' "${backupPath}"
check-for-path debPath "${debPath}"
check-for-path certPath "${certPath}"
check-for-path confPath "${confPath}"

banner "Checking for required deb packages"
check-for-file "deb_pkg" "${debPath}" "${libpcspkg}"
check-for-file "deb_pkg" "${debPath}" "${wpapkg}"

banner "Checking for required certificates"
check-for-file "CA" "${certPath}" "${CA_filename}"
check-for-file "Client" "${certPath}" "${Client_filename}"
check-for-file "PrivateKey" "${certPath}" "${PrivateKey_filename}"

banner "Checking for wpa_supplicant.conf"
check-for-file "wpa_conf" "${confPath}" "wpa_supplicant.conf"

banner "Checking wpa_supplicant service"
# Check status of wpa_supplicant service
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
while getopts "ic" option; do
	case $option in
		i) wpasupp_install="install"
			main-install;;
		c) main-check;;
		\?) echo "Error: Invalid option"
			display-help
			exit;;
	esac
done

display-help
