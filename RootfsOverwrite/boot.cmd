# Loading address
# run bootcmd_mmc0
setenv load_addr "0x44000000"
setenv kerneladdr "0x40800000"
setenv initrdaddr "0x42000000"
setenv dtbaddr "0x44000000"
# default values (configurable)

setenv rootdev "/dev/mmcblk1p2"
setenv rootfstype "ext4"
# IPaddress:NFSserverIP:GatewayIP:Netmask:Hostname:ethercard
# setenv ips "192.168.0.1::192.168.0.254:255.255.255.0::eth0"
# Console
setenv console "both"
verbosity=1
if test "${console}" = "display" || test "${console}" = "both"; then setenv consoleargs "console=tty1"; fi
if test "${console}" = "serial" || test "${console}" = "both"; then setenv consoleargs "${consoleargs} console=ttySAC2,115200n8"; fi

# Append environment
if load mmc 0:1 ${load_addr} uEnv.txt; then
        env import -t ${load_addr} ${filesize}
fi

setenv bootargs "${consoleargs} root=${rootdev} rootfstype=${rootfstype} rootwait panic=10 consoleblank=0 loglevel=${verbosity} ip=${ips}"

# Load default file
# system dependent: mmcbootdev, mmcbootpart
load mmc ${mmcbootdev}:${mmcbootpart} ${kerneladdr} zImage
load mmc ${mmcbootdev}:${mmcbootpart} ${initrdaddr} uInitrd
load mmc ${mmcbootdev}:${mmcbootpart} ${dtbaddr} dtb/exynos5422-odroidxu4-kvm.dtb


# Boot

bootz ${kerneladdr} ${initrdaddr} ${dtbaddr}

# Generate boot.scr:
# mkimage -c none -A arm -T script -d boot.cmd boot.scr
