#!/tmp/flash/bin/bash


WIN_PART_NUM="$(get_part_value win Number )"
ESP_PART_NUM="$(get_part_value esp Number )"

[ -n "${WIN_PART_NUM}" ] || err_exit "win${STR_RES[partition_is_not_found]},${STR_RES[cancel_flashing]}" 10
[ -n "${ESP_PART_NUM}" ] || err_exit "esp${STR_RES[partition_is_not_found]},${STR_RES[cancel_flashing]}" 10


WIN_PATH="${DISK_PATH}${WIN_PART_NUM}"
ESP_PATH="${DISK_PATH}${ESP_PART_NUM}"

#检测系统镜像文件
[ -r ${SOURCES}/install.wim ] || err_exit "${STR_RES[cant_found_file]}${SOURCES}/install.wim" 404

#格式化
function format(){
    ui_print "${STR_RES[formating]}win${STR_RES[partition]} esp${STR_RES[partition]}..."
    ${BASE_PATH_BIN}/mkntfs -f ${WIN_PATH}
    [ $? -eq 0 ] || err_exit "${STR_RES[format]}win${STR_RES[partition]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
    ${BASE_PATH_BIN}/mkfs.fat -F 32 ${ESP_PATH}
    [ $? -eq 0 ] || err_exit "${STR_RES[format]}esp${STR_RES[partition]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
}

#安装系统
function install_win(){
    ui_print "${STR_RES[msg_installing_windows]}..."
    ui_print "${STR_RES[msg_take_5_minutes]},${STR_RES[sit_back_and_relax]}"
    ui_print "${STR_RES[msg_time_depends_on_usb]}..."
    ui_print "${STR_RES[msg_do_not_turn_off_or_disconnect_usb]}"
    ${BASE_PATH_BIN}/wimlib-imagex apply ${SOURCES}/install.wim 1 ${WIN_PATH}
    [ $? -eq 0 ] || err_exit "${STR_RES[msg_install_windows_error]},${STR_RES[cancel_flashing]}" 10
}

format
install_win