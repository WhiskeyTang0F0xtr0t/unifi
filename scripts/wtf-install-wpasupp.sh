#!/bin/bash

###################################### 
# wtf-install-wpa v3.3
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

# "install" -> Install the packages if needed.
# "" -> Do not install the packages, but report that it is needed.
wpasupp_install=""

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
	printf "%b %s\\n" "${INFO}" "${string}" && log B "*** $string ***"
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
		printf "   %b  %b %s\\n" "${TICK}" "Model:" "${CYAN}${model}${NC}"; log I "Hardware - ${model}"
	else
    printf "   %b %s\\n" "${CROSS}" "${RED}UNSUPPORTED HARDWARE - EXITING${NC}"; log E "UNSUPPORTED HARDWARE - EXITING"; exit 1
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
		printf "   %b  %b %s\\n" "${TICK}" "WAN Int:" "${CYAN}${udapi_wan_int}${NC}" && log I "WAN Interface: ${udapi_wan_int}"
	else
		printf "   %b  %b %s\\n" "${CROSS}" "WAN Int:" "${RED}Could not determine WAN interface from udapi-net-cfg - EXITING${NC}"; log E "Could not determine WAN interface from udapi-net-cfg - EXITING"
		exit 1
	fi
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
		printf "   %b  %b %s\\n" "${TICK}" "Installed:" "${GREEN}${wpa_supp_ver}${NC}"; log I "wpa_supplicant installed: ${wpa_supp_ver}"
	else
		printf "   %b  %b %s\\n" "${CROSS}" "Installed:" "${RED}NOT INSTALLED${NC}"; log E "wpa_supplicant not installed"; return 1
	fi
}

#######################################
# Checks if backupPath exists
# Globals:
#   backupPath
# Outputs:
#   Status message, exits script if fails
#######################################
check-backupPath () {
	if [ -d "${backupPath}" ]; then
	   printf "   %b  %b %s\\n" "${TICK}" "Backup Path:" "${GREEN}${backupPath}${NC}"; log IF "backupPath ${backupPath}"
	else
		printf "   %b  %b %s\\n" "${CROSS}" "Backup Path:" "${RED}${backupPath} not found."; log ENF "backupPath ${backupPath}"
		printf "   %b  %b %s\\n" "${INFO}" "Backup Path:" "Please check your files and try again. - EXITING${NC}"; exit 1
	fi
}

#######################################
# Checks if destination paths exist & create if needed
# Globals:
#   debPath certPath confPath
# Outputs:
#   Status message, exits script if fails
#######################################
check-destPaths () {
	local path_type
	path_type=(debPath certPath confPath)
	local path_list
	path_list=("${debPath}" "${certPath}" "${confPath}")
	for i in "${!path_type[@]}"; do
		if [[ -d ${path_list[i]} ]]; then
		   printf "   %b  %b %s\\n" "${TICK}" "${path_type[i]}" "Found: ${GREEN}${path_list[i]}${NC}"; log IF "${path_type[i]} ${path_list[i]}"
		else
	      printf "   %b  %b %s\\n" "${CROSS}" "${path_type[i]}" "${RED}${path_list[i]} not found.${NC} - Attempting to create"; log ENF "Creating ${path_type[i]} ${path_list[i]}"
	      if mkdir -p "${path_list[i]}" &> /dev/null; then
		      printf "   %b  %b %s\\n" "${TICK}" "${path_type[i]}" "${GREEN}${path_list[i]} created${NC}"; log I "Created ${path_list[i]}"
	      else
		      printf "   %b  %b %s\\n" "${CROSS}" "${path_type[i]}" "${RED}Could not create ${path_list[i]}! - EXITING${NC}"; log E "Could not create ${path_type[i]} ${path_list[i]} - EXITING"
		      exit 1
		    fi
		fi
	done
}

#######################################
# Checks for certs, copies from backup if missing
# Globals:
#   certPath CA Client PrivateKey
# Arguments:
#   Short name, cert variable
# Outputs:
#   Status message, exits script if fails
####################################### 
check-for-pems () {
	local cert_type=(CA Client PrivateKey)
	local cert_files=("${CA_filename}" "${Client_filename}" "${PrivateKey_filename}")
	for i in "${!cert_type[@]}"; do
		if [ -f ${certPath}/"${cert_files[i]}" ]; then
			printf "   %b  %b %s\\n" "${TICK}" "${cert_type[i]}:" "${GREEN}${cert_files[i]}${NC}"; log IF "${cert_type[i]} ${certPath}/${cert_files[i]}"
		else
			printf "   %b  %b %s\\n" "${CROSS}" "${cert_type[i]}:" "${RED}${cert_files[i]} not found${NC}"; log ENF "${cert_type[i]}: ${cert_files[i]}"
			printf "   %b  %b %s\\n" "${INFO}" "${cert_type[i]}:" "Copying ${cert_files[i]} from ${backupPath}"; log IF "Copying ${cert_files[i]} from ${backupPath}"
			if cp ${backupPath}/"${cert_files[i]}" ${certPath}/ &> /dev/null; then
				printf "   %b  %b %s\\n" "${TICK}" "${cert_type[i]}:" "${GREEN}${cert_files[i]}${NC}"; log IC "${cert_type[i]} ${certPath}/${cert_files[i]}"
			else
				printf "   %b  %b %s\\n" "${CROSS}" "${cert_type[i]}:" "Could not copy ${cert_files[i]} from ${backupPath}"; log E "Could not copy ${cert_files[i]} from ${backupPath}"
				printf "   %b  %b %s\\n" "${INFO}" "${cert_type[i]}:" "Please check your files and try again."
				exit 1
			fi
		fi
	done
}

