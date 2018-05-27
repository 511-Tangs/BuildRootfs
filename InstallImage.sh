#!/bin/bash
# Function Table
# Print Help
function PrtHelp() {
    clear
    echo -ne "
Usage: $0 HostName CompressedRootfs(.tgz) TargetPath[,Tag] IP[,Netmask,Gateway] PartitionTableFile

Tips: HostName, the string to be stored in the /etc/hostname file of system.
Tips: CompressedRootfs created by command line:\" tar -cvzf ../odroidxu4.tgz . \"
Tips: TargetPath, x86 base computer read SD or eMMC by adapter and show on system as /dev/sdd.
Tips: TargetPath can using tag to mark which template you want to create, Support tags have SD, eMMC, VM. For example using /dev/sdd,eMMC will create eMMC image. Default will create SD image, If you want to create image  on eMMC, please add tag eMMC as /dev/ssd,eMMC.  
Tips: IP, the network IP address provide to target system. users can add gateway IP address 
to help this script find correct netmask and gateway/
Tips: PartitionTableFile, this parameter is optional. we may use it to custom format target partition.

"

}

# Print Info
function PrtInfo() {
    echo -ne "\e[1;49;92m[INFO] $@\e[m\n"
}

# Print Read
function PrtRead() {
    echo -ne "[READ] $2"
    read $1
}

# Print Warn
function PrtWarn() {
    echo -ne "\e[1;49;93m[WARN] $@\e[m\n"
}

# Print Error
function PrtErr() {
    echo -ne "\e[1;49;91m[ERROR] $@\e[m\n"
    exit 1
}

# Check Ip correct
function CheckIpFormat() {
    local len Ans ip ii
    len=$(echo $1 |tr "." "\n" |wc -l)
    if [ "$len" -eq "4" ]; then
        ii=1
        for ip in $(echo $1 |tr "." " "); do
            [[ $ip =~ ^[0-9]+$ ]] # IP addr is real number
            if [ "$?" -ne "0" ]; then
                Ans="No"
                break
            fi
            # without ip = [255 0].*.*.[255 0]
            if [ "$ii" == "1" ]; then
		if [ "$ip" -eq "255" ]; then
		    Ans="mask"
		    break
		elif [ "$ip" -lt 0 ] || [ "$ip" -ge 255 ] ; then
		    Ans='No'
		    break
		else
		    Ans='Yes'
		fi

	    elif [ "$ii" == "4" ]; then
                #  value <= 0 or value >= 255
                if [ "$ip" -le 0 ] || [ "$ip" -ge 255 ] ; then
			Ans="No"
			break
                else
                    Ans="Yes"
                fi

            else
                # value < 0 or value >=255
                if [ "$ip" -lt 0 ] || [ "$ip" -ge 255 ] ; then
                    Ans="No"
                    break
                else
                    Ans="Yes"
                fi
            fi
            ii=$(( $ii + 1 ))
        done
    else
        Ans="No"
    fi
    echo $Ans
}

