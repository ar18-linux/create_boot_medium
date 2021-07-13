#!/usr/bin/env bash
# ar18

# Prepare script environment
{
  # Script template version 2021-07-14_00:22:16
  script_dir_temp="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
  script_path_temp="${script_dir_temp}/$(basename "${BASH_SOURCE[0]}")"
  # Get old shell option values to restore later
  if [ ! -v ar18_old_shopt_map ]; then
    declare -A -g ar18_old_shopt_map
  fi
  shopt -s inherit_errexit
  ar18_old_shopt_map["${script_path_temp}"]="$(shopt -op)"
  set +x
  # Set shell options for this script
  set -e
  set -E
  set -o pipefail
  set -o functrace
}

function stacktrace(){
  echo "STACKTRACE"
  local size
  size="${#BASH_SOURCE[@]}"
  local idx
  idx="$((size - 2))"
  while [ "${idx}" -ge "1" ]; do
    caller "${idx}"
    ((idx--))
  done
}

function restore_env(){
  local exit_script_path
  exit_script_path="${script_path}"
  # Restore PWD
  cd "${ar18_pwd_map["${exit_script_path}"]}"
  # Restore ar18_extra_cleanup
  eval "${ar18_sourced_return_map["${exit_script_path}"]}"
  # Restore script_dir and script_path
  script_dir="${ar18_old_script_dir_map["${exit_script_path}"]}"
  script_path="${ar18_old_script_path_map["${exit_script_path}"]}"
  # Restore LD_PRELOAD
  LD_PRELOAD="${ar18_old_ld_preload_map["${exit_script_path}"]}"
  # Restore old shell values
  IFS=$'\n' shell_options=(echo ${ar18_old_shopt_map["${exit_script_path}"]})
  for option in "${shell_options[@]}"; do
    eval "${option}"
  done
}

function ar18_return_or_exit(){
  set +x
  local path
  path="${1}"
  local ret
  set +u
  ret="${2}"
  set -u
  if [ "${ret}" = "" ]; then
    ret="${ar18_exit_map["${path}"]}"
  fi
  if [ "${ar18_sourced_map["${path}"]}" = "1" ]; then
    export ar18_exit="return ${ret}"
  else
    export ar18_exit="exit ${ret}"
  fi
}

function clean_up() {
  rm -rf "/tmp/${ar18_parent_process}"
  if type ar18_extra_cleanup > /dev/null 2>&1; then
    ar18_extra_cleanup
  fi
}
trap clean_up SIGINT SIGHUP SIGQUIT SIGTERM EXIT

function err_report() {
  local path="${1}"
  local lineno="${2}"
  local msg="${3}"
  RED="\e[1m\e[31m"
  NC="\e[0m" # No Color
  stacktrace
  printf "${RED}ERROR ${path}:${lineno}\n${msg}${NC}\n"
}
trap 'err_report "${BASH_SOURCE[0]}" ${LINENO} "${BASH_COMMAND}"' ERR

