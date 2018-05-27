#!/bin/bash
### Function table
function prt_err() {
    echo -e "$1"
    exit 1 
}

function prt_help() {
    echo -e "This script is used to control lower limit temp for fan to run"
    echo -e "This script will use CPU0 temp to control fan speed"
    echo -e "In this script temp is using degree celsius"
    echo -e "Fan_speed means percent of Fan max speed, for example 20 means 20% of Max fan speed \n "
    echo -e "Please Using this command to change lower limit temp for fan"
    echo -e "$0 change Fan_min_temp Fan_speed"
    echo -e "$0 status"
}

function check_real_number() {
    local value
    value=$1
    if [[ "${value}" =~ ^[0-9]+$ ]]; then
	echo -e "True"
    else
	prt_err "lower limit temp is not an real number"
    fi
}

function color_add() {
    #Red         \033[31m
    #green       \033[32m
    #Light red   \033[91m
    #Light green \033[92m
    local color_number Value
    color_number=$1
    case ${color_number} in
	"red")
	echo -e "\e[31m$2\e[m"
	;;
	"Lightred")
	echo -e "\e[1;49;31m$2\e[m"
	;;"green")
	echo -e "\e[32m$2\e[m"
	;;"Lightgreen")
        echo -e "\e[92m$2\e[m"
	;;*)
        echo -e "$2"
    esac

}
### Main script 

### Define Template setting 
# This is using on kernel 4.9
CEL=$'\xe2\x84\x83'
CPU_DIR="/sys/devices/virtual/thermal"
CPU0_DIR="thermal_zone0"
FAN_SPEED_FILE="trip_point_2_hyst"
FAN_TEMP_FILE="trip_point_2_temp"
CPU_TEMP_FILE="temp"

### Math template
#check_real_number $1 &>/dev/null
case $1 in
    "change")
	### Check root 
	if [ $EUID -ne 0 ]
	then echo "Super User passwd, please:"
	     SUDO='sudo'
	     ${SUDO} echo -e ""
	     if [ $? -ne 0 ]
	     then  prt_err "Sorry, need su privilege!"
		   
	     fi
	else
	    SUDO=''
	fi
	if [  $# -ne 3 ];then
	    prt_help
	    prt_err
	fi
	Fan_min_temp=$2
	Fan_speed=$3
	echo -e "Real number test : Fan min temp :$(color_add Lightgreen ${Fan_min_temp}${CEL} )"
	check_real_number ${Fan_min_temp} 
	echo -e "Real number test :Fan speed :$(color_add Lightgreen ${Fan_speed}% )"
	check_real_number ${Fan_speed} 
	CHANGE_TEMP=$(( ${Fan_min_temp} * 1000 )) ##Using temp * 1000 into value
	CHANGE_SPEED=$(( ${Fan_speed} * 100 )) ## Using speed * 100 into value
	echo -e "Start Change Fan min temp and speed "
	sudo /bin/bash -c "echo ${CHANGE_TEMP} > ${CPU_DIR}/${CPU0_DIR}/${FAN_TEMP_FILE}"
	sudo /bin/bash -c "echo ${CHANGE_SPEED} > ${CPU_DIR}/${CPU0_DIR}/${FAN_SPEED_FILE}"
	;;
    "status")
	CPU_TEMP=$(cat ${CPU_DIR}/${CPU0_DIR}/${CPU_TEMP_FILE})
	echo -e "Check Value from system : "
	check_real_number ${CPU_TEMP} 
	REALTEMP=$(( ${CPU_TEMP} / 1000 ))
	echo -e "CPU0 temp : $(color_add Lightred ${REALTEMP}${CEL} )"
	;;
    *)
	prt_help
	prt_err
esac

echo -e "Finsh script"