# Transform NetMask
function TransNetmask() {
    local Mask mask ii jj number
    ii=0
    jj=32
    Mask=$1
    # According https://www.oav.net/mirrors/cidr.html web page for netmask transform
    # Replace mask from number ( 1 - 32 ) to 255.255.255.255
    # Mask 25 == 255.255.255.128 # 128 == 2 ^ 7                    # Range 1 - 127, 129 - 254
    # Mask 26 == 255.255.255.192 # 192 == 2 ^ 7 + 2 ^ 6            # Range 1 - 63, 65 - 127 , 129 - 191 , 193 - 254
    # Mask 27 == 255.255.255.224 # 192 == 2 ^ 7 + 2 ^ 6 + 2 ^ 5
    # ...
    # Mask 32 == 255.255.255.255 # 255 == 2 ^ 7 + ... + 2 ^ 0
    while [ "$jj" -gt "0" ]; do
        if [ "$Mask" -ge "8" ]; then
            mask[$ii]=255
            Mask=$(( $Mask - 8 ))
        else
            if [ "$Mask" -gt "0" ]; then
                number=0
                for ini in $(seq 7 -1 $(( 8 - $Mask ))); do
                    number=$(( $number + 2**$ini ))
                done
                mask[$ii]=$number
            else
                mask[$ii]="0"
            fi
            Mask="0"
        fi
        ii=$(( $ii + 1 ))
        jj=$(( $jj - 8 ))
    done
    # Replace mask from range 0 - 32 to *.*.*.*
    mask="${mask[0]}.${mask[1]}.${mask[2]}.${mask[3]}"
    echo "$mask"

}
# Check IP subnet
function check-same-subnet() {
    local ii ip ips Ans hostip hostmask hostips jj word mask checkip ip1 ip2 D2B ini HostMask HostIps hosteth IpNumbers gateway
    checkip=$2
    ips=($(egrep -o [0-9]+ <<< ${checkip} |tr "\n" " "))
    case $1 in
        subnet)

            # Using Bitwise AND test for hostmask
            # test ip1 value == ip2 value
            # An eth card my have multi ip address, will loop to test it.

            #Get host match eth card
            hosteth=$3

            #Get host ip match on eth card with route mark.
            HostIps=($(/sbin/ip addr show |grep inet |grep $hosteth |egrep -o 'inet [0-9]+.[0-9]+.[0-9]+.[0-9]+/[0-9]+' | sed 's/inet //g' ))
            #Get each host mask from host ip addr
            HostMask=($(echo ${HostIps[@]} |tr " " "\n" |awk -F '/' '{print $2}'))

            # Bitwise change function Range: 0 - 255
            D2B=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})

            # Length with multi ip addr
            IpNumbers="${#HostIps[@]}"

            #Reset Ans to empty
            Ans=''

            # Checking SameSubnetP exist
            SameSubnetP=$(which SameSubnetP)
            if [ -z $SameSubnetP ]; then

                for Len in $(seq 0 $((${IpNumbers} - 1 )) ); do

                    # Loading each host mask and change ip format to array.
                    hostmask=${HostMask[$Len]}
                    hostips=($(egrep -o [0-9]+ <<< ${HostIps[$Len]} ))
                    echo >&2 "Check same subnet between Guest:${ips[0]}.${ips[1]}.${ips[2]}.${ips[3]} and Host:${HostIps[$Len]} "
                    ii=0
                    jj=32
                    mask=''
                    mask=($(tr "." " " <<< $( TransNetmask $hostmask ) ))
                    # when hostmask > 8 , match Check ip address and host ip address
                    # After Check ip address, 'hostmask - 8' and loop again
                    # While hostmask < 8 , using binary value to check subnet
                    # Change hostmask to range 0 - 255 by using 0+ 2 ^ 7 + ... + 2 ^ ( 8 - hostmask )
                    # Creating mask, hostip and ips to binary code
                    # if mask = 1 , then check ips(0,1) == hostips(0,1) # Bitwise AND test 1 AND ( 1 , 0 ) == ( 1 ,0 )
                    # if mask = 0 , do nothing # 0 AND ( 1 , 0 ) == 0
                    # After check last hostmask < 8, jump out to loop

                    while [ "$jj" -gt "0" ]; do
                    # create mask bitwise value
                    # last mask = 2 ^ 7 + ... + 2 ^ ( 8 - hostmask )
                    # for example hostmask = 1, mask = 2 ^ 7 = 128 # hostmask = 2, mask= 2 ^ 7 + 2 ^ 6 = 192
                    # chnage ip value to binary value
                        if [ "${mask[$ii]}" == "255" ]; then
                            ip1="${ips[$ii]}"
                            ip2="${hostips[$ii]}"
                            if [ ! "$ip1" == "$ip2" ]; then
                                # echo >&2 "IP1: $2 not match on subnet"
                                Ans='No'
                            fi
                        elif [ "${mask[$ii]}" == "0" ];then
                            break
                        else
                            D2Bmask="${D2B[${mask[$ii]}]}"

                            # ( ip1 AND mask ) == ( ip2 AND mask ) test
                            for word in $(seq 1 8 ); do
                                netmaskword=$(cut -c $word <<< ${D2Bmask} )
                                if [ "$netmaskword" == "1" ]; then
                                    ip1test=$(cut -c $word <<< ${ip1} )
                                    ip2test=$(cut -c $word <<< ${ip2} )
                                    if [ "$ip1test" -ne "$ip2test" ]; then
                                        # echo >&2 "Mask: ${mask[$ii]} not match between $ip1 and $ip2"
                                        Ans='No'
                                    fi
                                fi
                            done
                        fi

                        # ii means shift test value, jj means max netmask 32
                        ii=$(( $ii + 1 ))
                        jj=$(( $jj - 8 ))
                    done

                    # Cause of multi ip address, Need to check Ans
                    # If Ans == No and not the last one, Clean Ans value for another test
                    if [ "$Ans" == "No" ] && [ "$Len" -lt "$((${IpNumbers} - 1 ))" ]; then
                        echo >&2 "Failed to match, test another host ip on same ether card "
                        echo >&2 " "
                        Ans=''
                    else
                    # If Ans =\= No , return gateway ip
                        gateway=$(awk -F '/' '{print $1}' <<<${HostIps[$Len]})
                        mask=$( TransNetmask $hostmask )
                        echo >&2 "IP1 :$checkip IP2:${HostIps[$Len]} "
                        echo >&2 "Netmask:$mask "
                        break
                    fi
                done

            else
                # Test multi IP address
                for Len in $(seq 0 $((${IpNumbers} - 1 )) ); do

                    # Loading each host mask and change ip format to array.
                    hostmask=${HostMask[$Len]}
                    ii=0
                    jj=32
                    mask=''
                    mask=$( TransNetmask $hostmask )
                    ip2=$(awk -F '/' '{print $1}'  <<<${HostIps[$Len]})
                    Return=$($SameSubnetP  $checkip $ip2 ${mask} ) # ip2 for hostip
                    echo >&2 ""
                    if [ "x$Return" == "x0" ]; then
                        Ans='Yes'
                    else
                        Ans='No'
                    fi

                    # If Ans == No and not the last one, Clean Ans value for another test
                    if [ "$Ans" == "No" ] && [ "$Len" -lt "$((${IpNumbers} - 1 ))" ]; then
                        Ans=''
                    else
                    # If Ans =\= No , return gateway ip
                        gateway=$(awk -F '/' '{print $1}' <<<${HostIps[$Len]})
                        break
                    fi
                done
            fi


            if ! [ "$Ans" == "No" ]; then
                Ans="Yes"
                echo $Ans $gateway $mask
                echo >&2 "CheckIP: $2 match on Host subnet: ${HostIps[$Len]} "
                echo >&2 " "
            fi

        ;;
        private)
        # 192.168.0.0 ip address
        if [ "${ips[0]}" == "192" ] && [ "${ips[1]}" == "168" ]; then
            Ans=Yes
        # 172.16.0.0 - 172.32.0.0 ip address
        elif [ "${ips[0]}" == "172" ] && [  "${ips[1]}" -ge "16" ] && [ "${ips[1]}" -le "32"  ]; then
            Ans=Yes
        # 10.0.0.0 ip address
        elif [ "${ips[0]}" == "10" ]; then
            Ans=Yes
        else
            Ans=No
        fi
        echo $Ans

        ;;
	*)

    esac

}
# Check Image file
function CheckImageFile() {
    local image Ans Type test Ans Return
    # Support link image
    test -L $1 &>/dev/null
    if [ "$?" -eq "0" ]; then
        image=$(readlink -f $1)
    else
        image=$1
    fi
    # data type for raw
    test=$(file $image |egrep -o data)
    if [ "$test" == "data" ]; then
        Ans="Yes"
	Return='Image'
    fi
    # block type for /dev/sd*
    test=$(file $image |egrep -o block )
    if [ "$test" == "block" ]; then
        Ans="Yes"
	Return='Disk'
    fi
    # Check file by fdisk
    if [ ! "$Ans" == "Yes" ]; then
        Type=$(${SUDO} fdisk -l $image 2>/dev/null |egrep -o "Disklabel type:.*$" |sed 's/Disklabel type: //g' )
        # echo No if Ans is not Yes
        # Partition table type : msdos, dos, gpt, loop
        case $Type in
            msdos)
                 Ans="Yes"
		 Return='Image'
                 ;;
            dos)
                 Ans="Yes"
		 Return='Image'
                 ;;
            gpt)
                 Ans="Yes"
		 Return='Image'
                 ;;
            loop)
                 Ans="Yes"
		 Return='Image'
                 ;;
            *)
                 Ans="No"
        esac
	
    fi
	
    if [ "$Ans" == "Yes" ]; then
	echo "Yes"
	echo "$Return"
    else
	echo >&2 "Image type:$Type not support."
	echo "No"
    fi
}

