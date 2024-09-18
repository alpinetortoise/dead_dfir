#!/bin/bash

MOUNT_POINT="$1"
TIME_ZONE="$2"

RED='\033[31m'
GREEN='\033[32m'
BLUE='\033[34m'
CYAN='\033[35m'
RESET='\033[0m'
BOLD='\033[1m'
BOLD_PINK='\033[1;35m'
DIV="=============================="

log_header() {
  local heading=$1
  local sub_heading=$2

  if [ -z "$sub_heading" ]; then
    echo -e "${BLUE}${DIV}|${BOLD}${GREEN} ${heading} ${RESET}${BLUE}|${DIV}${RESET}"
  else
    echo -e "${BLUE}${DIV}|${BOLD}${GREEN} ${heading} - ${sub_heading} ${RESET}${BLUE}|${DIV}${RESET}"
  fi
}

log_value() {
  local title=$1
  local val=$2

  echo -e "${RED}${BOLD}[+] ${BLUE}${title}: ${RESET}${val}"
}

get_property() {
  local key=$1
  local file=$2
  
  echo $(cat $file | grep $key | cut -d '"' -f 2)
}

get_birth() {
  local path=$1

  stat "$MOUNT_POINT$home" | grep "Birth" | cut -d " " -f 3,4 | cut -d "." -f 1
}

# Check if the mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
  echo "Error: Mount point $MOUNT_POINT does not exist."
  exit 1
fi

get_timezone() {
  if [ -f "$MOUNT_POINT/etc/timezone" ]; then
    echo "$(cat $MOUNT_POINT/etc/timezone)"
  else
  echo "$(realpath $MOUNT_POINT/etc/localtime | sed 's/.*zoneinfo\///')"
  fi
}

# Change timezone based on user input and target
timezone="$(get_timezone)"

if [ ! "$TIME_ZONE" ]; then
	export TZ="$timezone"
else 
	export TZ="$TIME_ZONE"
fi

convert_timestamp() {
  local timestamp="$1"
  # Convert timestamp to the target timezone
  # Assumes the format of timestamp is YYYY-MM-DD HH:MM:SS for conversion
  date -d "$timestamp $from_tz" +"%Y-%m-%d %H:%M:%S" -u | TZ="$to_tz" date +"%Y-%m-%d %H:%M:%S"
}

# -----------------------------------------------------------
# MOUNT IMAGE
# -----------------------------------------------------------
mount_image() {
  echo 'eofijwoif'
}

# -----------------------------------------------------------
# DEVICE SETTINGS
# -----------------------------------------------------------
get_device_settings() {
  echo $(log_header "DEVICE SETTINGS")
  echo

  # OS Version
  if [ -f "$MOUNT_POINT/etc/os-release" ]; then
    os_version=$(get_property "PRETTY_NAME" $MOUNT_POINT/etc/os-release)
  elif [ -f "$MOUNT_POINT/etc/lsb-release" ]; then
    os_version=$(get_property "PRETTY_NAME" $MOUNT_POINT/etc/lsb-release)
  elif [ -f "$MOUNT_POINT/etc/redhat-release" ]; then
    os_version=$(get_property "PRETTY_NAME" $MOUNT_POINT/etc/redhat-release)
  elif [ -f "$MOUNT_POINT/etc/debian_version" ]; then
    os_version=$(get_property "PRETTY_NAME" $MOUNT_POINT/etc/debian_version)
  else
    os_version="Not Found"
  fi

  echo $(log_value "OS Version" "$os_version")

  # Kernel Version
  kernel_ver=$(ls $MOUNT_POINT/lib/modules)
  echo $(log_value "Kernel Version" "$kernel_ver")

  # Processor Architecture
  proc_arch="$(ls $MOUNT_POINT/lib/modules | cut -d "." -f 5)"

  if [ ! $proc_arch ]; then
    proc_arch="$(ls $MOUNT_POINT/lib/modules | cut -d "-" -f 3)"
  fi

  echo $(log_value "Processor Architecture" "$proc_arch")

  # Time Zone
  echo $(log_value "Time Zone" "$timezone")

  # Last Shutdown
  last_shutdown=$(last -x -f $MOUNT_POINT/var/log/wtmp  | grep shutdown | head -n 1 | awk '{$1=$2=$3=$4=""; sub(/ -.*$/, ""); print}')
  echo $(log_value "Last Shutdown" "$last_shutdown")

  # Hostname
  hostname=$(cat $MOUNT_POINT/etc/hostname)
  echo $(log_value "Hostname" "$hostname")

  echo
}

