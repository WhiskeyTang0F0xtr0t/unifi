#!/bin/bash

####################################### 
# wtf-check-wpasupp v2.6
#
# Checks the wpa_supplicant service and confirms needed files are present by parsing the existing config.
#
####################################### 
full_filename=$(basename -- "$0")
short_filename="${full_filename%.*}"
log_file="${short_filename}.log"

####################################### 
##    DO NOT EDIT BELOW THIS LINE    ##
####################################### 
log() {
	local flag="$1"; shift
	stamp=$(date '+[%F %T]')
	case $flag in
		I) echo "$stamp - INFO: ${*}" >> "$log_file" ;;
		IF) echo "$stamp - INFO: Found - ${*}" >> "$log_file" ;;
		IP) echo "$stamp - INFO: Parsed - ${*}" >> "$log_file" ;;
		E) echo "$stamp - ERROR: ${*}" >> "$log_file" ;;
		ENF) echo "$stamp - ERROR: Not found - ${*}" >> "$log_file" ;;
		B) echo "$stamp - ${*}"  >> "$log_file" ;;
	esac
}

log_stream() {
  # used to capture stream output from command responses
  [[ ! -t 0 ]] && while read -r line; do echo "$(date '+[%F %T]') $line" >> "$log_file"; done
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
# RETURNS:
#   Writes string to stdout
####################################### 
banner () {
	local string=$1
	printf "%b \e[4m%s\e[0m\\n" "${INFO}" "${string}" && log B "*** $string ***"
}

#######################################
# Identify unifi hardware
# RETURN:
#   Status message, exits script if fails
#######################################
check-hw () {
	if command -V ubnt-device-info 1> /dev/null 2> >(log_stream); then
		local model
		model=$(ubnt-device-info model)
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Model:" "${CYAN}${model}${NC}"; log I "Hardware - ${model}"
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
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "WAN Int:" "${CYAN}${udapi_wan_int}${NC}" && log I "WAN Interface: ${udapi_wan_int}"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "WAN Int:" "${RED}Could not determine WAN interface from udapi-net-cfg - EXITING${NC}"; log E "Could not determine WAN interface from udapi-net-cfg - EXITING"; exit 1
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
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Installed:" "${GREEN}${wpa_supp_ver}${NC}" && log I "wpa_supplicant installed: ${wpa_supp_ver}"
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
# Checks for override.conf and parses path to wpa_supplicant configuration file
# OUTPUTS:
#   override_wpasupp_path
# RETURN:
#   Status message
####################################### 
check-for-override () {
	if [ -f /etc/systemd/system/wpa_supplicant.service.d/override.conf ]; then
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "override.conf:" "${GREEN}FOUND${NC}"; log IF "/etc/systemd/system/wpa_supplicant.service.d/override.conf"
	   override_wpasupp_path=$(awk '/Dwired/{ print $6 }' /etc/systemd/system/wpa_supplicant.service.d/override.conf | sed 's/-c//')
	   printf "   %b  %s\\n" "${INFO}" "Parsing override.conf for service configuration file"
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Parsed:" "${GREEN}${override_wpasupp_path}${NC}"; log IP "${override_wpasupp_path}"
	else
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "override.conf:" "${RED}NOT FOUND${NC}"; log E "override.conf was not found"
	fi
}

#######################################
# Gets path to wpa_supplicant.conf from wpa_supplicant service and parses wpasuppconf_longpath wpasuppconf_filename wpasuppconf_path wpasupp_int
# OUTPUTS:
#   wpasuppconf_longpath wpasuppconf_filename wpasuppconf_path wpasupp_int
# RETURN:
#   Status message, exits script if fails
#######################################
parse_service_conf () {
	wpasuppconf_longpath=$(systemctl status wpa_supplicant --no-pager 2> >(log_stream) | awk '/Dwired/{ print $7 }' | sed 's/-c//')
	wpasuppconf_filename=$(basename "${wpasuppconf_longpath}")
	#wpasuppconf_path=$(dirname "${wpasuppconf_longpath}") #Unused
   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Found:" "${GREEN}${wpasuppconf_longpath}${NC}"; log IF "${wpasuppconf_longpath}"
	wpasupp_int=$(systemctl status wpa_supplicant --no-pager 2> >(log_stream) | awk '/Dwired/{ print $6 }' | sed 's/-i//') && log IP "Dwired"
   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Found:" "${CYAN}${wpasupp_int}${NC}"; log IP "Interface: ${wpasupp_int}"
}

#######################################
# pulls configuration info from $wpasuppconf_longpath
# OUTPUTS:
#   CA_filename CA_path Client_filename Client_path PrivateKey_filename PrivateKey_path
# RETURN:
#   Status messages
#######################################
parse-wpasupp-conf () {
	if [ -f "${wpasuppconf_longpath}" ]; then
		log I "wpa_supplicant conf - ${wpasuppconf_longpath}"
		inetONTmac=$(awk -F '"' '/identity/{ print $2 }' "${wpasuppconf_longpath}") && log IP "identity"
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "ONT MAC:" "${CYAN}${inetONTmac}${NC}"; log IP "ONT MAC - ${inetONTmac}"
		CA=$(awk -F '"' '/ca_cert/{ print $2 }' "${wpasuppconf_longpath}") && log IP "ca_cert"
		CA_filename=$(basename "${CA}")
		CA_path=$(dirname "${CA}")
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "CA Path:" "${GREEN}${CA_path}${NC}"; log IP "CA Path: ${CA_path}"
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "CA Filename:" "${GREEN}${CA_filename}${NC}"; log IP "CA Filename: ${CA_filename}"
		Client=$(awk -F '"' '/client_cert/{ print $2 }' "${wpasuppconf_longpath}") && log IP "client_cert"
		Client_filename=$(basename "${Client}")
		Client_path=$(dirname "${Client}")
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Client Path:" "${GREEN}${Client_path}${NC}"; log IP "Client Path: ${Client_path}"
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Client Filename:" "${GREEN}${Client_filename}${NC}"; log IP "Client Filename: ${Client_filename}"
		PrivateKey=$(awk -F '"' '/private_key/{ print $2 }' "${wpasuppconf_longpath}") && log IP "private_key"
		PrivateKey_filename=$(basename "${PrivateKey}")
		PrivateKey_path=$(dirname "${PrivateKey}")
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "PrivateKey Path:" "${GREEN}${PrivateKey_path}${NC}"; log IP "PrivateKey Path: ${PrivateKey_path}"
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "PrivateKey Filename:" "${GREEN}${PrivateKey_filename}${NC}"; log IP "PrivateKey Filename: ${PrivateKey_filename}"
	else
	   printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "${RED}MISSING" "${wpasuppconf_longpath}${NC}"; log ENF "wpa_supplicant conf not found at the parsed path"
	fi
}

#######################################
# Checks for files based on input arrays	
# Arguments:
#   Short name, path variable, file variable
# RETURN:
#   Status message
####################################### 
check-for-pems () {
	local cert_type=(CA Client PrivateKey)
	local cert_paths=("${CA}" "${Client}" "${PrivateKey}")
	local cert_files=("${CA_filename}" "${Client_filename}" "${PrivateKey_filename}")
	for i in "${!cert_type[@]}"; do
		if [ -f "${cert_paths[i]}" ]; then
		   printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "${cert_type[i]}:" "${GREEN}${cert_files[i]}${NC}"; log IF "${cert_type[i]} ${cert_files[i]}"
		else
		   printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "${cert_type[i]}:" "${RED}${cert_files[i]}${NC}"; log ENF "${cert_type[i]} ${cert_files[i]}"
		fi
	done
}


#######################################
# Verifies detected WAN interface matches configured wpa_supplicant interface
# RETURN:
#   Status message
####################################### 
check-compare-interfaces () {
if [[ "$udapi_wan_int" == "$wpasupp_int" ]]; then
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "Detected WAN" "${CYAN}${udapi_wan_int}${NC}"
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "Service Conf" "${CYAN}${wpasupp_int}${NC}"
	printf "   %b  %s\\n" "${TICK}" "Detected interface matches service conf file"
	log I "Detected WAN interface matches wpa_supplicant service conf"
else
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "Detected WAN" "${CYAN}${udapi_wan_int}${NC}"
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "Service Conf" "${CYAN}${wpasupp_int}${NC}"
	printf "   %b  %s\\n" "${CROSS}" "Detected interface does not match wpa_supplicant service conf file"
	log E "Detected WAN interface(ubios-udapi-server.state) does not match wpa_supplicant service conf file"
fi
}

####################################### 
## Main script
####################################### 
clear
rm "$log_file"
banner "Logging to: $log_file"

banner "Checking Hardware"
check-hw
parse-wan-int

banner "Checking wpa_supplicant service"
# Check status of wpa_supplicant service
check-wpa-supp-installed
check-wpa-supp-active	
check-wpa-supp-enabled

banner "Checking for override.conf file"
check-for-override

banner "Pulling active config from wpa_supplicant service"
parse_service_conf

banner "Parsing ${wpasuppconf_filename}"
parse-wpasupp-conf

banner "Verifying certificates exist"
check-for-pems

banner "Verifying WAN interfaces match"
check-compare-interfaces

banner "Checks complete"
