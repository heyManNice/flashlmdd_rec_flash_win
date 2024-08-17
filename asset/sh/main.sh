#!/tmp/flash/bin/bash

DEBUG=0

BASE_PATH="/tmp/flash"
BASE_PATH_BIN="${BASE_PATH}/bin"
BASE_PATH_SH="${BASE_PATH}/sh"
TOOLBOX="${BASE_PATH_BIN}/toolbox"
BUSYBOX="${BASE_PATH_BIN}/busybox"

declare -A  package_info
source ${BASE_PATH_SH}/init.sh


external_storage_list=(
    "/usb-otg"
    "/external_sd"
)

#检测挂载的外置储存
for storage_path in ${external_storage_list[@]}
do
    [ -n "$(is_mount "${storage_path}")" ] && MY_EXTERNAL_STORAGE=${storage_path}
done
[ -n "${MY_EXTERNAL_STORAGE}" ] || err_exit "找不到挂载的外置储存" 10



IMAGES_PATH="${MY_EXTERNAL_STORAGE}/${BUILD_DEVICE}_rec_flash_win"
SOURCES="${IMAGES_PATH}/sources"


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
    "BCD"
)

#将文档中的\r\n换成\n
#让linux能够正常的读取由win编辑的文档
function win2unix(){
    ${BASE_PATH_BIN}/dos2unix ${BASE_PATH_SH}/build_info.sh
    [ -r ${IMAGES_PATH}/package.info ] && ${BASE_PATH_BIN}/dos2unix ${IMAGES_PATH}/package.info
}


#打印编译信息
function get_build_info(){
    ui_print "编译日期：${BUILD_DATE}"
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
        ui_print "${1}已挂载，即将取消挂载"
        ${BUSYBOX} umount ${1}
    else
        ui_print "${1}未挂载"
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
        [ -r ${IMAGES_PATH}/package.info ] || err_exit "找不到文件${IMAGES_PATH}/package.info" 404
        source ${IMAGES_PATH}/package.info
    else
        package_info=(
            #刷机之后的系统
            [target]="Debugging"
            #这个刷机包适配的机型
            [device]="flashlmdd"
            #刷机包简介
            [brief]="脚本测试中，没有刷机包"
            #是否启用分区功能
            #1是启用，0是禁用
            [part]=1
            #安卓分区大小,合理值范围是0.11到0.7
            #表示安卓分区占比大小,0.11标识占磁盘的15%
            #其余空间自动分给windows
            [android]=0.11
        )
    fi
    
    print_hr
    ui_print "= 机型：${package_info[device]}"
    ui_print "= 目标系统：${package_info[target]}"
    ui_print "= 外置存储：${MY_EXTERNAL_STORAGE}"
    ui_print "= 系统简介：${package_info[brief]}"

    if [ ${package_info[part]} -eq 1 ]
    then
        local is_size_legal=$(calc "${package_info[android]} >= 0.11 && ${package_info[android]} <= 0.7")
        [ "${is_size_legal}" = "0" ] && err_exit "package.info文件中安卓分区的占比必须是0.11到0.7之间,当前为${package_info[android]}" 10

        local total_size=107.6
        local android_size=$(calc "${total_size} * ${package_info[android]}")
        local windows_size=$(calc "${total_size} - ${android_size} - 0.3")
        ui_print "= 分区：安卓${android_size}GB,视窗${windows_size}GB"
    else
        ui_print "= 分区：不重新分区，但会检测是否符合要求"
    fi
    ui_print "= Github：${BUILD_GITHUB}"
    ui_print "= 编译日期：${BUILD_DATE}"
    print_hr
    ui_print "= 刷机步骤：1=备份  2=分区  3=安装  4=引导"
    print_hr
}