# -----------------------------------------------------------
# USERS
# -----------------------------------------------------------
get_users() {
  echo $(log_header "USERS")
  echo

  users=$(egrep "bash|zsh" $MOUNT_POINT/etc/passwd | cut -d ":" -f 1,3)

  for userid in $users; do
    id=$(echo "${userid}" | cut -d ":" -f 2)
    user=$(echo "${userid}" | cut -d ":" -f 1)

    home="$(grep "^$user" $MOUNT_POINT/etc/passwd | cut -d ":" -f 6)"

    disabled="$(cat $MOUNT_POINT/etc/shadow | cut -d ":" -f 1-3 | egrep "^$user(:\$|::)")"
    dis_enabled="$([ "$disabled" ] && echo -e "${BOLD_PINK}True${RESET}" || echo "False")"

    password="$(egrep "^$user:[^!][^:]*:.*$" $MOUNT_POINT/etc/shadow)"
    pass_enabled="$([ "$password" ] && echo -e "${BOLD_PINK}True${RESET}" || echo "False")"

    groups=$(cat $MOUNT_POINT/etc/group | grep $user | cut -d ":" -f 1 | sed ':a;N;$!ba;s/\n/, /g')
    creation="$(get_birth $home)"

    echo -e "$(log_value "$user ($id)" "")"
    echo -e "  ${BOLD}Creation: ${RESET}$creation"
    echo -e "  ${BOLD}Password: ${RESET}$pass_enabled"
    echo -e "  ${BOLD}Disabled: ${RESET}${dis_enabled}"
    echo -e "  ${BOLD}Groups: ${RESET}$groups"
    echo
  done
}

# -----------------------------------------------------------
# SUDOERS
# -----------------------------------------------------------
get_sudoers() {
  echo $(log_header "SUDOERS")
  echo

  if [ -f "$MOUNT_POINT/etc/sudoers" ]; then
    sudoers="$(grep -v "#" $MOUNT_POINT/etc/sudoers | egrep -v "^$|Defaults")"

    echo "$sudoers" | sed -e 's/^[%@]*\([a-zA-Z0-9_-]*\)[ \t]*\(.*\)/\x1b[1;35m\1\x1b[0m \2/'
  else
    echo $(log_value "'/etc/sudoers' file not found..." "")
  fi

  echo
}

# -----------------------------------------------------------
# INSTALLED SOFTWARE
# -----------------------------------------------------------
get_installed_software() {
  echo $(log_header "INSTALLED SOFTWARE")
  echo

  if [ -f "$MOUNT_POINT/var/log/dpkg.log" ]; then
  echo
  elif [ -f "$MOUNT_POINT/var/log/yum.log" ]; then
    packages=$(grep -i installed $MOUNT_POINT/var/log/yum.log)
    highlighted=$(echo "${packages}" | cut -d " " -f 1-3,5 | sed -e 's/^\(.*\) \([^-]*\)-\(.*\)/\1 \x1b[1;35m\2\x1b[0m-\3/')

    echo "$highlighted"
  else
    echo $(log_value "Could't find Installed Software..." "")
  fi

  echo
}

