#!/tmp/flash/bin/bash

TWRP_CONFIG_PATH="/data/media/0/TWRP/.twrps"

#获取OUTFD的代码来自Magisk
#https://github.com/topjohnwu/Magisk
function get_outfd(){
    # update-binary|updater <RECOVERY_API_VERSION> <OUTFD> <ZIPFILE>
    OUTFD=$(ps | grep -v 'grep' | grep -oE 'update(.*) 3 [0-9]+' | cut -d" " -f3)
    [ -z $OUTFD ] && OUTFD=$(ps -Af | grep -v 'grep' | grep -oE 'update(.*) 3 [0-9]+' | cut -d" " -f3)
    # update_engine_sideload --payload=file://<ZIPFILE> --offset=<OFFSET> --headers=<HEADERS> --status_fd=<OUTFD>
    [ -z $OUTFD ] && OUTFD=$(ps | grep -v 'grep' | grep -oE 'status_fd=[0-9]+' | cut -d= -f2)
    [ -z $OUTFD ] && OUTFD=$(ps -Af | grep -v 'grep' | grep -oE 'status_fd=[0-9]+' | cut -d= -f2)
}

#检测是否挂载分区
#参数1 分区路径
function is_mount(){
    echo $(${BUSYBOX} mount | grep ${1})
}

#打印信息到rec的屏幕上
function ui_print(){
    if [ $OUTFD ]
    then
        echo -e "ui_print "${1}"" >> /proc/self/fd/$OUTFD
    else
        echo -e "${1}"
    fi
}



#清除rec屏幕上的内容
#打印大量的空白字符实现
function ui_clear(){
    for i in $(${BUSYBOX} seq 1 30)
    do
        ui_print " "
    done
}


#打印横线
function print_hr(){
    ui_print "============================================"
}

#显示进度条
#参数1 进度条前进的值，总值为1
#参数2 前进所化的时间，单位秒
function show_progress(){
    if [ $OUTFD ]
    then
        echo -e "progress $1 $2" >> /proc/self/fd/$OUTFD
    fi
}

#从字符串资源打印格式化字符
#参数1 字符串资源的名字或者需要格式化输出的字符串
#参数n 需要格式化显示的内容
function prints(){
    local format_str
    if [ -n "${STR_RES[${1}]}" ]
    then
        format_str="${STR_RES[$1]}"
    else
        format_str=$1
    fi
    
    shift
    local str=$(printf "${format_str}" "$@")
    ui_print "$str"
}


#从twrp配置中获取语言
function load_languages(){
    if [ -r ${TWRP_CONFIG_PATH} ]
    then
        local lang_arr=($(${BUSYBOX} ls ${BASE_PATH_LANG} | ${BUSYBOX} awk -F. '{print $1}'))
        local LOACL
        for lang in ${lang_arr[@]}
        do
            ${BUSYBOX} cat ${TWRP_CONFIG_PATH} | ${BUSYBOX} grep -q "${lang}" && LOACL=${lang}
        done
        
        if [ -n "${LOACL}" ]
        then
            #加载该语言
            source "${BASE_PATH_LANG}/${LOACL}.sh"
        else
            #如果找不到语言，那就加载英文
            source "${BASE_PATH_LANG}/en.sh"
        fi


    else
        source "${BASE_PATH_LANG}/en.sh"
    fi
}

get_outfd
load_languages

#显示错误信息并且退出
#参数1 报错信息
#参数2 退出返回的值
function err_exit(){
    ui_clear
    ui_print "LOG:"
    ui_print "$(cat /tmp/recovery.log | tail -n 5)"
    ui_print " "
    ui_print "XXXX========================"
    ui_print "[${STR_RES[str_error]}]${1}";
    ui_print " "
    exit $2;
}

#从字符串资源格式化输出字符串显示错误信息并且退出
#参数1 报错信息
#参数2 各个参数值
function err_exitf(){
    local format_str
    if [ -n "${STR_RES[${1}]}" ]
    then
        format_str="${STR_RES[$1]}"
    else
        format_str=$1
    fi
    shift
    local str=$(printf "${format_str}" "$@")

    ui_clear
    ui_print "LOG:"
    ui_print "$(cat /tmp/recovery.log | tail -n 5)"
    ui_print " "
    ui_print "XXXX========================"
    ui_print "[${STR_RES[str_error]}]${str}";
    ui_print " "
    exit 10;
}


[ -r ${BASE_PATH_SH}/build_info.sh ] || err_exit "${STR_RES[cant_found]}${BASE_PATH_SH}/build_info.sh,${STR_RES[cancel_flashing]}" 10
source ${BASE_PATH_SH}/build_info.sh