#######################################
# Checks for deb packages in debPath
# Globals:
#   debPath backupPath
# Outputs:
#   Status message, exits script if fails
####################################### 
check-for-debpkg () {
	local list
	list=("${libpcspkg}" "${wpapkg}")
	for i in "${!list[@]}"; do
		if [ -f ${debPath}/"${list[i]}" ]; then
			printf "   %b  %b %s\\n" "${TICK}" "deb_pkg" "${GREEN}${debPath}/${list[i]}${NC}"; log IF "${list[i]}"
		else
			printf "   %b  %b %s\\n" "${CROSS}" "deb_pkg" "${RED}${list[i]} not found${NC}"; log ENF "${debPath}/${list[i]}"
			printf "   %b  %b %s\\n" "${INFO}" "deb_pkg" "Copying ${list[i]} from ${backupPath}"; log ENF "Copying ${list[i]} from ${backupPath}"
			if cp ${backupPath}/"${list[i]}" ${debPath}/ &> /dev/null; then
				printf "   %b  %b %s\\n" "${TICK}" "deb_pkg" "${GREEN}${debPath}/${list[i]}${NC}"; log IC "${debPath}/${list[i]}"
			else
				printf "   %b  %b %s\\n" "${CROSS}" "deb_pkg" "${RED}Could not copy ${list[i]} from ${backupPath} - EXITING${NC}"; log E "Could not copy ${list[i]} from ${backupPath} - EXITING"
				exit 1
			fi
		fi
	done
}

#######################################
# Checks for wpa_supplicant.conf in confPath, recreates if missing
# Globals:
#   confPath,backupPath,certPath,CA,Client,inetONTmac,PrivateKey
# Outputs:
#   Status message, ${confPath}/wpa_supplicant.conf if needed
####################################### 
check-wpasupp-conf () {
	if [ -f ${confPath}'/wpa_supplicant.conf' ]; then
		printf "   %b  %b %s\\n" "${TICK}" "wpa_conf" "${GREEN}${confPath}/wpa_supplicant.conf${NC}"; log IF "${confPath}/wpa_supplicant.conf"
	else
		printf "   %b  %b %s\\n" "${CROSS}" "wpa_conf" "${RED}${confPath}/wpa_supplicant.conf not found${NC}"; log ENF "${confPath}/wpa_supplicant.conf"
		if [ -f ${backupPath}'/wpa_supplicant.conf' ]; then
			printf "   %b  %b %s\\n" "${INFO}" "wpa_conf" "Copying wpa_supplicant.conf from ${backupPath}"; log I "Copying wpa_supplicant.conf from ${backupPath}"
			cp ${backupPath}'/wpa_supplicant.conf' ${confPath}/ &> /dev/null && printf "   %b  %b %s\\n" "${TICK}" "wpa_conf" "${GREEN}${confPath}/wpa_supplicant.conf${NC}"; log IC "${confPath}/wpa_supplicant.conf"
		else
			printf "   %b  %b %s\\n" "${CROSS}" "wpa_conf" "${RED}Not found in ${backupPath}${NC}"; log ENF "${backupPath}/wpa_supplicant.conf"
			printf "   %b  %b %s\\n" "${INFO}" "wpa_conf" "Attempting to build wpa_supplicant.conf from known variables"; log I "Attempting to build wpa_supplicant.conf from known variables"
			# Attempts to create ${confPath}/wpa_supplicant.conf from known variables
			printf 'eapol_version=1\nap_scan=0\nfast_reauth=1\nnetwork={\n''        ca_cert="'"${certPath}"/"${CA}"'"\n''        client_cert="'"${certPath}"/"${Client}"'"\n''        eap=TLS\n        eapol_flags=0\n''        identity="'"${inetONTmac}"'" # Internet (ONT) interface MAC address must match this value\n        key_mgmt=IEEE8021X\n        phase1="allow_canned_success=1"\n        private_key="'"${certPath}"/"${PrivateKey}"'"\n''}\n' > "${confPath}"'/wpa_supplicant.conf' && printf "   %b  %b %s\\n" "${TICK}" "${backupPath}/wpa_supplicant.conf - Created"; log I "${backupPath}/wpa_supplicant.conf - Created"
		fi
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
	   printf "   %b  %b %s\\n" "${TICK}" "Active:" "${GREEN}Yes${NC}" && log I "wpa_supplicant is active"
	else
	   printf "   %b  %b %s\\n" "${CROSS}" "Active:" "${RED}No${NC}"; log E "wpa_supplicant is not active"
	   wpa-supp-enable
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
		printf "   %b  %b %s\\n" "${TICK}" "systemctl" "${GREEN}wpa_supplicant started & enabled${NC}"; log I "Started & enabled wpasupplicant"
	else
		printf "   %b  %b %s\\n" "${CROSS}" "systemctl" "${RED}wpa_supplicant service could not be enabled - EXITING${NC}"; log E "wpa_supplicant service could not be enabled - EXITING"
		exit 1
	fi
}

