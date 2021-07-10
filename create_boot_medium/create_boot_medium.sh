#!/usr/bin/env bash
# ar18

# Prepare script environment
{
  # Script template version 2021-07-10_14:04:55
  # Get old shell option values to restore later
  if [ ! -v ar18_old_shopt_map ]; then
    declare -A -g ar18_old_shopt_map
  fi
  shopt -s inherit_errexit
  ar18_old_shopt_map["$(realpath "${BASH_SOURCE[0]}")"]="$(shopt -op)"
  set +x
  # Set shell options for this script
  set -o pipefail
  set -e
  # Make sure some modification to LD_PRELOAD will not alter the result or outcome in any way
  if [ ! -v ar18_old_ld_preload_map ]; then
    declare -A -g ar18_old_ld_preload_map
  fi
  if [ ! -v LD_PRELOAD ]; then
    LD_PRELOAD=""
  fi
  ar18_old_ld_preload_map["$(realpath "${BASH_SOURCE[0]}")"]="${LD_PRELOAD}"
  LD_PRELOAD=""
  # Save old script_dir variable
  if [ ! -v ar18_old_script_dir_map ]; then
    declare -A -g ar18_old_script_dir_map
  fi
  set +u
  if [ ! -v script_dir ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
  fi
  ar18_old_script_dir_map["$(realpath "${BASH_SOURCE[0]}")"]="${script_dir}"
  set -u
  # Save old script_path variable
  if [ ! -v ar18_old_script_path_map ]; then
    declare -A -g ar18_old_script_path_map
  fi
  set +u
  if [ ! -v script_path ]; then
    script_path="${script_dir}/$(basename "${0}")"
  fi
  ar18_old_script_path_map["$(realpath "${BASH_SOURCE[0]}")"]="${script_path}"
  set -u
  # Determine the full path of the directory this script is in
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
  script_path="${script_dir}/$(basename "${0}")"
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
  ar18_pwd_map["$(realpath "${BASH_SOURCE[0]}")"]="${PWD}"
  if [ ! -v ar18_parent_process ]; then
    export ar18_parent_process="$$"
  fi
  # Get import module
  if [ ! -v ar18.script.import ]; then
    mkdir -p "/tmp/${ar18_parent_process}"
    cd "/tmp/${ar18_parent_process}"
    curl -O https://raw.githubusercontent.com/ar18-linux/ar18_lib_bash/master/ar18_lib_bash/script/import.sh > /dev/null 2>&1 && . "/tmp/${ar18_parent_process}/import.sh"
    cd "${ar18_pwd_map["${script_path}"]}"
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
function clean_up(){
  rm -rf "/tmp/${ar18_parent_process}"
}
# Restore environment
{
  exit_script_path="${script_path}"
  # Restore script_dir and script_path
  script_dir="${ar18_old_script_dir_map["$(realpath "${BASH_SOURCE[0]}")"]}"
  script_path="${ar18_old_script_path_map["$(realpath "${BASH_SOURCE[0]}")"]}"
  # Restore LD_PRELOAD
  LD_PRELOAD=ar18_old_ld_preload_map["$(realpath "${BASH_SOURCE[0]}")"]
  # Restore PWD
  cd "${ar18_pwd_map["$(realpath "${BASH_SOURCE[0]}")"]}"
  # Restore old shell values
  IFS=$'\n' shell_options=(echo ${ar18_old_shopt_map["$(realpath "${BASH_SOURCE[0]}")"]})
  for option in "${shell_options[@]}"; do
    eval "${option}"
  done
}
# Return or exit depending on whether the script was sourced or not
{
  if [ "${ar18_sourced_map["${exit_script_path}"]}" = "1" ]; then
    return "${ar18_exit_map["${exit_script_path}"]}"
  else
    if [ "${ar18_parent_process}" = "$$" ]; then
      clean_up
    fi
    exit "${ar18_exit_map["${exit_script_path}"]}"
  fi
}

trap clean_up SIGINT
