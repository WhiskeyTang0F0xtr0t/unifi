#!/bin/bash

###################################### 
# wtf-splunkforwarder v0.1
#
# Check/repair/install the splunk_forwader
#
####################################### 

## USER VARIABLES ##

# Local Splunk user config
localUsername=""
localUserPassword=""

# Splunk server config
splunkServerIP="192.168.0.20"
splunkServerPort="8089"
splunkServerUser=""
splunkServerPassword=""

# dpkg info
dpkgFile="splunkforwarder-9.3.0-51ccf43db5bd-Linux-armv8.deb"
dpkgURL="https://download.splunk.com/products/universalforwarder/releases/9.3.0/linux/splunkforwarder-9.3.0-51ccf43db5bd-Linux-armv8.deb"

####################################### 
##    DO NOT EDIT BELOW THIS LINE    ##
####################################### 
full_filename=$(basename -- "$0")
short_filename="${full_filename%.*}"
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
log_file="${script_dir}/${short_filename}.log"

log() {
	# write formatted status messages to $log_file
	local flag="$1"; shift
	stamp=$(date '+[%F %T]')
	case $flag in
		I) echo "$stamp - INFO: ${*}" >> "$log_file" ;;
		IF) echo "$stamp - INFO: Found - ${*}" >> "$log_file" ;;
		IC) echo "$stamp - INFO: Copied - ${*}" >> "$log_file" ;;
		E) echo "$stamp - ERROR: ${*}" >> "$log_file" ;;
		ENF) echo "$stamp - ERROR: Not found - ${*}" >> "$log_file" ;;
		B) echo "$stamp - ${*}"  >> "$log_file" ;;
	esac
}

log-stream() {
  # used to capture stream output from command responses
  [[ ! -t 0 ]] && while read -r line; do echo "$(date '+[%F %T]') - STREAM: $line" >> "$log_file"; done
}