#检测当前环境是否满足刷机要求
function env_check(){
    #检测是否在rec中
    [ -r /init.rc ] && err_exit "请在rec中运行此脚本" 8

    #检测root
    [ "$(${BUSYBOX} whoami)" != "root" ] && err_exit "请使用root权限运行此脚本" 4

    #检测机型
    [ "$(${TOOLBOX} getprop ro.product.device)" != ${BUILD_DEVICE} ] && err_exit "刷机取消，该设备代号不为${BUILD_DEVICE}" 4

    #检测脚本文件
    for path in ${asset_path[@]}
    do
        [ -x ${BASE_PATH}/${path} ] || err_exit "${BASE_PATH}/${path}文件不存在或者无权限执行" 5
    done

    #当DEBUG=0才会去检测U盘中的系统镜像文件
    if [ $DEBUG -eq 0 ]
    then
    #检测系统镜像文件
    [ -r ${SOURCES}/install.wim ] || err_exit "找不到文件${SOURCES}/install.wim" 404

    #检测系统包信息文件
    [ -r ${IMAGES_PATH}/package.info ] || err_exit "找不到文件${IMAGES_PATH}/package.info" 404
    fi

    #检测电量
    local battery=$(${BUSYBOX} cat /sys/class/power_supply/battery/capacity)
    [ $battery -lt 70 ] && err_exit "请将手机充电到70%以上再刷机" 6
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
        ui_print "= !!${timer}秒后开始刷机"
        ui_print "= !!要取消请按音量-或电源键，或强制重启"
        print_hr
        local key_event=$(${BUSYBOX} timeout 1 ${BUSYBOX} cat /dev/input/event0)
        if [ "${key_event}" != "" ]
        then
            ui_print "= 用户取消了刷机"
            print_hr
            exit 0
        fi
        let timer--
    done
}

#main函数
#模仿其他编程语言假装是程序的主入口
function main(){
    
    win2unix
    get_build_info
    env_check
    wait2flash

    #备份
    show_progress 0.1 10
    ui_clear
    print_hr
    ui_print "= 正在安装 Windows"
    ui_print "="
    ui_print "=   1、备份  <=="
    ui_print "=   2、分区"
    ui_print "=   3、安装"
    ui_print "=   4、引导"
    print_hr
    source ${BASE_PATH_SH}/backup.sh

    #分区
    show_progress 0.1 20
    ui_clear
    print_hr
    ui_print "= 正在安装 Windows"
    ui_print "="
    ui_print "=   1、备份  ✓"
    ui_print "=   2、分区  <=="
    ui_print "=   3、安装"
    ui_print "=   4、引导"
    print_hr
    source ${BASE_PATH_SH}/partition.sh


    #安装
    show_progress 0.6 300
    ui_clear
    print_hr
    ui_print "= 正在安装 Windows"
    ui_print "="
    ui_print "=   1、备份  ✓"
    ui_print "=   2、分区  ✓"
    ui_print "=   3、安装  <=="
    ui_print "=   4、引导"
    print_hr
    source ${BASE_PATH_SH}/install.sh

    #引导
    show_progress 0.1 10
    ui_clear
    print_hr
    ui_print "= 正在安装 Windows"
    ui_print "="
    ui_print "=   1、备份  ✓"
    ui_print "=   2、分区  ✓"
    ui_print "=   3、安装  ✓"
    ui_print "=   4、引导  <=="
    print_hr

    source ${BASE_PATH_SH}/boot.sh


    #完成
    ui_clear
    print_hr
    ui_print "= Windows安装完成"
    ui_print "="
    ui_print "=   1、备份  ✓"
    ui_print "=   2、分区  ✓"
    ui_print "=   3、安装  ✓"
    ui_print "=   4、引导  ✓"
    print_hr
    ui_print "建议重启之前先在rec格式化Data分区"
    ui_print "下次启动安卓才不会出现要求密码之类的情况"
    ui_print "重启即可进入${package_info[target]}"
    ui_print "想了解更多信息请访问${BUILD_GITHUB}"
    print_hr
}

main