# Main script
DATE=$(date +%y%m%d%H%M%S)
# Check Value
if [ "$#" -ge "4" ]; then
    HostName=$1
    CompressRootfs=$2
    Disk=($(tr "," " " <<< $3 )) # Replace TargetPath as array.
    TargetPath=${Disk[0]}
    if [ "${#Disk[@]}" -gt "1" ]; then
	TargetType=${Disk[1]}
    else
	TargetType=SD
    fi
    Net=($(tr "," " " <<< $4 )) # Replace Net value as array.
    if [ "$#" -eq "5" ]; then
	PartitionTable=$(realpath $5 )
	if ! cat $PartitionTable |grep root &>/dev/null ;then
	    PrtErr "No root partition found on $PartitionTable."
	fi
	if [ $( cat $PartitionTable |grep root |wc -l ) -gt "1" ];then
	    PrtErr "Multi root partition found on $PartitionTable."
	fi
    fi
else
    PrtHelp
    exit 127
fi

# Test tgz file can unzip
PrtInfo "Testing $CompressRootfs file can decompress by tar."
if tar -tzf $CompressRootfs &>/dev/null; then
    PrtInfo "CompressRootfs test: success."
else
    PrtErr "CompressRootfs test: failed, $CompressRootfs cannot decompress by tar -zxvf $CompressRootfs. "
    
