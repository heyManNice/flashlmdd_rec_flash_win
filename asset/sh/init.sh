#!/tmp/flash/bin/bash


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


#显示错误信息并且退出
#参数1 报错信息
#参数2 退出返回的值
function err_exit(){
    ui_clear
    ui_print "LOG:"
    ui_print "$(cat /tmp/recovery.log | tail -n 5)"
    ui_print " "
    ui_print "XXXX========================"
    ui_print "[错误]${1}";
    ui_print " "
    exit $2;
}

get_outfd


[ -r ${BASE_PATH_SH}/build_info.sh ] || err_exit "找不到${BASE_PATH_SH}/build_info.sh,取消刷机" 10
source ${BASE_PATH_SH}/build_info.sh