{
  # Make sure some modification to LD_PRELOAD will not alter the result or outcome in any way
  if [ ! -v ar18_old_ld_preload_map ]; then
    declare -A -g ar18_old_ld_preload_map
  fi
  if [ ! -v LD_PRELOAD ]; then
    LD_PRELOAD=""
  fi
  ar18_old_ld_preload_map["${script_path_temp}"]="${LD_PRELOAD}"
  LD_PRELOAD=""
  # Save old script_dir variable
  if [ ! -v ar18_old_script_dir_map ]; then
    declare -A -g ar18_old_script_dir_map
  fi
  set +u
  if [ ! -v script_dir ]; then
    script_dir="${script_dir_temp}"
  fi
  ar18_old_script_dir_map["${script_path_temp}"]="${script_dir}"
  set -u
  # Save old script_path variable
  if [ ! -v ar18_old_script_path_map ]; then
    declare -A -g ar18_old_script_path_map
  fi
  set +u
  if [ ! -v script_path ]; then
    script_path="${script_path_temp}"
  fi
  ar18_old_script_path_map["${script_path_temp}"]="${script_path}"
  set -u
  # Determine the full path of the directory this script is in
  script_dir="${script_dir_temp}"
  script_path="${script_path_temp}"
  #Set PS4 for easier debugging
  export PS4='\e[35m${BASH_SOURCE[0]}:${LINENO}: \e[39m'
  # Determine if this script was sourced or is the parent script
  if [ ! -v ar18_sourced_map ]; then
    declare -A -g ar18_sourced_map
  fi
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    ar18_sourced_map["${script_path}"]=1
  else
    ar18_sourced_map["${script_path}"]=0
  fi
  # Initialise exit code
  if [ ! -v ar18_exit_map ]; then
    declare -A -g ar18_exit_map
  fi
  ar18_exit_map["${script_path}"]=0
  # Save PWD
  if [ ! -v ar18_pwd_map ]; then
    declare -A -g ar18_pwd_map
  fi
  ar18_pwd_map["${script_path}"]="${PWD}"
  if [ ! -v ar18_parent_process ]; then
    unset import_map
    export ar18_parent_process="$$"
  fi
  # Local return trap for sourced scripts so that each sourced script 
  # can have their own return trap
  if [ ! -v ar18_sourced_return_map ]; then
    declare -A -g ar18_sourced_return_map
  fi
  if type ar18_extra_cleanup > /dev/null 2>&1 ; then
    ar18_extra_cleanup_temp="$(type ar18_extra_cleanup)"
    ar18_extra_cleanup_temp="$(echo "${ar18_extra_cleanup_temp}" | sed -E "s/^.+is a function\s*//")"
  else
    ar18_extra_cleanup_temp=""
  fi
  ar18_sourced_return_map["${script_path}"]="${ar18_extra_cleanup_temp}"
  function local_return_trap(){
    if [ "${ar18_sourced_map["${script_path}"]}" = "1" ] \
    && [ "${FUNCNAME[1]}" = "ar18_return_or_exit" ]; then
      if type ar18_extra_cleanup > /dev/null 2>&1; then
        ar18_extra_cleanup
      fi
      restore_env
    fi
  }
  trap local_return_trap RETURN
  # Get import module
  if [ ! -v ar18_script_import ]; then
    mkdir -p "/tmp/${ar18_parent_process}"
    old_cwd="${PWD}"
    cd "/tmp/${ar18_parent_process}"
    curl -O https://raw.githubusercontent.com/ar18-linux/ar18_lib_bash/master/ar18_lib_bash/script/import.sh >/dev/null 2>&1 && . "/tmp/${ar18_parent_process}/import.sh"
    export ar18_script_import
    cd "${old_cwd}"
  fi
}
#################################SCRIPT_START##################################

ar18.script.import ar18.script.execute_with_sudo
ar18.script.import ar18.script.obtain_sudo_password
ar18.script.import ar18.pacman.install
ar18.script.import ar18.script.version_check

ar18.script.version_check

ar18.script.obtain_sudo_password

ar18.pacman.install cpio

echo "" 
read -p "specify device to use for boot (i.e. sdb): " ar18_device
echo ""
read -p "ALL DATA ON [${ar18_device}] WILL BE LOST! CONTINUE?"

set +e
ar18.script.execute_with_sudo umount -R "/mnt/ar18_usb"
set -e

set +e
echo 'type=83' | ar18.script.execute_with_sudo sfdisk "/dev/${ar18_device}"
set -e
ar18.script.execute_with_sudo mkfs.ext4 "/dev/${ar18_device}1"

ar18.script.execute_with_sudo mkdir -p /mnt/ar18_usb
ar18.script.execute_with_sudo mount "/dev/${ar18_device}1" /mnt/ar18_usb

ar18.script.execute_with_sudo mkdir -p "/mnt/ar18_usb/boot"

