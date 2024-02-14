#!/bin/bash

###################################### 
# wtf_wpa v3.1
#
# Check/repair/install the wpa_supplicant setup on UDM hardware
#
####################################### 
# Backup folder structure
# $backupPath
#  - $wpapkg
#  - $libpcspkg
#  - CA_XXXXXX-123456789012345.pem
#  - Client_XXXXXX-123456789012345.pem
#  - PrivateKey_PKCS1_XXXXXX-123456789012345.pem
#  - wpa_supplicant.conf(Can be created if not found)
####################################### 

## USER VARIABLES ##

# "install" -> Install the packages if needed.
# "" -> Do not install the packages, but report that it is needed.
wpasupp_install=""

# FULL PATH to "backup" folder
backupPath='/root/config'

# Names of install deb files
libpcspkg='libpcsclite1_1.9.1-1_arm64.deb'
wpapkg='wpasupplicant_2.9.0-21_arm64.deb'

# Internet (ONT) interface MAC address (Pulled from cert extraction process)
inetONTmac='00:00:00:00:00:00'

# Certficate variables
CA='CA_XXXXXX-YYYYYYYYYYYYYYY.pem'
Client='Client_XXXXXX-YYYYYYYYYYYYYYY.pem'
PrivateKey='PrivateKey_PKCS1_XXXXXX-YYYYYYYYYYYYYYY.pem'

# FULL PATH for wpa_supplicant.conf
confPath='/etc/wpa_supplicant/conf'

# FULL PATH for cert storage
certPath='/etc/wpa_supplicant/conf'

# FULL PATH for deb package storage
debPath='/etc/wpa_supplicant/packages'

####################################### 
##    DO NOT EDIT BELOW THIS LINE    ##
####################################### 
full_filename=$(basename -- "$0")
short_filename="${full_filename%.*}"
log_file="${short_filename}.log"

log() {
	# write formatted status messages to $log_file
	local flag="$1"; shift
	stamp=`date '+[%F %T]'`
	case $flag in
		I) echo "$stamp - INFO: ${@}" >> $log_file ;;
		IF) echo "$stamp - INFO: Found - ${@}" >> $log_file ;;
		IP) echo "$stamp - INFO: Parsed - ${@}" >> $log_file ;;
		E) echo "$stamp - ERROR: ${@}" >> $log_file ;;
		ENF) echo "$stamp - ERROR: Not found - ${@}" >> $log_file ;;
		B) echo "$stamp - ${@}"  >> $log_file ;;
	esac
}

log_stream() {
  # used to capture stream output from command responses
  [[ ! -t 0 ]] && while read line; do echo "$(date '+[%F %T]') $line" >> $log_file; done
}

# Banner column formatting
format="%20s : %-s\n"

# Output colors
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
NC=$(tput sgr0)

#######################################
# Show a formatted banner with message
# ARGUMENTS:
#   Message to be displayed
# OUTPUTS:
#   Writes formatted string to stdout
####################################### 
banner () {
	local string=$1
	padding="============================================================"
	printf "%s\n" "== ""$string"" ""${padding:${#string}}" && log B "*** $string ***"
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
		hw_model=`ubnt-device-info model`
		printf "$format" "Hardware" "${CYAN}${hw_model}${NC}"; log I "Hardware - ${hw_model}"
	else
      printf "$format" "Hardware" "${RED}UNSUPPORTED HARDWARE - EXITING${NC}"; log E "UNSUPPORTED HARDWARE - EXITING"; exit 1
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
		udapi_wan_int=`jq -r '.services.wanFailover.wanInterfaces.[0].interface' /data/udapi-config/udapi-net-cfg.json`
		printf "$format" "WAN Interface" "${CYAN}${udapi_wan_int}${NC}" && log I "WAN Interface: ${udapi_wan_int}"
	else
		printf "$format" "WAN Interface" "${RED}Could not determine WAN interface from udapi-net-cfg - EXITING${NC}"; log E "Could not determine WAN interface from udapi-net-cfg - EXITING"; exit 1
	fi
}

