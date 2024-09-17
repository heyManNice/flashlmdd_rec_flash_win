#!/tmp/flash/bin/bash

DEBUG=0

BASE_PATH="/tmp/flash"
BASE_PATH_BIN="${BASE_PATH}/bin"
BASE_PATH_SH="${BASE_PATH}/sh"
BASE_PATH_LANG="${BASE_PATH}/languages"
TOOLBOX="${BASE_PATH_BIN}/toolbox"
BUSYBOX="${BASE_PATH_BIN}/busybox"

declare -A  package_info

declare -A  STR_RES

source ${BASE_PATH_SH}/init.sh


external_storage_list=(
    "/usb-otg"
    "/external_sd"
    "/usbstorage"
    "/sdcard1"
)


#检测挂载的外置储存/Detecting mounted external storage
for storage_path in "${external_storage_list[@]}"
do
    [ -n "$(is_mount "${storage_path}")" ] && MY_EXTERNAL_STORAGE=${storage_path}
done
[ -n "${MY_EXTERNAL_STORAGE}" ] || err_exitf str_cant_found_storage



IMAGES_PATH="${MY_EXTERNAL_STORAGE}/${BUILD_DEVICE}_rec_flash_win"
SOURCES="${IMAGES_PATH}/sources"

#脚本将会检测这些文件的可执行性
asset_path=(
    "bin/bash"
    "bin/busybox"
    "bin/toolbox"
    "bin/dos2unix"
    "bin/parted"
    "bin/wimlib-imagex"
    "bin/ntfsfix"
    "bin/bcdboot"
    "sh/build_info.sh"
    "sh/main.sh"
    "sh/partition.sh"
    "sh/backup.sh"
    "sh/install.sh"
    "sh/boot.sh"
    "sh/init.sh"
    "BCD"
)

#将文档中的\r\n换成\n
#让linux能够正常的读取由win编辑的文档
function win2unix(){
    ${BASE_PATH_BIN}/dos2unix ${BASE_PATH_SH}/build_info.sh
    [ -r "${IMAGES_PATH}/package.info" ] && ${BASE_PATH_BIN}/dos2unix "${IMAGES_PATH}/package.info"
}


#升序排序
#参数1 需要排的字符串，空格间隔
function my_sort(){
    echo $(${BUSYBOX} echo "${1}" | ${BUSYBOX} tr " " "\n" | ${BUSYBOX} sort -n)
}




#检测如果挂载了分区就取消挂载分区
#参数1 要检测的目录
function check_umount(){
    if [ -n "$(is_mount ${1})" ]
    then
        prints str_mounted_about_to_remounted "$1"
        ${BUSYBOX} umount ${1}
    else
        prints str_unmounted "$1"
    fi
}


#算数计算
#参数1 算数字符串
function calc(){
    echo $(${BUSYBOX} echo "${1}" | ${BUSYBOX} bc)
}


#判断这些整数是否是连续的
#参数1 数字组成的字符串
function is_continuou(){
    local num_arr=(${1})
    local index=$(calc "${#num_arr[@]} - 1")
    echo $(calc "${num_arr[${index}]} - ${num_arr[0]} == ${index}")
}

#打印刷机信息
function print_info(){

    if [ $DEBUG -eq 0 ]
    then
        [ -r ${IMAGES_PATH}/package.info ] || err_exit "${STR_RES[cant_found_file]}:${IMAGES_PATH}/package.info" 404
        source ${IMAGES_PATH}/package.info
    else
        package_info=(
            #刷机之后的系统/System after flashing
            [target]="Debugging"
            #这个刷机包适配的机型/This flashing package is compatible with different models
            [device]="flashlmdd"
            #刷机包简介/Introduction to flashing package
            [brief]="test"
            #是否启用分区功能/Whether to enable partition function
            #1是启用，0是禁用/1 is enabled, 0 is disabled
            [part]=0
            #安卓分区大小,合理值范围是0.11到0.7 / The reasonable range for Android partition size is 0.11 to 0.7
            #表示安卓分区占比大小,0.11标识占磁盘的15% / Indicates the proportion size of Android partitions, with a 0.11 mark representing 15% of the disk
            #其余空间自动分给windows / The remaining space is automatically allocated to Windows
            [android]=0.11
        )
    fi
    
    print_hr
    prints str_device "${package_info[device]}"
    prints str_target_system "${package_info[target]}"
    prints str_external_storage "${MY_EXTERNAL_STORAGE}"
    prints str_system_brief "${package_info[brief]}"

    if [ ${package_info[part]} -eq 1 ]
    then
        local is_size_legal=$(calc "${package_info[android]} >= 0.11 && ${package_info[android]} <= 0.7")
        [ "${is_size_legal}" = "0" ] && err_exitf str_and_011_to_07 "${package_info[android]}"

        local android_size=$(calc "100 * ${package_info[android]}")
        local windows_size=$(calc "100 - ${android_size}")
        prints str_partition_and_gb_win_gb "${android_size}" "${windows_size}"
    else
        prints str_partition_no
    fi
    prints str_github "${BUILD_GITHUB}"
    prints str_build_data2 "${BUILD_DATE}"
    print_hr
    prints str_flashing_steps
    print_hr
}

