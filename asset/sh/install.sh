#!/tmp/flash/bin/bash


WIN_PART_NUM="$(get_part_value win Number )"
ESP_PART_NUM="$(get_part_value esp Number )"

[ -n "${WIN_PART_NUM}" ] || err_exit "win分区未找到，取消刷机" 10
[ -n "${ESP_PART_NUM}" ] || err_exit "esp分区未找到，取消刷机" 10


WIN_PATH="${DISK_PATH}${WIN_PART_NUM}"
ESP_PATH="${DISK_PATH}${ESP_PART_NUM}"

#检测系统镜像文件
[ -r ${SOURCES}/install.wim ] || err_exit "找不到文件${SOURCES}/install.wim" 404

#格式化
function format(){
    ui_print "正在格式化win分区和esp分区..."
    ${BASE_PATH_BIN}/mkntfs -f ${WIN_PATH}
    [ $? -eq 0 ] || err_exit "格式化win分区遇到错误，取消刷机" 10
    ${BASE_PATH_BIN}/mkfs.fat -F 32 ${ESP_PATH}
    [ $? -eq 0 ] || err_exit "格式化esp分区遇到错误，取消刷机" 10
}

#安装系统
function install_win(){
    ui_print "正在部署win系统..."
    ui_print "这个过程一般会经历5分钟，做和放宽"
    ui_print "具体的时间取决于你的U盘速度..."
    ui_print "请不要关闭设备或者断开U盘连接"
    ${BASE_PATH_BIN}/wimlib-imagex apply ${SOURCES}/install.wim 1 ${WIN_PATH}
    [ $? -eq 0 ] || err_exit "部署win系统遇到错误，取消刷机" 10
}

format
install_win