# Remove keyfiles
chosen_image="$(ls -d1 /boot/* | grep initramfs | sort -r | head -1)"
chosen_image_basename="$(basename "${chosen_image}")"
ar18.script.execute_with_sudo rm -rf "/tmp/${chosen_image_basename}"
mkdir -p "/tmp/${chosen_image_basename}"
ar18.script.execute_with_sudo cp -rf "${chosen_image}" "/tmp/${chosen_image_basename}/${chosen_image_basename}"
cd "/tmp/${chosen_image_basename}"
# Decompress image
ar18.script.execute_with_sudo zcat "/tmp/${chosen_image_basename}/${chosen_image_basename}" | cpio -idmv
ar18.script.execute_with_sudo rm -rf "/tmp/${chosen_image_basename}/${chosen_image_basename}"
for filename2 in "/tmp/${chosen_image_basename}/"*; do
  if [ "$(basename "${filename2}")" = "crypto_keyfile.bin" ]; then
    ar18.script.execute_with_sudo rm -rf "${filename2}"
  fi
done
# Change dropbear port
if [ -f "/tmp/${chosen_image_basename}/hooks/dropbear" ]; then
  if [ -f "/home/$(whoami)/.config/ar18/deploy/installed_target" ]; then
    ar18_target="$(cat "/home/$(whoami)/.config/ar18/deploy/installed_target")"
    if [ -f "/home/$(whoami)/.config/ar18/setup_dropbear/${ar18_target}" ]; then
      . "/home/$(whoami)/.config/ar18/setup_dropbear/${ar18_target}"
      if [ ! -v ar18_port ]; then
        ar18_port="22"
      fi
      ar18.script.execute_with_sudo sed -i -E "s@/usr/sbin/dropbear -E -s -j -k@/usr/sbin/dropbear -E -s -j -k -p ${ar18_port}@g" "/tmp/${chosen_image_basename}/hooks/dropbear"
    fi
  fi
fi
# Compress new image
ar18.script.execute_with_sudo sh -c "find . | cpio -H newc -o -R root:root | gzip -9 > \"/mnt/ar18_usb/boot/${chosen_image_basename}\""
# Cleanup 
ar18.script.execute_with_sudo rm -rf "/tmp/${chosen_image_basename}"

chosen_kernel="$(ls -d1 /boot/* | grep vmlinuz | sort -r | head -1)"
chosen_kernel_basename="$(basename "${chosen_kernel}")"
ar18.script.execute_with_sudo cp -rf "${chosen_kernel}" "/mnt/ar18_usb/boot/${chosen_kernel_basename}"

for filename in "/boot/"*; do
  base_name="$(basename "${filename}")"
  if [ "${filename}" = "/boot/memtest86+" ]; then
    continue
  else
    if [[ "${base_name}" =~ ^initramfs ]] \
    || [[ "${base_name}" =~ ^vmlinuz ]]; then
      continue
    else
      ar18.script.execute_with_sudo cp -rf "${filename}" "/mnt/ar18_usb/boot"
    fi
  fi
done

crypt_uuid="$(lsblk -l -o name,uuid,mountpoint | grep sda1 | xargs | cut -d ' ' -f2)"
root_uuid="$(lsblk -l -o name,uuid,mountpoint | grep -E " /$" | xargs | cut -d ' ' -f1)"
crypt_resume_uuid="$(lsblk -l -o name,uuid,mountpoint | grep sda2 | xargs | cut -d ' ' -f2)"

ar18.script.execute_with_sudo cp -rf "${script_dir}/grub.cfg" "/mnt/ar18_usb/boot/grub/grub.cfg"

ar18.script.execute_with_sudo sed -i "s/{{CHOSEN_IMAGE}}/${chosen_image_basename}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"
ar18.script.execute_with_sudo sed -i "s/{{CHOSEN_KERNEL}}/${chosen_kernel_basename}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"
ar18.script.execute_with_sudo sed -i "s/{{CRYPT_UUID}}/${crypt_uuid}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"
ar18.script.execute_with_sudo sed -i "s/{{ROOT_UUID}}/${root_uuid}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"
ar18.script.execute_with_sudo sed -i "s/{{CRYPT_RESUME_UUID}}/${crypt_resume_uuid}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"

##################################SCRIPT_END###################################
set +x
ar18_return_or_exit "${script_path}" && eval "${ar18_exit}"