fi

#Check net and gateway
Ans=$(CheckIpFormat ${Net[0]})
if [ "$Ans" == "Yes" ]; then
    IP="${Net[0]}"
else
    PrtErr "IP format error."
fi

for ii in $(seq 1 $((${#Net[@]} - 1 ))); do
    Ans=$(CheckIpFormat ${Net[$ii]})
    if [ "$Ans" == "Yes" ]; then
	Gateway=${Net[$ii]}
    elif [ "$Ans" == "mask" ];then
	Mask=${Net[$ii]}
    fi
done

#Get gateway IP
if [ -z "$Gateway" ]; then
    for eth in $(/sbin/ip addr show |egrep inet |egrep global |awk -F ' ' '{print $7}'|tr "\n" " "); do
	if [ "$CheckGw" == "Yes" ]; then
	    break # Found Gateway IP and jump out loop
	fi
	echo "Testing host ethernet: $eth"
	Ans=($(check-same-subnet subnet ${IP} ${eth}))
	if [ "${Ans[0]}" == "Yes" ]; then
	    Gateway=${Ans[1]}
	    Mask=${Ans[2]}
	    if /sbin/ip route show |grep via |grep $eth &>/dev/null;then
		GW=($(/sbin/ip route show |grep via | grep $eth |awk -F ' ' '{print $3 }'))
		if [ ! -z "${GW[@]}" ]; then
		    for gw in ${GW[@]}; do
			Ans=($(check-same-subnet subnet $gw $eth))
			if [ "${Ans[1]}" == "$Gateway" ]; then
			    Gateway=$gw
			    PrtInfo "IP address has same subnet at host, using $Gateway as gateway IP." 
			    CheckGw='Yes'
			    break # Found and jump out loop
			fi
		    done
		fi
	    fi
	fi
    done
    # Not found Gateway
    if [ ! "$CheckGw" == "Yes" ]; then
	PrtInfo "Cannot found gateway IP at host, checking harder ..."
	Ans=$(check-same-subnet private $IP)
	if [ "$Ans" == "Yes" ]; then
	    PrtInfo "Target system using private IP but no gateway IP found. "
	    PrtRead GatewayHost "Please input Target system default gatewa's Host IP:"
	    if ping -c3 $GatewayHost &>/dev/null; then
		PrtInfo "Start to connect gateway host"
		Net=($(ssh -t $(whoami)@$GatewayHost ' ip route show' 2>/dev/null |grep 'scope link'  | egrep -o "$(egrep -o "[0-9]+.[0-9]+.[0-9]+."<<<${IP})0.*$" |tr " " "\n" |sed '/^$/d'|  egrep  "$(egrep -o "[0-9]+.[0-9]+.[0-9]+."<<<${IP})"))
		Mask=$( TransNetmask $(awk -F '/' '{print $2}' <<< ${Net[0]} ) )
		Gateway=${Net[1]}
		CheckGw='Yes'
	    else
		PrtWarn "Gateway Host cannot connect, Target system using private IP without gateway."
	    fi
	else
	    PrtWarn "Gateway IP not found and Target system using public IP."
	fi
    fi
else
    if [ -z "$Mask" ]; then
	Mask=255.255.255.0
    fi
    CheckGw='Yes'
fi

# End gateway checking
PrtInfo "Gateway IP:$Gateway with mask:$Mask."

# Get Root permission
PrtInfo "Super user permission test"
echo "Super User passwd, please:"
if [ $EUID -ne 0 ]
   then sudo echo -ne ""
        if [ $? -ne 0 ]
            then  PrtErr "Sorry, need su privilege!"
        else
            PrtInfo "Super user permission  test: succeed."
            SUDO=$(which sudo)
        fi
else
    SUDO=''
fi


# Testing target file is block disk
PrtInfo "Testing $TargetPath image."
Ans=($(CheckImageFile $TargetPath))
if [ "${Ans[0]}" == "Yes" ]; then
    PrtInfo "TargetPath test: success. TargetPath mode: ${Ans[1]}"
    ImageType=${Ans[1]}
else
    PrtErr "TargetPath test: failed, $TargetPath is not an image file."
    
fi

# Read Partition table
if [ -z "$PartitionTable" ]; then
    PrtInfo "Using default partition table"
    if [ "$ImageType" == "Disk" ]; then
	PrtInfo "1:boot:8192:512M"
	PrtInfo "2:root:512M:100%"
    else
	PrtInfo "1:boot:2048:512M"
	PrtInfo "2:root:512M:100%"
    fi
    PartitionMode='Base'
else
    PrtInfo "Reading partition table on partition file."
    PartitionMode='Custom'
fi
if ! which fdisk &>/dev/null ; then
    PrtErr "Please install fdisk package first."
fi

PrtInfo "Clean partition info at target."
# Clean disk table
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | ${SUDO} fdisk $TargetPath
o # clear the in memory partition table
w # write
q # quit
EOF

PrtInfo "Create partiitions at target."
# Create Image partition and format
case $PartitionMode in
    Base)

    if [ "$ImageType" == "Disk" ]; then
	sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | ${SUDO} fdisk $TargetPath
o # clear the in memory partition table
n # new partition
p # primary partition
1 # partition number 1
8192  # default 4 MB
+512M # 100 MB boot parttion
n # new partition
p # primary partition
2 # partion root
1056768 # default, start immediately after preceding partition
  # full size root partition
w # write
q # quit
EOF
    else
	sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | ${SUDO} fdisk $TargetPath
n # new partition
p # primary partition
1 # partition number 1
2048 # default 4 MB
999423 # 100 MB boot parttion
n # new partition
p # primary partition
2 # partion root
999424 # default, start immediately after preceding partition
  # full size root partition
w # write
q # quit
EOF
    fi
    ;;
    Custom)
      if [ "$ImageType" == "Disk" ]; then
	  PrtInfo "Custom create partition table with disk."
      else
	  PrtInfo "Custom create partition table with raw image."
      fi

      PartitionNumber=($(cat $PartitionTable |sed '/^#/d' |awk -F ':' '{print $1}'))
      PartitionName=($(cat $PartitionTable |sed '/^#/d' |awk -F ':' '{print $2}'))
      PartitionStartSector=($(cat $PartitionTable |sed '/^#/d' |awk -F ':' '{print $3}'))
      PartitionEndSector=($(cat $PartitionTable |sed '/^#/d' |awk -F ':' '{print $4}'))
      PartitionFormat=($(cat $PartitionTable |sed '/^#/d' |awk -F ':' '{print $5}'))
      LenPartition=${#PartitionNumber[@]}
      for ii in $(seq 0 $(( ${LenPartition} - 1 ))); do
	  if [[ "${PartitionNumber[$ii]}" =~ ^[0-9]+$ ]]; then
	      if [ "${PartitionNumber[$ii]}" -le "4" ]; then
                  # Create extended partition
		  cat <<EOF |${SUDO}  fdisk $TargetPath
n
p
${PartitionNumber[$ii]}
${PartitionStartSector[$ii]}
${PartitionEndSector[$ii]}
w
q
EOF
                  #Format partition
	      else
                  # Create extended partition
		  cat <<EOF |${SUDO}  fdisk $TargetPath
n
${PartitionStartSector[$ii]}
${PartitionEndSector[$ii]}
w
q
EOF
                  # Format partition
	      
	      fi
	  else
	      # Create full extended partition
	      cat <<EOF |${SUDO}  fdisk $TargetPath
n
${PartitionNumber[$ii]}
${PartitionStartSector[$ii]}
${PartitionEndSector[$ii]}
w
q
EOF

	  fi
	  sleep 2
      done
    ;;
    
esac

# Install bootloader into SD image
if [ "$TargetType"  == "SD" ]; then
    if [ -d ./xu4_blobs ]; then
	if [ -f ./xu4_blobs/sd_fusing.sh ]; then
	    PrtInfo "Start to install bootloader into SD image."
	    cmd=$(pwd)
	    cd xu4_blobs
	    if [ ! -x ./sd_fusing.sh ]; then
		PrtInfo "sd_fusing.sh cannot exec, add exec type for shell script."
		${SUDO} chmod +x ./sd_fusing.sh
	    fi
	    ${SUDO} ./sd_fusing.sh $TargetPath
	    cd $cmd
	else
	    PrtWarn "SD image not found bootloader installer, is there any directory name xu4_blobs with file ./xu4_blobs/sd_fusing.sh?"
	fi
    fi
else
    PrtInfo "Only target tag SD will install bootloader."
fi

# Mount TargetPath into system
PrtInfo "Mount target path into system."
if [ "$ImageType" == "Disk" ]; then
    targetpath=$TargetPath
else
    
    loopdev=$(${SUDO} losetup -f --show $TargetPath)
    targetpath=${loopdev}p
    ${SUDO} partx -av $loopdev
fi
mkdir /tmp/tmp-$DATE
case $PartitionMode in
    Base)
      #Mount root
      ${SUDO} mkfs.ext2 ${targetpath}1 -F -L boot 
      ${SUDO} mkfs.ext4 ${targetpath}2 -F -L root
     sleep 2 
      ${SUDO} mount ${targetpath}2 /tmp/tmp-$DATE
      # Mount boot
      ${SUDO} mkdir -p /tmp/tmp-$DATE/boot
      ${SUDO} mount ${targetpath}1 /tmp/tmp-$DATE/boot
    ;;

    Custom)
    # Select Mount root path 
    RootInfo=($(cat $PartitionTable |grep root |tr ":" " "))
    RootNumber=${RootInfo[0]}
    RootName=${RootInfo[1]}
    RootFormat=${RootInfo[4]}
    ${SUDO} mkfs.${RootFormat} ${targetpath}${RootNumber} -F -L ${RootName}
    ${SUDO} mount ${targetpath}${RootNumber} /tmp/tmp-$DATE
    # Mount usr and usrlocal
    UsrNumber=($(cat $PartitionTable |grep usr |awk -F ':' '{print $1}'))
    loop=''
    while [ "a$loop" == "a" ]; do
	if [[ "a${#UsrNumber[@]}" == "a0" ]]; then
	    break
	fi
	for num in ${UsrNumber[@]}; do
	    path=$(cat $PartitionTable |grep "^$num" |awk -F ':' '{print $2}' )
	    format=$(cat $PartitionTable| grep "^$num" |awk -F ':' '{print $5}')
	    case $path in
		usr)
	          if [ ! -d /tmp/tmp-$DATE/usr ]; then
		      ${SUDO} mkdir -p /tmp/tmp-$DATE/usr
		  fi
		  ${SUDO} mkfs.$format ${targetpath}${num} -F -L usr
		  ${SUDO} mount ${targetpath}${num} /tmp/tmp-$DATE/usr
		
		;;
		usrlocal)
	          if [ ! -d /tmp/tmp-$DATE/usr ]; then
		      continue
		  else
		      if [ ! -d /tmp/tmp-$DATE/usr/local/ ]; then
			  ${SUDO} mkdir -p /tmp/tmp-$DATE/usr/local
		      fi
		      ${SUDO} mkfs.$format ${targetpath}${num} -F -L usrlocal
		      ${SUDO} mount ${targetpath}${num} /tmp/tmp-$DATE/usr/local
		      loop="stop"
		  fi
		
		;;*)
		continue
	    esac
	done
    done
    # Mount others path
      for ii in $(seq 0 $(( ${LenPartition} - 1 ))); do
	  case "${PartitionName[$ii]}" in
	      "root")
	      continue
	      ;;
	      "usr")
	      continue
	      ;;
	      "usrlocal")
	      continue
	      ;;
	      "extended")
              continue
	      ;;
	      "swap")
	      ${SUDO} mkswap ${targetpath}${PartitionNumber[$ii]} 
	      ;;
	      *)
	      if [ ! -d /tmp/tmp-$DATE/${PartitionName[$ii]} ]; then
		  ${SUDO} mkdir -p /tmp/tmp-$DATE/${PartitionName[$ii]}
	      fi
	      ${SUDO} mkfs.${PartitionFormat[$ii]} ${targetpath}${PartitionNumber[$ii]} -F -L ${PartitionName[$ii]}
	      ${SUDO} mount ${targetpath}${PartitionNumber[$ii]} /tmp/tmp-$DATE/${PartitionName[$ii]}
	      
	  esac
      done
	
    ;;*)
    
