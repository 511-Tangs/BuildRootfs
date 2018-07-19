#!/bin/bash
# BaseValue
BasePkg='dselect'
FullPkg="u-boot-tools bash-completion sudo openssh-client openssh-server aptitude autotools-dev bisonc++ bison bzip2 deborphan isc-dhcp-client emacs flex gcc g++ gfortran less libatlas-base-dev libatlas-test libblas-dev libblas-doc libc6-dev liblapack-doc libltdl-dev libopenmpi-dev libpng12-0 lynx make netcat nmap openmpi-bin openmpi-common openmpi-doc synaptic tcpdump traceroute xaw3dg xterm xauth ca-certificates e2fsprogs curl apt-utils parted mawk tmux screen ntpdate elinks firmware-linux-free zsh git-core locales tree jadetex latex2html texlive-base texlive-fonts-recommended texlive-latex-base texlive-latex-recommended texlive texlive-base texlive-bibtex-extra texlive-binaries texlive-extra-utils texlive-font-utils texlive-fonts-recommended texlive-fonts-recommended-doc texlive-generic-recommended texlive-latex-base texlive-latex-base-doc texlive-latex-extra texlive-latex-extra-doc texlive-latex-recommended texlive-latex-recommended-doc texlive-luatex texlive-pictures texlive-pictures-doc texlive-pstricks texlive-pstricks-doc texlive-science texlive-science-doc iperf iperf3 ethtool dnsutils geoip-bin sshfs fuse usbutils file hdparm"
ReplaceFile="./RootfsOverwrite/NoteForFiles.txt"


if [ -z $1 ]; then
    BasePkg="$BasePkg $FullPkg"
    SecPkg="fail2ban task-xfce-desktop lightdm"
    echo "Install full package."
    echo "If you want to custom pkg using '$0 [pkglist file|mini] ' to provite system pkg."
else
    if [ -f $1 ]; then
	echo "Loading package file $1."
	CustomPkg=$(cat $1 |tr "\n" " " )
	BasePkg="$BasePkg $CustomPkg"
	if [ -f $2 ]; then
	    SecPkg=$(cat $2 |tr "\n" " " )
	fi
    else
	echo "Load mini package."
	MiniPkg="acpid acpi-support-base qemu-guest-agent u-boot-tools initramfs-tools bash-completion sudo live-boot-initramfs-tools live-boot openssh-client openssh-server aptitude  autotools-dev  bisonc++  bison  bzip2  deborphan  emacs  flex  gcc  g++  gfortran  less  libatlas-base-dev  libatlas-test  libblas-dev  libblas-doc  libc6-dev  liblapack-doc  libltdl-dev  libpng12-0  lynx  make  netcat  nmap  synaptic  tcpdump  traceroute  xaw3dg  xterm  xauth ca-certificates curl apt-utils parted screen ntpdate rsync locales tree "
	BasePkg="$BasePkg $MiniPkg"
    fi

fi


Mirror="http://amd1m/merged"
Distro="jessie"
# Arch
Arch=armhf

# Get Root permission
echo "Super user permission test"
echo "Super User passwd, please:"
if [ $EUID -ne 0 ]
   then sudo echo -ne ""
        if [ $? -ne 0 ]
            then echo "Sorry, need su privilege!"
	    exit 127
        else
            echo "Super user permission  test: succeed."
            SUDO=$(which sudo)
        fi
else
    SUDO=''
fi


# Debootstrap package test
which debootstrap &>/dev/null
if [ "$?" -ne "0" ]; then
    echo "No debootstrap found, please install debootstrap first."
    exit 127
fi
#Free space test 
Date=$(date +%y%m%d%H%M%S)
Space=$(df . -BG|awk -F ' ' '{print $4}'|sed 1d |sed 's/[a-zA-Z]//g')
if [ "$Space" -lt "8" ]; then
    echo "Space: $Space GB not enought to create rootfs, using larger than 8 GB space."
    exit 127
fi