#检测当前环境是否满足刷机要求
function env_check(){
    #检测是否在rec中
    [ -r /init.rc ] && err_exitf str_please_run_in_rec

    #检测root
    [ "$(${BUSYBOX} whoami)" != "root" ] && err_exitf str_please_run_in_root

    #检测机型
    [ "$(${TOOLBOX} getprop ro.product.device)" != ${BUILD_DEVICE} ] && err_exitf str_cancel_device_is_not "${BUILD_DEVICE}"

    #检测脚本文件
    for path in "${asset_path[@]}"
    do
        [ -x ${BASE_PATH}/${path} ] || err_exitf str_not_exist_or_permission_denied "${BASE_PATH}/${path}"
    done

    #当DEBUG=0才会去检测U盘中的系统镜像文件
    if [ $DEBUG -eq 0 ]
    then
    #检测系统镜像文件
    [ -r ${SOURCES}/install.wim ] || err_exitf str_cant_found_file "${SOURCES}/install.wim"

    #检测系统包信息文件
    [ -r ${IMAGES_PATH}/package.info ] || err_exitf str_cant_found_file "${SOURCES}/package.info"
    fi

    #检测电量
    local battery=$(${BUSYBOX} cat /sys/class/power_supply/battery/capacity)
    [ $battery -lt 70 ] && err_exitf str_please_charge_over_70
}

#提取字符串中的浮点数
#参数1 要处理的字符串
function str2float(){
    echo "${1}" | grep -oE '[0-9]+(\.[0-9]+)?'
}

#等待30秒开始刷机
function wait2flash(){
    local timer

    if [ $DEBUG -eq 0 ]
    then
        timer=30
    else
        timer=1
    fi

    for i in $(${BUSYBOX} seq 0 ${timer})
    do
        ui_clear
        print_info
        prints str_seconds_before_start_flashing "${timer}"
        prints str_to_cancel_volume_or_power_or_reboot
        print_hr
        local key_event=$(${BUSYBOX} timeout 1 ${BUSYBOX} cat /dev/input/event0)
        if [ "${key_event}" != "" ]
        then
            prints str_user_cancel_flashing
            print_hr
            exit 0
        fi
        let timer--
    done
}

#返回箭头还是打勾
#参数1 输入的值
#参数2 对比的值
function get_state_symbol(){
    [ $1 -eq $2 ] && echo "  <=="
    [ $1 -gt $2 ] && echo "  ok"
}

#打印当前进度
#参数1 进度值1~5
function print_progress(){
    ui_clear
    print_hr
    if [ $1 = 5 ]
    then
        prints str_installation_completed
    else
        prints str_installing_windows
    fi

    ui_print "="

    prints progress_backup "$(get_state_symbol ${1} 1)"
    prints progress_partition "$(get_state_symbol ${1} 2)"
    prints progress_install "$(get_state_symbol ${1} 3)"
    prints progress_bootleader "$(get_state_symbol ${1} 4)"
    print_hr
}

#main函数
#模仿其他编程语言假装是程序的主入口
function main(){
    
    win2unix
    env_check
    wait2flash

    #备份
    show_progress 0.3 120
    print_progress 1
    source ${BASE_PATH_SH}/backup.sh

    #分区
    show_progress 0.1 20
    print_progress 2
    source ${BASE_PATH_SH}/partition.sh


    #安装
    show_progress 0.5 150
    print_progress 3
    source ${BASE_PATH_SH}/install.sh

    #引导
    show_progress 0.1 10
    print_progress 4
    source ${BASE_PATH_SH}/boot.sh


    #完成
    print_progress 5
    prints str_format_data_before_reboot
    prints str_no_password_next_boot_to_android
    prints str_restart_to_enter "${package_info[target]}"
    prints str_information_visit "${BUILD_GITHUB}"
    print_hr
}

main