#######################################
# Checks if wpa_supplicant service is installed
# RETURN:
#   Status message with version
####################################### 
check-wpa-supp-installed () {
# Check if wpa_supplicant is installed with dpkg
	if dpkg -s wpasupplicant 1> /dev/null 2> >(log_stream); then
   	wpa_supp_ver=`dpkg -s wpasupplicant | grep -i '^Version' | cut -d' ' -f2`
	   printf "$format" "wpa_supplicant" "${GREEN}Installed: ${wpa_supp_ver}${NC}" && log I "wpa_supplicant installed: ${wpa_supp_ver}"
	else
	   printf "$format" "wpa_supplicant" "${RED}NOT INSTALLED${NC}"; log E "wpa_supplicant not installed"; return 1
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
	if [ -d ${backupPath} ]; then
	   printf "$format" "backupPath" "${GREEN}Found ${backupPath}${NC}"; log IF "backupPath ${backupPath}"
	else
      printf "$format" "backupPath" "${RED}${backupPath} not found."; log ENF "backupPath ${backupPath}"
	   printf "$format" "${1}" "Please check your files and try again. - EXITING${NC}"; exit 1
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
	local path_type=(debPath certPath confPath)
	local path_list=(${debPath} ${certPath} ${confPath})
	for i in "${!path_type[@]}"; do
		if [[ -d ${path_list[i]} ]]; then
		   printf "$format" "${path_type[i]}" "${GREEN}Found ${path_list[i]}${NC}"; log IF "${path_type[i]} ${path_list[i]}"
		else
	      printf "$format" "${path_type[i]}" "${RED}${path_list[i]} not found.${NC} - Attempting to create"; log ENF "Creating ${path_type[i]} ${path_list[i]}"
	      mkdir -p ${path_list[i]} &> /dev/null && printf "$format" "${path_type[i]}" "${GREEN}${path_list[i]} created${NC}"; log I "Created ${path_list[i]}" || { printf "$format" "${path_type[i]}" "${RED}Could not create ${path_list[i]}! - EXITING${NC}" ; log E "Could not create ${path_type[i]} ${path_list[i]} - EXITING" ; exit 1; }
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
	local list1=(CA Client PrivateKey)
	local list2=(${CA} ${Client} ${PrivateKey})
	for i in "${!list1[@]}"; do
		if [ -f ${certPath}/${list2[i]} ]; then
		   printf "$format" "${list1[i]}" "${GREEN}${list2[i]}${NC}"; log IF "${list1[i]} ${certPath}/${list2[i]}"
		else
		   printf "$format" "${list1[i]}" "${RED}MISSING ${certPath}/${list2[i]}${NC} - Copying from ${backupPath}"; log ENF "${list1[i]}: ${list2[i]} - Copying from ${backupPath}"
		   cp ${backupPath}/${list2[i]} ${certPath}/ &> /dev/null || { printf "$format" "${list1[i]}" "Could not copy ${list2[i]} from ${backupPath}${NC}"; printf "\nPlease check your files and try again.\n\n"; log E "Could not copy ${list2[i]} from ${backupPath}" ; exit 1; }
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
	local list=(${libpcspkg} ${wpapkg})
	for i in "${!list[@]}"; do
		if [ -f ${debPath}/${list[i]} ]; then
		   printf "$format" "deb_pkg" "${GREEN}Found ${debPath}/${list[i]}${NC}"; log IF "${list[i]}"
		else
		   printf "$format" "deb_pkg" "${RED}${list[i]} not found.${NC} - Copying from ${backupPath}"; log ENF "${list[i]} - Copying from ${backupPath}"
	       cp ${backupPath}/${list[i]} ${debPath}/ &> /dev/null && printf "$format" "deb_pkg" "${GREEN}Copied ${debPath}/${list[i]}${NC}"; log I "Copied ${debPath}/${list[i]}" || { printf "$format" "deb_pkg" "${RED}Could not copy ${debPath}/${list[i]} - EXITING${NC}"; log E "Could not copy ${debPath}/${list[i]} - EXITING" ; exit 1; }
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
	   printf "$format" "wpa_conf" "${GREEN}Found in ${confPath}${NC}"; log IF "${confPath}/wpa_supplicant.conf"
	else
	   printf "$format" "wpa_conf" "${RED}Not found in ${confPath}${NC}"; log ENF "${confPath}/wpa_supplicant.conf"
	   if [ -f ${backupPath}'/wpa_supplicant.conf' ]; then
		   printf "$format" "wpa_conf" "${GREEN}Copying from ${backupPath}${NC}"; log I "Copying from ${backupPath}"
		   cp ${backupPath}'/wpa_supplicant.conf' ${confPath}/ &> /dev/null || { printf "$format" "wpa_conf" "${RED}Copying from ${backupPath} FAILED${NC}" ; log E "Copying from ${backupPath} FAILED" ; exit 1; }
		else
		   printf "$format" "wpa_conf" "${RED}Not found in ${backupPath}${NC}"; log ENF "${backupPath}/wpa_supplicant.conf"
		   printf "$format" "wpa_conf" "Attempting to build wpa_supplicant.conf from known variables"; log I "Attempting to build wpa_supplicant.conf from known variables"
			# Attempts to create ${confPath}/wpa_supplicant.conf from known variables
		   printf 'eapol_version=1\nap_scan=0\nfast_reauth=1\nnetwork={\n''        ca_cert="'"${certPath}"/"${CA}"'"\n''        client_cert="'"${certPath}"/"${Client}"'"\n''        eap=TLS\n        eapol_flags=0\n''        identity="'"${inetONTmac}"'" # Internet (ONT) interface MAC address must match this value\n        key_mgmt=IEEE8021X\n        phase1="allow_canned_success=1"\n        private_key="'"${certPath}"/"${PrivateKey}"'"\n''}\n' > "${confPath}"'/wpa_supplicant.conf' && printf "$format" "wpa_conf" "${GREEN}${backupPath}/wpa_supplicant.conf - Created${NC}"; log I "${backupPath}/wpa_supplicant.conf - Created"
	   fi
	fi
}

