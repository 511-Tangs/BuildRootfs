#! /bin/bash
### Find eth0 usb lan irq 
# Get USB IRQ 
IRQUSBNUMBER=$( cat /proc/interrupts |grep xhci-hcd |awk -F ' ' '{print $13}' | sed 's/xhci-hcd\:usb//g' |tr "\n" " ")

# Get eth0 usb xhci-hcd number
Eth0UsbNumber=$(/bin/echo -ne "$(readlink -f /sys/class/net/eth0/)" | sed 's/\// /g' |tr " " "\n" |grep xhci-hcd)


# Testing IRQ Usb Number

for Irqtest in ${IRQUSBNUMBER}; do
    /bin/echo "${Eth0UsbNumber}" | grep "${Irqtest}" &>/dev/null
    if [ "$?" -eq "0" ]; then
	IRQ=$(cat /proc/interrupts |grep xhci-hcd| grep usb${Irqtest}|awk -F ':' '{print $1}')
	break
    fi
done

# Replace cpu list into Usb network ether card

/bin/echo "Select IRQ number is ${IRQ}"
/bin/echo "Default Using cpu core is $(cat /proc/irq/${IRQ}/smp_affinity_list)"
# Check root 
if [ $EUID -ne 0 ]
then /bin/echo "Super User passwd, please:"
     SUDO="sudo"
     ${SUDO} /bin/echo -e ""
     if [ $? -ne 0 ]; then
	 prt_err "Sorry, need su privilege!"
           
     fi
else
    SUDO=''
fi
${SUDO} /bin/bash -c "/bin/echo 4-7 > /proc/irq/${IRQ}/smp_affinity_list"
/bin/echo "Change Using cpu core is $(cat /proc/irq/${IRQ}/smp_affinity_list)"