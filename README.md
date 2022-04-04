# bootsync

Keep ESPs synchronized on mirrored-disk systems

# Requirements

- UEFI

# Dependencies

- bash
- systemd
- efibootmgr
- rsync
- coreutils (ln, mktemp)
- util-linux (mountpoint, findmnt)
- selinux-policy-devel (needed by sepolicy\_install)

# Installation

These scripts expect that the ESPs to be kept synchronized are mounted to directories named /boot@? where the question mark (?) is a single character in the range [a-z] that is unique to each ESP. The distinguishing character could, for example, correlate with the lettering of the corresponding SCSI disk device nodes that the ESPs are stored on (i.e. /dev/sda1 -> /boot@a, /dev/sdb1 -> /boot@b, etc.). Setting up such a correlation is just a recommendation. Only the pattern for the directory name matters. Where the /boot@? directories actually mount from is irrelevant to the scripts.

The /boot@? mountpoints are expected to be available early in the system start up process. This is usually accomplished by listing the mounts in the /etc/fstab system configuration file. For example, your /etc/fstab file might contain lines like the following:

    PARTLABEL=boot@a /boot@a vfat umask=0077,shortname=lower,context=system_u:object_r:boot_t:s0,nofail 0 0
    PARTLABEL=boot@b /boot@b vfat umask=0077,shortname=lower,context=system_u:object_r:boot_t:s0,nofail 0 0

The /boot directory should be empty and unmounted. These scripts will bind-mount /boot to whichever ESP is currently being used on system start up. You can disable the rc-bootbind systemd service and maintain the mount yourself if you wish, but /boot must be a bind mount to one of the /boot@[a-z] mountpoints.

Once the mountpoints are configured as the scripts expect, the scripts can be copied into place and enabled. A makefile is provide to automate the installation process. To install the scripts and the selinux policy using the makefile, run the following commands while in the root of the git repository:

    $ sudo make install
    $ sudo make sepolicy_install

# How it works

This software consists of two Bash scripts and two corresponding systemd services that call them on system start up. The scripts are quite short and simple. In the end, all the scripts do is call [rsync](https://en.wikipedia.org/wiki/Rsync) to copy the data from the active ESP to all other ESPs. The slightly complex part is in figuring out which is the ESP that the system is using and in performing a few safety checks to make sure a newer ESP (one containing a newer kernel) is not overwritten with the contents of an older ESP.

Only paths matching the machine id of the currently booted OS are copied from the current ESP to the secondary ESP(s). This sould be sufficient to synchronize the kernel, initramfs, and BLS loader entries across the ESPs. The currently booted OS's machine id is obtained from /etc/machine-id. The recommended way to synchronize other ESP content is to call `booctl update --esp-path=...` manually when necessary.

The Bash scripts are stored in /etc/rc.d. One is named rc.bootbind. It bind mounts one of the /boot@[a-z] mountpoints onto /boot. The other is named rc.bootsync. It calls rsync after performing a few basic safety checks. The Bash scripts can be run manually with sudo. They do not take any parameters. In fact, I recommend running them manually once right after they are installed to be sure that they are working properly. I also recommend making a backup copy of your ESPs before running them for the first time just to be safe.

Note that when calling the rc.bootsync command manually with selinux enabled, it will be running in a different selinux context than it does when called by the systemd startup scripts. Your selinux rules may block running the scripts manually depending on what permissive domains you have configured. You might need to temporarily set the *rsync\_t* domain to permissive mode to run the rc.bootsync command from the command line. Basically, do the following to test rc.bootsync manually with selinux enabled:

    $ sudo semanage permissive -a rsync_t
    $ sudo /etc/rc.d/rc.bootbind
    $ sudo /etc/rc.d/rc.bootsync
    $ sudo semanage permissive -d rsync_t

# Final notes

I use these scripts on Fedora systems (Workstation edition, not Silverblue) where I have my ESPs mounted to /boot@{a,b} and these partitions contain both the bootloader ([systemd-boot](https://www.freedesktop.org/wiki/Software/systemd/systemd-boot/)) and the kernel+initramfs. This configuration is recommended by the [Boot Loader Specification](https://systemd.io/BOOT_LOADER_SPECIFICATION/) which is part of the systemd project.

The GRUB bootloader is known to have problems with this configuration because it attempts to put a symlink below /boot. I have not tested these scripts with GRUB and I do not expect that they will work (properly) with GRUB. Feel free to try and get this to work with GRUB if you like, but my personal recommendation is to switch to using systemd-boot if possible. Please do not send pull requests to integrate GRUB compatibility features. I want to keep these scripts as simple as possible (no GRUB hacks please).

# Disclaimer

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
