#!/tmp/flash/bin/bash

DISK_PATH="/dev/block/sda"
PARTED="${BASE_PATH_BIN}/parted"

#通过分区的关键字获取分区的参数
#参数1 关键字
#参数2 键  可用的值为 Number Start End Size File_system Name Flags
#找不到分区是返回空字符串
function get_part_value(){
    local result=$(${PARTED} ${DISK_PATH} print | grep ${1})
    if [ ! -n "${result}" ]
    then
        return
    fi
    local result_arr=(${result})
    local index
    case "${2}" in
        "Number") index=0
        ;;
        "Start")  index=1
        ;;
        "End")    index=2
        ;;
        "Size")   index=3
        ;;
        "File_system")  index=4
        ;;
        "Name")   index=5
        ;;
        "Flags")  index=6
        ;;
        *)  return
        ;;
    esac
    echo ${result_arr[${index}]}
}

#获取磁盘最大终止位置
function get_disk_max_size(){
    local grow_end=$(str2float $(get_part_value grow End))
    local esp_end=$(str2float $(get_part_value esp End))
    local userdata_end=$(str2float $(get_part_value userdata End))
    local win_end=$(str2float $(get_part_value win End))

    local end_sort_arr=($(my_sort "${grow_end} ${esp_end} ${userdata_end} ${win_end}"))
    echo ${end_sort_arr[-1]}
}

#获取磁盘最小起始位置
#取userdata的起始位置
function get_disk_min_size(){
    local grow_start=$(str2float $(get_part_value grow Start))
    local esp_start=$(str2float $(get_part_value esp Start))
    local userdata_start=$(str2float $(get_part_value userdata Start))
    local win_start=$(str2float $(get_part_value win Start))
    
    local start_sort_arr=($(my_sort "${grow_start} ${esp_start} ${userdata_start} ${win_start}"))
    echo ${start_sort_arr[0]}
}

function part_test(){
    local test_p="userdata"
    ui_print "Number:$(get_part_value ${test_p} "Number")"
    ui_print "Start:$(get_part_value ${test_p} "Start")"
    ui_print "End:$(get_part_value ${test_p} "End")"
    ui_print "Size:$(get_part_value ${test_p} "Size")"
    ui_print "File_system:$(get_part_value ${test_p} "File_system")"
    ui_print "Name:$(get_part_value ${test_p} "Name")"
    ui_print "Flags:$(get_part_value ${test_p} "Flags")"
}

#检测分区大小
function part_check(){
    #获取分区号码
    USERDATA_PART_NUM="$(get_part_value userdata Number )"
    WIN_PART_NUM="$(get_part_value win Number )"
    ESP_PART_NUM="$(get_part_value esp Number )"
    GROW_PART_NUM="$(get_part_value grow Number )"

    #测试分区是不是连续的
    local nums_sort="$(my_sort " ${USERDATA_PART_NUM} ${ESP_PART_NUM} ${WIN_PART_NUM} ${GROW_PART_NUM}")"
    [ "$(is_continuou "${nums_sort}")" = "0" ] && err_exit "${STR_RES[unexpected_situation]},${STR_RES[partition_discontinuity]},${STR_RES[cancel_flashing]}" 10

    if [ ${package_info[part]} -eq 1 ]
    then
        local part_extra_msg=",${STR_RES[about_to_delete]}"
    else
        local part_extra_msg=",${STR_RES[remain_unchanged]}"
    fi

    #打印现有分区信息
    #userdata分区
    if [ -n "${USERDATA_PART_NUM}" ]
    then
        ui_print "${STR_RES[detected]}userdata${STR_RES[partition]},${STR_RES[size_is]}$(get_part_value userdata Size )${part_extra_msg}"
    else
        err_exit "${STR_RES[unexpected_situation]} ${STR_RES[cant_found]}userdata${STR_RES[partition]},${STR_RES[cancel_flashing]}" 10
    fi
    #win分区
    if [ -n "${WIN_PART_NUM}" ]
    then
        ui_print "${STR_RES[detected]}win${STR_RES[partition]},${STR_RES[size_is]}$(get_part_value win Size )${part_extra_msg}"
    fi
    #esp分区
    if [ -n "${ESP_PART_NUM}" ]
    then
        ui_print "${STR_RES[detected]}esp${STR_RES[partition]},${STR_RES[size_is]}$(get_part_value esp Size )${part_extra_msg}"
    fi
    #grow分区
    if [ -n "${GROW_PART_NUM}" ]
    then
        ui_print "${STR_RES[detected]}grow${STR_RES[partition]},${STR_RES[size_is]}$(get_part_value grow Size )${part_extra_msg}"
    fi
}