esac


# Decompress rootfs into target path
PrtInfo "Starting decompress rootfs into target."
${SUDO} tar -zxf $CompressRootfs -C /tmp/tmp-$DATE

# Create host name, network and fstab

# Host name replace
PrtInfo "Overwrite Host name."
${SUDO} sed -i "s/localhost/localhost $HostName /g" /tmp/tmp-$DATE/etc/hosts
${SUDO} /bin/bash -c "echo $HostName > /tmp/tmp-$DATE/etc/hostname"
cat /tmp/tmp-$DATE/etc/hosts 
cat /tmp/tmp-$DATE/etc/hostname
# fstab # Default using SD type
case "$TargetType" in
    [sS][dD])
    FixDisk="/dev/mmcblk1p"
    ;;
    [eE][mM][mM][cC])
    FixDisk="/dev/mmcblk0p"
    
    ;;[vV][mM])
    FixDisk="/dev/vda"
    
    ;;*)
    FixDisk="/dev/mmcblk1p"
    
esac
# Create base
cat <<EOF >fstab
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>

EOF

# Create image fstab and overwrite uEnv

case "$PartitionMode" in
    "Base")
    echo "${FixDisk}1    /boot  ext2    defaults        0       2" >> fstab
    echo "${FixDisk}2    /      ext4    errors=remount-ro       0       1" >> fstab
    echo "rootdev=${FixDisk}2 " >uEnv.txt
    echo "rootfstype=ext4 " >>uEnv.txt
    ;;
    "Custom")
      for ii in $(seq 0 $(( ${LenPartition} - 1 ))); do
	  case "${PartitionName[$ii]}" in
	      "root")
	      echo "${FixDisk}${PartitionNumber[$ii]}    /      ${PartitionFormat[$ii]}    errors=remount-ro       0       1" >> fstab
	      echo "rootdev=${FixDisk}${PartitionNumber[$ii]} " >uEnv.txt
	      echo "rootfstype=${PartitionFormat[$ii]} " >>uEnv.txt
	      ;;
	      "usrlocal")
	      echo "${FixDisk}${PartitionNumber[$ii]}    /usr/local      ${PartitionFormat[$ii]}    defaults       0       2" >> fstab
	      
	      ;;
	      "extended")
	      continue
	      ;;
	      
	      *)
	      echo "${FixDisk}${PartitionNumber[$ii]}    /${PartitionName[$ii]}   ${PartitionFormat[$ii]}    defaults       0       2" >> fstab
	  esac
      done
    
    ;;*)
    