#######################################
# Checks if wpa_supplicant service is installed
# RETURN:
#   Status message with version
####################################### 
check-wpa-supp-installed () {
# Check if wpa_supplicant is installed with dpkg
	if dpkg -s wpasupplicant 1> /dev/null 2> >(log_stream); then
   	wpa_supp_ver=`dpkg -s wpasupplicant | grep -i '^Version' | cut -d' ' -f2`
	   printf "$format" "wpa_supplicant" "${GREEN}Installed: ${wpa_supp_ver}${NC}" && log I "wpa_supplicant installed: ${wpa_supp_ver}"
	else
	   printf "$format" "wpa_supplicant" "${RED}NOT INSTALLED${NC}"; log E "wpa_supplicant not installed"; return 1
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
	   printf "$format" "wpa_supplicant" "${GREEN}Service is ACTIVE${NC}" && log I "wpa_supplicant is active"
	else
	   printf "$format" "wpa_supplicant" "${RED}NOT ACTIVE${NC}"; log E "wpa_supplicant is not active"
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
	   printf "$format" "wpa_srv" "${GREEN}Starting and enabling wpasupplicant${NC}"; log I "Starting & enabling wpasupplicant"
	else
		printf "$format" "wpa_srv" "${RED}wpa_supplicant service could not be enabled - EXITING${NC}"; log E "wpa_supplicant service could not be enabled - EXITING"; exit 1
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
	   printf "$format" "netcat" "${GREEN}google.com:80 SUCCESSFUL${NC}" && log I "netcat google.com:80 SUCCESSFUL"
	else
	   printf "$format" "netcat" "${RED}google.com:80 FAILED${NC}" && log E "netcat google.com:80 FAILED"
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
		printf "$format" "Install" "${GREEN}${libpcspkg} - Installing${NC}"
		dpkg -i ${backupPath}/${libpcspkg} 1> /dev/null 2> >(log_stream) || { printf "$format" "Install" "${RED}${libpcspkg} - Install FAILED! - EXITING${NC}"; log E "${libpcspkg} - Install FAILED! - EXITING"; exit 1; }
		printf "$format" "Install" "${GREEN}${libpcspkg} - Install SUCCESSFUL${NC}"; log I "${libpcspkg} - Install SUCCESSFUL"
		printf "$format" "Install" "${GREEN}${wpapkg} - Installing${NC}"
		dpkg -i ${backupPath}/${wpapkg} 1> /dev/null 2> >(log_stream) || { printf "$format" "Install" "${RED}${wpapkg} - Install FAILED! - EXITING${NC}"; log E "${wpapkg} - Install FAILED! - EXITING"; exit 1; }
		printf "$format" "Install" "${GREEN}${wpapkg} - Install SUCCESSFUL${NC}"; log I "${wpapkg} - Install SUCCESSFUL"
		printf "$format" "Install" "${GREEN}Adding override.conf to Drop-In path.${NC}"; log I "Adding override.conf to Drop-In path"
		printf "[Service]\nExecStart=\nExecStart=/sbin/wpa_supplicant -u -s -Dwired -i${udapi_wan_int} -c${confPath}/wpa_supplicant.conf\n" > /etc/systemd/system/wpa_supplicant.service.d/override.conf && printf "$format" "Install" "${GREEN}override.conf created in Drop-In path${NC}" && log I "override.conf created in Drop-In path"
		systemctl daemon-reload && printf "$format" "Install" "${GREEN}systemd manager configuration reloaded${NC}" && log I "systemd manager configuration reloaded"
		wpa-supp-enable && netcat-test
	else
		printf "$format" "Install" "${RED}${wpapkg} - Install flag NOT SET. ABORTING${NC}"; log E "Install flag NOT SET. ABORTING" 
	fi
}

####################################### 
## Main script
####################################### 
clear
rm $log_file
banner "Resetting $log_file"

banner "Checking Hardware Version"
check-hw
parse-wan-int

banner "Checking for required deb packages"
check-for-debpkg

banner "Checking for required directories"
check-backupPath
check-destPaths

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
fi

banner "Testing internet connectivity"
netcat-test

banner "Process complete"