#计算新分区信息
function new_part_info(){
    #计算磁盘的初始位置和终止位置
    DISK_MAX_SIZE="$(get_disk_max_size)"
    DISK_MIN_SIZE="$(get_disk_min_size)"

    DISK_TOTAL_SIZE=$(calc "${DISK_MAX_SIZE} - ${DISK_MIN_SIZE}")

    if [ $(calc "${DISK_TOTAL_SIZE} < 100") = 1 ]
    then
        err_exit "${STR_RES[msg_adjustable_partitions_less_than_100]}" 10
    fi

    #分区的userdata信息
    USERDATA_START=$DISK_MIN_SIZE
    USERDATA_END=$(calc "${USERDATA_START} + ${DISK_TOTAL_SIZE} * ${package_info[android]}")
    USERDATA_SIZE=$(calc "${USERDATA_END} - ${USERDATA_START}")

    #分区的esp信息
    ESP_START=$USERDATA_END
    ESP_END=$(calc "${ESP_START} + 0.3")
    ESP_SIZE=$(calc "${ESP_END} - ${ESP_START}")

    #分区的win信息
    WIN_START=$ESP_END
    WIN_END=$DISK_MAX_SIZE
    WIN_SIZE=$(calc "${WIN_END} - ${WIN_START}")

    ui_print "${STR_RES[min_starting_position_of_disk_is]}${DISK_MIN_SIZE}GB,${STR_RES[max_ending_position_of_disk_is]}${DISK_MAX_SIZE}GB"
    ui_print "${STR_RES[the_adjustable_disk_space_is]}${DISK_TOTAL_SIZE}GB"

    #android和win的空间大小占比
    ANDROID_USAGE=$(calc "${package_info[android]} * 100" )
    WINDOWS_USAGE=$(calc "100 - ${ANDROID_USAGE}" )
    ui_print "${STR_RES[android_is_set_as_a_total_partition_of]}${ANDROID_USAGE}%,${STR_RES[windows_is_set_as_a_total_partition_of]}${WINDOWS_USAGE}%"
    print_hr
    ui_print "${STR_RES[msg_following_is_plan]}"
    ui_print "1、userdata${STR_RES[starting_is]}${USERDATA_START},${STR_RES[ending_is]}${USERDATA_END}。 ${STR_RES[total]}${USERDATA_SIZE}GB"
    ui_print "2、esp${STR_RES[starting_is]}${ESP_START},${STR_RES[ending_is]}${ESP_END}。 ${STR_RES[total]}0${ESP_SIZE}GB"
    ui_print "3、win${STR_RES[starting_is]}${WIN_START},${STR_RES[ending_is]}${WIN_END}。 ${STR_RES[total]}${WIN_SIZE}GB"
    ui_print "!!${STR_RES[confirm_it_20_sec]}"
    ui_print "!!${STR_RES[to_cancel_volume_or_power_or_reboot]}"
    print_hr

    local timer
    if [ $DEBUG -eq 0 ]
    then
        timer=20
    else
        timer=4
    fi

    for i in $(${BUSYBOX} seq 0 ${timer})
    do
        if [ "${i}" = "10" ]
        then
            ui_print "!!${STR_RES[confirm_it_10_sec]}"
            ui_print "!!${STR_RES[to_cancel_volume_or_power_or_reboot]}"
            print_hr
        fi

        local key_event=$(${BUSYBOX} timeout 1 ${BUSYBOX} cat /dev/input/event0)
        if [ "${key_event}" != "" ]
        then
            ui_print "= ${STR_RES[user_cancel_flashing]}"
            print_hr
            exit 0
        fi
    done
}

#删除分区
#参数1 要删除的分区的号码
function del_part(){
    if [ -n "${1}" ]
    then
        ui_print "${STR_RES[delete]}${1}${STR_RES[partition]}..."
        ${BASE_PATH_BIN}/parted ${DISK_PATH} rm ${1}
        [ $? -eq 0 ] || err_exit "${STR_RES[delete]}${1}${STR_RES[partition]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
    fi
}

#新建分区
#参数1 新建分区的名字
#参数2 新建分区的格式
#参数3 新建分区的起始
#参数4 新建分区的结束
function new_part(){
    ui_print "${STR_RES[create]}${1}${STR_RES[partition]}..."
    ${BASE_PATH_BIN}/parted ${DISK_PATH} mkpart $1 $2 ${3}GB ${4}GB
    [ $? -eq 0 ] || err_exit "${STR_RES[create]}${1}${STR_RES[partition]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
}

#开始分区 
function part_start(){
    ui_print "${STR_RES[start_partition_do_not_power_off]}"
    sleep 5s
    #删除分区

    check_umount "/data"
    del_part "${GROW_PART_NUM}"
    del_part "${WIN_PART_NUM}"
    del_part "${ESP_PART_NUM}"
    del_part "${USERDATA_PART_NUM}"

    #建立分区
    new_part userdata ext4 ${USERDATA_START} ${USERDATA_END}
    new_part esp fat32 ${ESP_START} ${ESP_END}
    new_part win ntfs ${WIN_START} ${WIN_END}
    ui_print "${STR_RES[msg_partition_completed]}..."
}

#程序流程开始

part_check

if [ ! ${package_info[part]} -eq 1 ]
then
    #如果不分区，就不执行以下内容
    return
fi

new_part_info
part_start
#part_test