esac
# Overwrite Target fstab
PrtInfo "Overwrite Target fstab."
cat fstab
${SUDO} mv fstab /tmp/tmp-$DATE/etc/fstab

# Overwrite Target uEnv.txt
PrtInfo "Overwrite target uEnv.txt"
echo "verbosity=8" >> uEnv.txt
cat uEnv.txt
${SUDO} mv uEnv.txt /tmp/tmp-$DATE/boot/uEnv.txt

# Create network interface
# Base interface
cat <<EOF >interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

EOF

if [ "$CheckGw" == "Yes" ]; then
    cat <<EOF >> interfaces

# The primary network interface
auto eth0
iface eth0 inet static
        address $IP
        netmask $Mask
        gateway $Gateway

EOF

else
    cat <<EOF >> interfaces

# The primary network interface
auto eth0
iface eth0 inet static
        address $IP

EOF
    
fi

PrtInfo "Overwrite target network."
cat interfaces
${SUDO} mv interfaces /tmp/tmp-$DATE/etc/network/interfaces

#Clean 70-net-rules
if [ -f /tmp/tmp-$DATE/etc/udev/rules.d/70-persistent-net.rules ]; then
    PrtInfo "Clean udev network rules."
    ${SUDO} rm /tmp/tmp-$DATE/etc/udev/rules.d/70-persistent-net.rules
