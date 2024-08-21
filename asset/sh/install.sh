#!/tmp/flash/bin/bash


WIN_PART_NUM="$(get_part_value win Number )"
ESP_PART_NUM="$(get_part_value esp Number )"

[ -n "${WIN_PART_NUM}" ] || err_exitf str_cant_found_partition win
[ -n "${ESP_PART_NUM}" ] || err_exitf str_cant_found_partition esp


WIN_PATH="${DISK_PATH}${WIN_PART_NUM}"
ESP_PATH="${DISK_PATH}${ESP_PART_NUM}"

#检测系统镜像文件
[ -r ${SOURCES}/install.wim ] || err_exitf str_cant_found_file "${SOURCES}/install.wim"

#格式化
function format(){
    prints str_formating_partition "win,esp"
    ${BASE_PATH_BIN}/mkntfs -f ${WIN_PATH}
    [ $? -eq 0 ] || err_exitf str_format_partition_failed win
    ${BASE_PATH_BIN}/mkfs.fat -F 32 ${ESP_PATH}
    [ $? -eq 0 ] || err_exitf str_format_partition_failed esp
}

#安装系统
function install_win(){
    prints str_extracting_windows_files
    prints str_msg_take_x_minutes_sit_back_and_relax 5
    prints str_msg_time_depends_on_usb
    prints str_msg_do_not_turn_off_or_disconnect_usb

    ${BASE_PATH_BIN}/wimlib-imagex apply ${SOURCES}/install.wim 1 ${WIN_PATH}
    [ $? -eq 0 ] || err_exitf str_extracting_failed
}

format
install_win