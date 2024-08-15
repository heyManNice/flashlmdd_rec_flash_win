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
    local max_size_res=$(${PARTED} ${DISK_PATH} print | grep "Disk ${DISK_PATH}")
    local max_size_arr=(${max_size_res})
    echo ${max_size_arr[2]}
}

#获取磁盘最小起始位置
#取userdata的起始位置
function get_disk_min_size(){
    echo "$(get_part_value userdata Start )"
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

    if [ ${package_info[part]} -eq 1 ]
    then
        local part_extra_msg="，即将删除"
    else
        local part_extra_msg="，保持不变"
    fi

    #打印现有分区信息
    #userdata分区
    if [ -n "${USERDATA_PART_NUM}" ]
    then
        ui_print "检测到userdata分区，大小为$(get_part_value userdata Size )${part_extra_msg}"
    else
        err_exit "意外的情况 找不到userdata分区，取消刷机" 10
    fi
    #win分区
    if [ -n "${WIN_PART_NUM}" ]
    then
        ui_print "检测到win分区，大小为$(get_part_value win Size )${part_extra_msg}"
    fi
    #esp分区
    if [ -n "${ESP_PART_NUM}" ]
    then
        ui_print "检测到esp分区，大小为$(get_part_value esp Size )${part_extra_msg}"
    fi
    #grow分区
    if [ -n "${GROW_PART_NUM}" ]
    then
        ui_print "检测到grow分区，大小为$(get_part_value grow Size )${part_extra_msg}"
    fi
}

#计算新分区信息
function new_part_info(){
    #计算磁盘的初始位置和终止位置
    DISK_MAX_SIZE="$(str2float $(get_disk_max_size))"
    DISK_MIN_SIZE="$(str2float $(get_disk_min_size))"
    DISK_TOTAL_SIZE=$(calc "${DISK_MAX_SIZE} - ${DISK_MIN_SIZE}")

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

    ui_print "磁盘最小起始位置为${DISK_MIN_SIZE}GB，最大终止位置为${DISK_MAX_SIZE}GB"
    ui_print "磁盘可调整空间为${DISK_TOTAL_SIZE}GB"

    #android和win的空间大小占比
    ANDROID_USAGE=$(calc "${package_info[android]} * 100" )
    WINDOWS_USAGE=$(calc "100 - ${ANDROID_USAGE}" )
    ui_print "安卓设置为总分区的${ANDROID_USAGE}%,视窗为${WINDOWS_USAGE}%"
    print_hr
    ui_print "以下是分区调整方案："
    ui_print "1、userdata起始为${USERDATA_START},终止为${USERDATA_END}。 共${USERDATA_SIZE}GB"
    ui_print "2、esp起始为${ESP_START},终止为${ESP_END}。 共0${ESP_SIZE}GB"
    ui_print "3、win起始为${WIN_START},终止为${WIN_END}。 共${WIN_SIZE}GB"
    ui_print "!!请确定当前方案无误，20秒后开始分区"
    ui_print "!!要取消请按音量-或电源键，或强制重启"
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
            ui_print "!!请确定当前方案无误，10秒后开始分区"
            ui_print "!!要取消请按音量-或电源键，或强制重启"
            print_hr
        fi

        local key_event=$(${BUSYBOX} timeout 1 ${BUSYBOX} cat /dev/input/event0)
        if [ "${key_event}" != "" ]
        then
            ui_print "= 用户取消了刷机"
            print_hr
            exit 0
        fi
    done
}

#开始分区 
function part_start(){
    ui_print "开始分区，请勿关闭设备或者断开u盘连接，否则设备会损坏"
    sleep 5s
    #删除分区
    #grow分区
    if [ -n "${GROW_PART_NUM}" ]
    then
        ui_print "删除grow分区..."
        ${BASE_PATH_BIN}/parted ${DISK_PATH} rm ${GROW_PART_NUM}
        [ $? -eq 0 ] || err_exit "删除grow分区遇到错误，取消刷机" 10
    fi

    #win分区
    if [ -n "${WIN_PART_NUM}" ]
    then
        ui_print "删除win分区..."
        ${BASE_PATH_BIN}/parted ${DISK_PATH} rm ${WIN_PART_NUM}
        [ $? -eq 0 ] || err_exit "删除win分区遇到错误，取消刷机" 10
    fi
    #esp分区
    if [ -n "${ESP_PART_NUM}" ]
    then
        ui_print "删除esp分区..."
        ${BASE_PATH_BIN}/parted ${DISK_PATH} rm ${ESP_PART_NUM}
        [ $? -eq 0 ] || err_exit "删除esp分区遇到错误，取消刷机" 10
    fi
    #userdata分区
    if [ -n "${USERDATA_PART_NUM}" ]
    then
        check_umount "/data"
        ui_print "删除userdata分区..."
        ${BASE_PATH_BIN}/parted ${DISK_PATH} rm ${USERDATA_PART_NUM}
        [ $? -eq 0 ] || err_exit "删除userdata分区遇到错误，取消刷机" 10
    fi


    #建立分区
    #userdata
    ui_print "建立userdata分区..."
    ${BASE_PATH_BIN}/parted ${DISK_PATH} mkpart userdata ext4 ${USERDATA_START}GB ${USERDATA_END}GB
    [ $? -eq 0 ] || err_exit "建立userdata分区遇到错误，取消刷机" 10

    #esp
    ui_print "建立esp分区..."
    ${BASE_PATH_BIN}/parted ${DISK_PATH} mkpart esp fat32 ${ESP_START}GB ${ESP_END}GB
    [ $? -eq 0 ] || err_exit "建立esp分区遇到错误，取消刷机" 10

    #win
    ui_print "建立win分区..."
    ${BASE_PATH_BIN}/parted ${DISK_PATH} mkpart win ntfs ${WIN_START}GB ${WIN_END}GB
    [ $? -eq 0 ] || err_exit "建立win分区遇到错误，取消刷机" 10
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