# Testing binfmt_misc module
if [ -f /usr/bin/qemu-arm-static ]; then

    lsmod|grep binfmt_misc &>/dev/null
    if [ "$?" -ne "0" ]; then
	echo "Not using binfmt_misc modules, loading...."
	sudo modprobe binfmt_misc
	lsmod|grep binfmt_misc &>/dev/null
	if [ "$?" -eq "0" ]; then
	    echo "Loading binfmt_misc success."
	else
	    echo "Failed to load binfmt_misc module, please check linux kernel module: binfmt_misc."
	    exit 127
	fi
    fi
else
    echo "Install QEMU user mode emulation: qemu-user-static first."
    exit 127
fi

# Create rootfs 
mkdir -p ${Date}
# First stage
echo "Start first stage of debootstrap rootfs."
${SUDO} debootstrap --foreign --arch=$Arch --include=$(tr " " "," <<<$BasePkg ) --exclude=udev $Distro $Date $Mirror
# Setting ARM type
${SUDO} cp /usr/bin/qemu-arm-static $Date/usr/bin/

#Secondary stage
echo "start secondary stage of debootstrap rootfs."
${SUDO} chroot  $Date /debootstrap/debootstrap --second-stage

# Install initramfs tools
${SUDO} chroot $Date /bin/bash -c "apt-get update ;apt-get install udev -y"
${SUDO} chroot $Date /bin/bash -c "aptitude install initramfs-tools  -y"

#Custom rootfs
echo "Start chroot to setup custom enviorment."

if [ -d ./RootfsOverwrite ]; then
    if [ -f $ReplaceFile ]; then
	files=($(cat $ReplaceFile | awk -F ':' '{print $1}'))
	paths=($(cat $ReplaceFile | awk -F ':' '{print $2}'))
	lanfile=${#files[@]}
	lanpath=${#paths[@]}
	for ii in $(seq 0 $(( $lanfile - 1 ))); do
	    if [ -f ./RootfsOverwrite/${files[$ii]} ]; then
		if [ ! -d $Date/${paths[$ii]} ]; then
		    ${SUDO} mkdir -p $Date/${paths[$ii]}
		fi
		${SUDO} cp RootfsOverwrite/${files[$ii]} $Date/${paths[$ii]}
	    fi
	done
    else
	echo "No NoteForFiles.txt file in RootfsOverwrite, if you want to custom file into rootfs you need to create NoteForFiles.txt into RootfsOverwrite directory."
	echo "NoteForFiles.txt example:"
	echo "Files name : Files directory"
	echo "05translations : /etc/apt/apt.conf.d/"
	echo ""

    fi
else
    echo "No RootfsOverwrite directory found, no custom setting for rootfs."
fi

# Base rootfs setup
${SUDO} chroot $Date /bin/bash -c "locale-gen en_US en_US.UTF-8"
${SUDO} chroot $Date /bin/bash -c "localedef -i en_US -f UTF-8 en_US.UTF-8"
${SUDO} sed -i 's/\/usr\/local\/bin:\/usr\/bin:\/bin:\/usr\/local\/games:\/usr\/games/.:\/usr\/local\/bin:\/usr\/local\/sbin:\/usr\/bin:\/usr\/sbin:\/bin:\/sbin/g' $Date/etc/profile
# Setup remove all USB device connect when reboot or halt.
if [ -f $Date/etc/init.d/SafeRemoveAllUsbDevice ]; then
    echo "Setting SafeRemoveAllUsbDevice up"
    ${SUDO} chroot $Date /bin/bash -c "update-rc.d SafeRemoveAllUsbDevice defaults"
fi
# Install e2fs package
${SUDO} chroot $Date /bin/bash -c "aptitude update ; aptitude safe-upgrade -y ; aptitude install -t jessie-backports e2fsprogs e2fslibs -y "
# Install secondary packages
if ! [ "a$SecPkg" == "a" ]; then
    ${SUDO} chroot $Date /bin/bash -c "aptitude update ; aptitude install $SecPkg --without-recommends -y ; aptitude clean ;apt-get autoremove ;apt-get autoclean"
    
fi
#Tar rootfs

cmd=$(pwd)
cd $Date 
echo "Start to compress rootfs into rootfs-$Date.tgz file"
${SUDO} tar -czf ../rootfs-$Date.tgz .
cd $cmd
${SUDO} rm -rf $Date
echo "Finsh create rootfs. "