display-help()
{
	# Display Help
	script_name=$(basename -- "$0")
	printf "%b %s\\n"
	printf "   %b\\n\\n" "Splunk Forwader [ install ]"
	printf "   %b\\n\\n" "Syntax: ${CYAN}${full_filename} [-i]${NC}"
	printf "   %b %s\\n\\n" "options:" ""
	printf "   %8s   %s\\n" "-i" "Install/repair & configure the splunkforwader service"
	printf "   %8s   %s\\n\\n" "" "Example: ${CYAN}${full_filename} -i${NC}"
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
####################################### 
banner () {
	local string=$1
	printf "%b \e[4m%s\e[0m\\n" "${INFO}" "${string}" && log B "*** $string ***"
}

#######################################
# Variable check
#######################################
var-check () {
	local varCheck="$1"
	if [ -z "${varCheck}" ]; then
		printf "   %b \e[4m%s\e[0m %s\\n" "${CROSS}" "${varCheck} not set in script. Exiting."; log E "${varCheck} not set in script."
		exit 1
	fi
}

#######################################
# Splunk local user check/create
#######################################
local-user-check () {
	while true; do
		if [[ -z "${localUsername}" || -z "${localUserPassword}" ]]; then
			printf "   %b \e[4m%s\e[0m %s\\n" "${CROSS}" "Local account information not set in script."; log ENF "Local account credentials not set in script."
			printf "   %b \e[4m%s\e[0m " "${INFO}" && read -p "Enter non-root username: " localUsername
			# localUsername checks
			if [[ "${localUsername}" =~ [^a-zA-Z0-9] ]] || [ -z "${localUsername}" ]; then
		    printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "local_user:" "Invalid username. Please enter a valid username (alphanumeric characters only)."; log E "Invalid username: ${localUsername}"
		    continue
			fi
			printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "local_user:" "Valid username: ${localUsername}"; log I "Valid username: ${localUsername}"
			while true; do
				printf "   %b \e[4m%s\e[0m " "${INFO}" && read -s -p "Enter password for ${localUsername}: " localUserPassword
				printf "\n"
				printf "   %b \e[4m%s\e[0m " "${INFO}" && read -s -p "Confirm password for ${localUsername}: " localUserPassword2
				printf "\n"
				# localUserPassword & localUserPassword2 checks
				if [ "${localUserPassword}" = "${localUserPassword2}" ]; then
					log I "localUserPassword & localUserPassword2 matched"
			  else
					printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "local_user:" "Passwords do not match!"; log E "Passwords do not match!"
					continue
				fi
				# Ensure password is not empty
				if [[ -z "${localUserPassword}" || -z "${localUserPassword2}" ]]; then
					printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "local_user:" "Password cannot be empty!"; log E "Password cannot be empty!"
					continue
				else
			    break
				fi
			done
			printf "   %b \e[4m%s\e[0m %s\\n" "${TICK}" "Local account information set."; log I "Local account credentials set."
		else
			printf "   %b \e[4m%s\e[0m %s\\n" "${TICK}" "Local account information found in script."; log IF "Local account credentials found in script."
		fi
		
		# Create the localUser, home directory and set password based on localUserPassword
		if id "${localUsername}" >/dev/null 2>&1; then
			printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "local_user:" "${RED}${localUsername} already exists! ${NC}"; log E "${localUsername} already exists"
		  break
		else
		  if useradd -m -s /bin/bash "${localUsername}" --password "$(openssl passwd -1 "${localUserPassword}")" > /dev/null 2>&1; then
			  printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "local_user:" "${GREEN}${localUsername} created${NC}"; log I "${localUsername} created${NC}"
			  break
		  else
				printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "local_user:" "${RED}Failed to create user ${localUsername}! ${NC}"; log E "Failed to create user -  ${localUsername}"
		  fi
		fi
	done
}

#######################################
# Get Splunk GUI credentials
#######################################
get-splunkgui-credentials () {
	if [[ -z "${splunkServerUser}" || -z "${splunkServerPassword}" ]]; then
		printf "   %b \e[4m%s\e[0m %s\\n" "${CROSS}" "Splunk GUI credentials not set."; log ENF "Splunk GUI credentials not set in script."
		printf "   %b \e[4m%s\e[0m " "${INFO}" && read -p "Enter the username for Splunk GUI: " splunkServerUser

		while true; do
	    # Get password from the user (hidden input)
	    printf "   %b \e[4m%s\e[0m " "${INFO}" && read -s -p "Enter password for Splunk GUI ${splunkServerUser} user: " splunkServerPassword
			printf "\n"
					
	    # Ensure password is not empty
	    if [[ -z "${splunkServerPassword}" ]]; then
				printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "splunk_gui:" "Password cannot be empty!"; log E " splunkServerPassword Password cannot be empty!"
	    else
				printf "   %b \e[4m%s\e[0m %s\\n" "${TICK}" "Splunk GUI credentials set."
        break
	    fi
		done
	else
		printf "   %b \e[4m%s\e[0m %s\\n" "${TICK}" "Splunk GUI credentials found in script."; log IF "Splunk GUI credentials found in script."
	fi
}

#######################################
# Creates user-seed.conf for silent install
#######################################
create-user-seed-conf () {
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "user-seed:" "Building user-seed.conf"; log I "Building user-seed.conf"
	printf  '[user_info]\nUSERNAME = '"${splunkServerUser}"'\nPASSWORD = '"${splunkServerPassword}"'\n' > /opt/splunkforwarder/etc/system/local/user-seed.conf && printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "user-seed:" "/opt/splunkforwarder/etc/system/local/user-seed.conf - Created"; log I "/opt/splunkforwarder/etc/system/local/user-seed.conf - Created"
}

#######################################
# Creates  INPUTS.CONF
####################################### 
create-inputs-conf () {
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "sf_conf:" "Building INPUTS.CONF"; log I "Building INPUTS.CONF"
	printf  '[monitor:///var/log/ulog]\ndisabled = false\nindex = unifi_firewall\nsourcetype = unifi_firewall\n\n[monitor:///var/log/suricata]\ndisabled = false\nindex = unifi_suricata\nsourcetype = unifi_suricata\n' > /opt/splunkforwarder/etc/system/local/INPUTS.CONF && printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "INPUTS.CONF:" "/opt/splunkforwarder/etc/system/local/INPUTS.CONF - Created"; log I "/opt/splunkforwarder/etc/system/local/INPUTS.CONF - Created"
}

#######################################
# Creates  OUTPUTS.CONF
####################################### 
create-outputs-conf () {
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "sf_conf:" "Building OUTPUTS.CONF"; log I "Building OUTPUTS.CONF"
	printf '[default]\n\n[tcpout]\ndefaultGroup = my_splunk_indexer\n\n[tcpout:my_splunk_indexer]\nserver = '"${splunkServerIP}"':'"${splunkServerPort}"'\n' > "/opt/splunkforwarder/etc/system/local/OUTPUTS.CONF" && printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "sf_conf:" "/opt/splunkforwarder/etc/system/local/OUTPUTS.CONF - Created"; log I "/opt/splunkforwarder/etc/system/local/OUTPUTS.CONF - Created"
}

#######################################
# Installs deb pkg passed as parameter
####################################### 
install-pkg () {
	local pkgName="$1"
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "Installing:" "${pkgName}"
	if dpkg -i "${pkgName}" 1> /dev/null 2> >(log-stream); then
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "dpkg" "Install successful: ${GREEN}${pkgName}${NC}"; log I "Install successful: ${pkgName}"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "dpkg" "Install failed: ${RED}${pkgName} - EXITING${NC}"; log E "Install failed: ${pkgName} - EXITING"
		cat $log_file && exit 1
	fi
}

#######################################
# Download file via wget
####################################### 
wget-file () {
	printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "wget-file:" "Downloading: ${dpkgFile}"
	if wget -O "${dpkgFile}" "${dpkgURL}" -q 1> /dev/null 2> >(log-stream); then
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "wget-file:" "wget download successful: ${GREEN}${dpkgFile}${NC}"; log I "wget download successful: ${dpkgFile}"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "wget-file:" "wget download failed: ${RED}${dpkgFile} - EXITING${NC}"; log E "wget download failed: ${dpkgFile} - EXITING"
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "wget-file:" "Check the URL set in dpkgURL or network connection."
		cat $log_file && exit 1
	fi
}

#######################################
# Installs splunkforwarder
####################################### 
install-splunkforwarder () {
	if [ -f "${dpkgFile}" ]; then
		printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Install:" "${GREEN}${dpkgFile}${NC}"; log IF "${dpkgFile}"
	else
		printf "   %b  \e[1m%b\e[0m %s\\n" "${CROSS}" "Install:" "${RED}${dpkgFile} not found${NC}"; log ENF "${dpkgFile}"
		wget-file 
	fi
	install-pkg "${dpkgFile}"
	chown -R "${localUsername}":"${localUsername}" /opt/splunkforwarder > /dev/null 2>&1 && printf "   %b  \e[1m%b\e[0m %s\\n" "${INFO}" "Install:" "Setting permissions - /opt/splunkforwarder"; log I "Setting permissions - /opt/splunkforwarder"
	create-user-seed-conf
	create-inputs-conf
	create-outputs-conf
	if [ -d /opt/splunkforwarder/bin ] ; then
    printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Install:" "Starting Splunk Universal Forwarder"; log I "Starting Splunk Universal Forwarder"
    /opt/splunkforwarder/bin/splunk start --accept-license --answer-yes 1> /dev/null 2> >(log-stream)
	else
    printf "   %b  \e[1m%b\e[0m %s\\n" "${TICK}" "Install:" "Cannot start Splunk Universal Forwarder"; log E "Cannot start Splunk Universal Forwarder"
		cat $log_file && exit 1
	fi
}

main-install () {
clear
rm "$log_file" 1> /dev/null 2> >(log-stream)
banner "Logging to: $log_file"
banner "Installation Mode"

banner "Checking for required variables"
var-check splunkServerIP
var-check splunkServerPort
var-check dpkgFile
var-check dpkgURL

banner "Checking for Splunk server credentials"
local-user-check
get-splunkgui-credentials

banner "Installing Splunk Universal Forwarder"
install-splunkforwarder

#banner "Installing recovery service"
#recovery-install

banner "Process complete"
exit
}

####################################### 
## Main script
####################################### 

# Get the options
while [[ $# -gt 0 ]]; do
	case $1 in
		-i)
			main-install
			;;
		*)
			echo "Error: Invalid option"
			exit 1;;
	esac
	shift
done

display-help