#######################################
# Checks internet connectivity using netstat
# Outputs:
#   Status message
####################################### 
netcat-test () {
# Test for internet connectivity with netcat to google.com:80
	if nc -z -w 3 google.com 80; then
	   printf "   %b  %b %s\\n" "${TICK}" "netcat" "${GREEN}google.com:80 SUCCESSFUL${NC}" && log I "netcat google.com:80 SUCCESSFUL"
	else
	   printf "   %b  %b %s\\n" "${CROSS}" "netcat" "${RED}google.com:80 FAILED${NC}" && log E "netcat google.com:80 FAILED"
	fi
}

#######################################
# Installs wpa_supplicant service, creates override.conf, enables wpa_supplicant service, tests internet connectivity
# Globals:
#   wpasupp_install,libpcspkg,backupPath,wpapkg,udapi_wan_int,confPath
# Outputs:
#   Status message, installs wpa_supplicant service, error output and exits script if failed
####################################### 
install-wpa-supp () {
# Install ${wpapkg} with dpkg
	if [ "$wpasupp_install" = "install" ]; then
		local list
		list=("${libpcspkg}" "${wpapkg}")
		for i in "${!list[@]}"; do
			printf "   %b  %b %s\\n" "${INFO}" "Installing:" "${list[i]}"
			if dpkg -i ${backupPath}/"${list[i]}" 1> /dev/null 2> >(log_stream); then
				printf "   %b  %b %s\\n" "${TICK}" "dpkg" "Install successful: ${GREEN}${list[i]}${NC}"; log I "Installed ${list[i]}"
			else
				printf "   %b  %b %s\\n" "${CROSS}" "dpkg" "Install failed: ${RED}${list[i]} - EXITING${NC}"; log E "Install failed: ${list[i]} - EXITING"
				exit 1
			fi
		done
		printf "   %b  %b %s\\n" "${INFO}" "override.conf:" "Adding override.conf to Drop-In path."; log I "Adding override.conf to Drop-In path"
		printf "[Service]\nExecStart=\nExecStart=/sbin/wpa_supplicant -u -s -Dwired -i${udapi_wan_int} -c${confPath}/wpa_supplicant.conf\n" > /etc/systemd/system/wpa_supplicant.service.d/override.conf && printf "   %b  %b %s\\n" "${TICK}" "override.conf:" "override.conf created in Drop-In path$"; log I "override.conf created in Drop-In path" || { printf "   %b  %b %s\\n" "${CROSS}" "override.conf:" "${RED}Could not create the override.conf file. EXITING${NC}" ; log E "Could not create the override.conf file. EXITING" ; exit 1; }
		printf "   %b  %b %s\\n" "${INFO}" "systemctl" "Reloading systemd manager configuration"; log I "Reloading systemd manager configuration"
		systemctl daemon-reload && printf "   %b  %b %s\\n" "${TICK}" "systemctl" "systemd manager configuration reloaded"; log I "systemd manager configuration reloaded" || { printf "   %b  %b %s\\n" "${CROSS}" "systemctl" "${RED}systemd manager configuration could not be reloaded. EXITING${NC}" ; log E "systemd manager configuration could not be reloaded. EXITING" ; exit 1; }
	else
		printf "   %b  %b %s\\n" "${INFO}" "dpkg" "Install flag not. ${RED}Aborting deb pkg installation${NC}"; log E "Install flag not. Aborting deb pkg installation" 
	fi
}

####################################### 
## Main script
####################################### 
clear
rm "$log_file" 1> /dev/null 2> >(log_stream)
banner "Logging to: $log_file"

banner "Checking Hardware Version"
check-hw
parse-wan-int

banner "Checking for required directories"
check-backupPath
check-destPaths

banner "Checking for required deb packages"
check-for-debpkg

banner "Checking for required certificates"
check-for-pems

banner "Checking for wpa_supplicant.conf"
check-wpasupp-conf

banner "Checking wpa_supplicant service"
# Check status of wpa_supplicant service
if check-wpa-supp-installed ; then
   check-wpa-supp-active
else	
   banner "Installing required packages"
   install-wpa-supp
   wpa-supp-enable
fi

banner "Testing internet connectivity"
netcat-test

banner "Process complete"