fi
# Check if rootfs no have kernel and type is VM.
if [ -f /tmp/tmp-$DATE/boot/zImage ]; then
    PrtInfo "Find kernel file, start custom"
else
    if [ "$TargetType" == "VM" ]; then
	PrtInfo "No kernel found, start install base kernel"
	if [ -f /tmp/tmp-$DATE/usr/bin/qemu-arm-static ]; then
	    PrtInfo "Start chroot and install kernel."
	    Status='ok'
	else
	    if [ -f /usr/bin/qemu-arm-static ]; then
		PrtInfo "Copy qemu-arm into system and chroot to install kernel."
		${SUDO} cp /usr/bin/qemu-arm-static /tmp/tmp-$DATE/usr/bin/qemu-arm-static
		Status='ok'
	    else
		PrtWarn "No qemu-arm-static found on /usr/bin."
		Status='failed'
	    fi
	fi
	if [ "$Status" == "ok" ]; then
	    ${SUDO} chroot /tmp/tmp-$DATE /bin/bash -c "apt-get update"
            ${SUDO} chroot /tmp/tmp-$DATE /bin/bash -c "apt-get install -t 'jessie-backports' -y linux-image-4.9.0-0.bpo.5-armmp-lpae linux-headers-4.9.0-0.bpo.5-common"
	    ${SUDO} chroot /tmp/tmp-$DATE /bin/bash -c "apt-get clean"
	    ${SUDO} rm /tmp/tmp-$DATE/usr/bin/qemu-arm-static
	fi

    else
	PrtWarn "No kernel found, need to install kernel first."
    fi