# -----------------------------------------------------------
# CRON JOBS
# -----------------------------------------------------------
get_cron_jobs() {
  echo $(log_header "CRON JOBS")
  echo

  suspicious_patterns=(
      "wget"
      "curl"
      "nc"
      "bash"
      "sh"
      "base64"
      "eval"
      "exec"
      "/tmp/"
      "/dev/"
      "perl"
      "python"
      "ruby"
      "nmap"
      "tftp"
      "nc"
  )

  cron_files=(
      "$MOUNT_POINT/etc/crontab"
      "$MOUNT_POINT/etc/cron.d"
      "$MOUNT_POINT/etc/cron.hourly"
      "$MOUNT_POINT/etc/cron.daily"
      "$MOUNT_POINT/etc/cron.weekly"
      "$MOUNT_POINT/etc/cron.monthly"
  )

  user_cron_directories=(
      "$MOUNT_POINT/var/spool/cron/crontabs" # Debian/Ubuntu
      "$MOUNT_POINT/var/spool/cron"          # Red Hat/CentOS
  )

  escape_sed_delimiters() {
      local string="$1"
      echo "$string" | sed 's/[.[\*^$]/\\&/g'
  }

  is_suspicious() {
      local line="$1"

    for pattern in "${suspicious_patterns[@]}"; do
      if echo "$line" | grep -q "$pattern"; then
        return 0
      fi
    done

      return 1
  }

  scan_cron_jobs() {
      local path="$1"

      if [ -f "$path" ]; then
          echo -e $(log_value "$file" "")

          while IFS= read -r line; do
            if is_suspicious "$line"; then
              echo "$line"
            fi
          done < "$path"

      echo
      elif [ -d "$path" ]; then
          for file in "$path"/*; do
              if [ -f "$file" ]; then
                  echo -e $(log_value "$file" "")

                  while IFS= read -r line; do
                      if is_suspicious "$line"; then
                          echo "$line"
                      fi
                  done < "$file"

          echo
              fi
          done
      fi
  }

  found_suspicious=false
  for file in "${cron_files[@]}"; do
      if [ -e "$file" ]; then
          scan_cron_jobs "$file"
          found_suspicious=true
      fi
  done

  for dir in "${user_cron_directories[@]}"; do
      if [ -d "$dir" ]; then
          for user_cron in "$dir"/*; do
              if [ -f "$user_cron" ]; then
                  scan_cron_jobs "$user_cron"
                  found_suspicious=true
              fi
          done
      fi
  done

  if [ "$found_suspicious" = false ]; then
      echo "No Suspicious Crons Found..."
  fi
}

# -----------------------------------------------------------
# NETWORK
# -----------------------------------------------------------
get_network() {
  echo $(log_header "NETWORK")
  echo

  echo $(log_value "Hosts" "")
  hosts=$(cat $MOUNT_POINT/etc/hosts | egrep -v "^#")
  echo "$hosts"
  echo

  echo $(log_value "DNS" "")
  dns=$(cat $MOUNT_POINT/etc/resolv.conf | egrep -v "^#")
  echo "$dns"
  echo

  echo $(log_value "Interfaces" "")

  get_key() {
    local key=$1
    local file=$2

    echo "$(grep $key $file | tr -d '"' | cut -d "=" -f 2)"
  }

  debian="$MOUNT_POINT/etc/network/interfaces"
  rhel="$MOUNT_POINT/etc/sysconfig/network-scripts/ifcfg-*"

  if [ -f $debian ]; then
    interfaces="$(cat $debian | grep "iface")"

    while IFS= read -r line; do
      int="$(echo $line | cut -d " " -f 2)"
      type="$(echo $line | cut -d " " -f 4)"

      echo -e "${BOLD_PINK}$int:${RESET}"

      if [ "$type" == "dhcp" ]; then
        lease_config="$(cat $MOUNT_POINT/var/lib/dhcp/dhclient.$int.leases)"

        ip_address="$(echo "$lease_config" | grep -oP "fixed-address \K\d{1,3}(\.\d{1,3}){3}" | tail -n 1)"
        subnet_mask="$(echo "$lease_config" | grep -oP "subnet-mask \K\d{1,3}(\.\d{1,3}){3}" | tail -n 1)"
        default_gateway="$(echo "$lease_config" | grep -oP "routers \K\d{1,3}(\.\d{1,3}){3}" | tail -n 1)"
        renew_time="$(echo "$lease_config" | grep -oP 'renew \d+ \K\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}' | tail -n 1)"
        
        echo -e "  ${BOLD}Type:${RESET} $type"
        echo -e "  ${BOLD}IP:${RESET} $ip_address"
        echo -e "  ${BOLD}Mask:${RESET} $subnet_mask"
        echo -e "  ${BOLD}Gateway:${RESET} $default_gateway"
        echo -e "  ${BOLD}Set Time:${RESET} $renew_time"
      else
        echo -e "  ${BOLD}Type:${RESET} $type"
      fi

      echo
    done <<< "$interfaces"
  elif [ ! -z "$(cat $rhel)" ]; then
    for config in $(ls $rhel); do
      local uuid="$(get_key "UUID" "$config")"
      local int="$(get_key "DEVICE" "$config")"
      local type="$(get_key "BOOTPROTO" "$config")"

      echo -e "${BOLD_PINK}$int:${RESET}"

      if [ "$type" == "dhcp" ]; then
        lease_config="$(cat $MOUNT_POINT/var/lib/NetworkManager/dhclient-$uuid*)"

        ip_address="$(echo "$lease_config" | grep -oP "fixed-address \K\d{1,3}(\.\d{1,3}){3}" | tail -n 1)"
        subnet_mask="$(echo "$lease_config" | grep -oP "subnet-mask \K\d{1,3}(\.\d{1,3}){3}" | tail -n 1)"
        default_gateway="$(echo "$lease_config" | grep -oP "routers \K\d{1,3}(\.\d{1,3}){3}" | tail -n 1)"
        renew_time="$(echo "$lease_config" | grep -oP 'renew \d+ \K\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}' | tail -n 1)"
        
        echo -e "  ${BOLD}Type:${RESET} $type"
        echo -e "  ${BOLD}IP:${RESET} $ip_address"
        echo -e "  ${BOLD}Mask:${RESET} $subnet_mask"
        echo -e "  ${BOLD}Gateway:${RESET} $default_gateway"
        echo -e "  ${BOLD}Set Time:${RESET} $renew_time"
      else
        echo -e "  ${BOLD}Type:${RESET} static"
        echo -e "  ${BOLD}IP:${RESET} $(get_key "IPADDR" "$config")"
        echo -e "  ${BOLD}Mask:${RESET} $(get_key "NETMASK" "$config")"
      fi
      
      echo
    done
  else
    echo "Cannot find network configurations..."
    echo
  fi
}

# -----------------------------------------------------------
# LAST MODIFIED
# -----------------------------------------------------------
get_last_modified() {
  echo $(log_header "LAST MODIFIED")
  echo

  last_modified="$(find $MOUNT_POINT -type f -printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null | sort | tail -n 20)"
  echo "$last_modified"

  echo
}

# -----------------------------------------------------------
# SESSIONS
# -----------------------------------------------------------
get_remote_sessions() {
  
  echo $(log_header "REMOTE SESSIONS")
  echo

  if [ -e $MOUNT_POINT/var/log/auth.log ]; then
    output="$(egrep "session opened|session closed" $MOUNT_POINT/var/log/auth.log | awk '{print "state:", $8,"\t|\t", "user:", $11,"\t|\t", "timestamp: ", $1, $2, $3}')"
  elif [ -e $MOUNT_POINT/var/log/secure ]; then
    output="$(egrep "session opened|session closed" $MOUNT_POINT/var/log/secure | awk '{print "state:", $8,"\t|\t", "user:", $11,"\t|\t", "timestamp: ", $1, $2, $3}')"
  else
    echo "Cannot find remote session information..."
  fi
  
  # while IFS= read -r line; do
  #   echo "$(convert_timezone "$line")"
  # done <<< "$output"

  echo "$output"

  echo
}

get_last_logins() {
  echo $(log_header "LAST LOGINS")
  echo

  lastlog -R $MOUNT_POINT | egrep -v "\*\*Never" | awk 'NR>1 {print $1; if (NF>=6) for (i=NF-5; i<=NF; i++) printf "%s ", $i; print ""; if (NF-5 != 3) print "from:\t" $3; if (NF-5 != 2) print "on:\t" $2; print "\n"}'
  
  echo
}

execute_all() {
  get_device_settings
  get_users
  get_sudoers
  get_installed_software
  get_cron_jobs
  get_network
  get_remote_sessions
  get_last_logins

  echo -e "${RED}${DIV}| FINISHED |${DIV}${RESET}"
}

execute_all