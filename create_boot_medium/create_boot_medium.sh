#!/bin/bash
# ar18

# Script template version 2021-06-12.03
# Make sure some modification to LD_PRELOAD will not alter the result or outcome in any way
LD_PRELOAD_old="${LD_PRELOAD}"
LD_PRELOAD=
# Determine the full path of the directory this script is in
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
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
if [ -z "${ar18_exit_map+x}" ]; then
  declare -A -g ar18_exit_map
fi
ar18_exit_map["${script_path}"]=0
# Get old shell option values to restore later
shopt -s inherit_errexit
IFS=$'\n' shell_options=($(shopt -op))
# Set shell options for this script
set -o pipefail
set -eu
#################################SCRIPT_START##################################

set -x

if [ ! -v ar18_helper_functions ]; then rm -rf "/tmp/helper_functions_$(whoami)"; cd /tmp; git clone https://github.com/ar18-linux/helper_functions.git; mv "/tmp/helper_functions" "/tmp/helper_functions_$(whoami)"; . "/tmp/helper_functions_$(whoami)/helper_functions/helper_functions.sh"; cd "${script_dir}"; export ar18_helper_functions=1; fi
obtain_sudo_password

pacman_install cpio

echo "" 
read -p "specify device to use for boot (i.e. sdb): " ar18_device
echo ""
read -p "ALL DATA ON [${ar18_device}] WILL BE LOST! CONTINUE?"

set +e
echo "${ar18_sudo_password}" | sudo -Sk umount -R /mnt/ar18_usb
set -e

set +e
echo 'type=83' | echo "${ar18_sudo_password}" | sudo -Sk sfdisk "/dev/${ar18_device}"
set -e
echo "${ar18_sudo_password}" | sudo -Sk mkfs.ext4 "/dev/${ar18_device}1"

echo "${ar18_sudo_password}" | sudo -Sk mkdir -p /mnt/ar18_usb
echo "${ar18_sudo_password}" | sudo -Sk mount "/dev/${ar18_device}1" /mnt/ar18_usb
#echo "${ar18_sudo_password}" | sudo -Sk grub-install --target=i386-pc --debug --boot-directory=/mnt/ar18_usb/boot "/dev/${ar18_device}"
#echo "${ar18_sudo_password}" | sudo -Sk grub-mkconfig -o /mnt/ar18_usb/boot/grub/grub.cfg

echo "${ar18_sudo_password}" | sudo -Sk mkdir -p "/mnt/ar18_usb/boot"

# Remove keyfiles
chosen_image="$(ls -d1 /boot/* | grep initramfs | sort -r | head -1)"
chosen_image_basename="$(basename "${chosen_image}")"
echo "${ar18_sudo_password}" | sudo -Sk rm -rf "/tmp/${chosen_image_basename}"
mkdir -p "/tmp/${chosen_image_basename}"
echo "${ar18_sudo_password}" | sudo -Sk cp -rf "${chosen_image}" "/tmp/${chosen_image_basename}/${chosen_image_basename}"
cd "/tmp/${chosen_image_basename}"
echo "${ar18_sudo_password}" | sudo -Sk zcat "/tmp/${chosen_image_basename}/${chosen_image_basename}" | cpio -idmv
echo "${ar18_sudo_password}" | sudo -Sk rm -rf "/tmp/${chosen_image_basename}/${chosen_image_basename}"
for filename2 in "/tmp/${chosen_image_basename}/"*; do
  if [ "$(basename "${filename2}")" = "crypto_keyfile.bin" ]; then
    echo "${ar18_sudo_password}" | sudo -Sk rm -rf "${filename2}"
  fi
done
echo "${ar18_sudo_password}" | sudo -Sk sh -c "find . | cpio -H newc -o -R root:root | gzip -9 > \"/mnt/ar18_usb/boot/${chosen_image_basename}\"" 
echo "${ar18_sudo_password}" | sudo -Sk rm -rf "/tmp/${chosen_image_basename}"

chosen_kernel="$(ls -d1 /boot/* | grep vmlinuz | sort -r | head -1)"
chosen_kernel_basename="$(basename "${chosen_kernel}")"
echo "${ar18_sudo_password}" | sudo -Sk cp -rf "${chosen_kernel}" "/mnt/ar18_usb/boot/${chosen_kernel_basename}"

for filename in "/boot/"*; do
  base_name="$(basename "${filename}")"
  if [ "${filename}" = "/boot/memtest86+" ]; then
    continue
  else
    if [[ "${base_name}" =~ ^initramfs ]] \
    || [[ "${base_name}" =~ ^vmlinuz ]]; then
      continue
    else
      echo "${ar18_sudo_password}" | sudo -Sk cp -rf "${filename}" "/mnt/ar18_usb/boot"
    fi
  fi
done

crypt_uuid="$(lsblk -l -o name,uuid,mountpoint | grep sda1 | cut -d ' ' -f2)"
root_uuid="$(lsblk -l -o name,uuid,mountpoint | grep -E " /$" | xargs | cut -d ' ' -f1)"
crypt_resume_uuid="$(lsblk -l -o name,uuid,mountpoint | grep sda2 | cut -d ' ' -f2)"

echo "${ar18_sudo_password}" | sudo -Sk cp -rf "${script_dir}/grub.cfg" "/mnt/ar18_usb/boot/grub/grub.cfg"

echo "${ar18_sudo_password}" | sudo -Sk sed -i "s/{{CHOSEN_IMAGE}}/${chosen_image_basename}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"
echo "${ar18_sudo_password}" | sudo -Sk sed -i "s/{{CHOSEN_KERNEL}}/${chosen_kernel_basename}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"
echo "${ar18_sudo_password}" | sudo -Sk sed -i "s/{{CRYPT_UUID}}/${crypt_uuid}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"
echo "${ar18_sudo_password}" | sudo -Sk sed -i "s/{{ROOT_UUID}}/${root_uuid}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"
echo "${ar18_sudo_password}" | sudo -Sk sed -i "s/{{CRYPT_RESUME_UUID}}/${crypt_resume_uuid}/g" "/mnt/ar18_usb/boot/grub/grub.cfg"

##################################SCRIPT_END###################################
# Restore old shell values
set +x
for option in "${shell_options[@]}"; do
  eval "${option}"
done
# Restore LD_PRELOAD
LD_PRELOAD="${LD_PRELOAD_old}"
# Return or exit depending on whether the script was sourced or not
if [ "${ar18_sourced_map["${script_path}"]}" = "1" ]; then
  return "${ar18_exit_map["${script_path}"]}"
else
  exit "${ar18_exit_map["${script_path}"]}"
fi