fi

# Put bootlaoder into SD image  
if [ "$TargetType"  == "SD" ]; then
    if [ -d ./xu4_blobs ]; then
	if [ -f ./xu4_blobs/sd_fusing.sh ]; then
	    PrtInfo "Put bootloader installer into SD image at /src/uboot/."
	    if [ ! -d /tmp/tmp-$DATE/src/uboot ]; then
		${SUDO} mkdir -p /tmp/tmp-$DATE/src/uboot
	    fi
	    ${SUDO} cp -a ./xu4_blobs/* /tmp/tmp-$DATE/src/uboot
	else
	    PrtWarn "SD image not found bootloader installer, is there any directory name xu4_blobs with file ./xu4_blobs/sd_fusing.sh?"
	fi
    fi
fi


PrtInfo "umount target from system."
# Umount target 
case "${PartitionMode}" in
    Base)
    ${SUDO} umount /tmp/tmp-$DATE/boot /tmp/tmp-$DATE/
    ;;
    Custom)
    
    for ii in $(seq 0 $(( ${LenPartition} - 1 ))); do
	case "${PartitionName[$ii]}" in
	    "root")
	    continue
	    ;;
	    "usr")
	    continue
	    ;;
	    "usrlocal")
	    continue
	    ;;
	    "extended")
	    continue
	    ;;
	    *)
	    ${SUDO} umount /tmp/tmp-$DATE/${PartitionName[$ii]}
	    
	esac
    done
    
    loop=''
    utype='' # umount type
    while [ "$loop" != "stop" ]; do
	if [[ -z "${UsrNumber[@]}" ]]; then
	    break
	fi
	for num in ${UsrNumber[@]}; do
	    path=$(cat $PartitionTable |grep "^$num" |awk -F ':' '{print $2}' )
	    case $path in
		usr)
		if [ "$(mount |grep "/tmp/tmp-$DATE/usr" |wc -l )" -gt "1" ]; then
		    continue
		else
		    ${SUDO} umount /tmp/tmp-$DATE/usr
		    loop="stop"
		fi
		
		;;
		usrlocal)
		if [ "$utype" == "done" ]; then
		    continue
		else
		    ${SUDO} umount /tmp/tmp-$DATE/usr/local
		    utype=done
		fi
		
		;;
		*)
	    esac
	done
    done
    
    
    ;;*)
    
esac
if [ "$(mount |grep /tmp/tmp-$DATE  |wc -l )" -eq "1" ]; then
    ${SUDO} umount /tmp/tmp-$DATE
    ${SUDO}  rm -rf /tmp/tmp-$DATE
fi
if [ "$ImageType" == "Disk" ]; then
    PrtInfo "Finsh create target system."
    
else
    ${SUDO} losetup -d $loopdev
    ${SUDO} partx -dv $loopdev
    PrtInfo "Finsh create target system."

fi
    
