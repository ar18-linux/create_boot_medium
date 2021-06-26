# create_boot_medium
create a bootable usb stick to boot the system the stick was created on. can be used as backup, but originally to use dropbear on an encrypted manjaro install, that has boot encrypted and could'nt be used with dropbear this way.

seems to be working reasonably well for the following manjaro installation: system encrypted with resumable encrypted swap, created by choosing the "Erase" option, i.e. no manual partitioning has taken place in the test system.

one thing to note: when hibernating, it will use the boot loader from the usb stick, but the one from the disk. ctrl alt del helps, but is useless since the whole excercise was to get dropbear working, which won't if the disk bootloader is used. normal reboots work fine though.
