#!/tmp/flash/bin/bash


WIN_PART_NUM="$(get_part_value win Number )"
ESP_PART_NUM="$(get_part_value esp Number )"


[ -n "${WIN_PART_NUM}" ] || err_exit "win${STR_RES[partition]}${STR_RES[cant_found]},${STR_RES[cancel_flashing]}" 10
[ -n "${ESP_PART_NUM}" ] || err_exit "esp${STR_RES[partition]}${STR_RES[cant_found]},${STR_RES[cancel_flashing]}" 10

WIN_PATH="${DISK_PATH}${WIN_PART_NUM}"
WIN_MOUNT="/mnt/win"

ESP_PATH="${DISK_PATH}${ESP_PART_NUM}"
ESP_MOUNT="/mnt/esp"


ui_print "win${STR_RES[partition]}:${WIN_PATH}"
ui_print "esp${STR_RES[partition]}:${ESP_PATH}"

#显示错误并且取消分区挂载
#报错显示的内容
#报错返回代码
function err_exit_umount(){
    check_umount $WIN_MOUNT
    check_umount $ESP_MOUNT
    err_exit $1 $2
}

#挂载分区
function mount_part(){
    ui_print "${STR_RES[msg_fix_ntfs_file_system]}..."
    ${BASE_PATH_BIN}/ntfsfix ${WIN_PATH}
    [ $? -eq 0 ] || err_exit_umount "${STR_RES[msg_fix_ntfs_file_system]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10

    ui_print "${STR_RES[mount_win_esp]}..."
    ${BUSYBOX} mkdir -p ${WIN_MOUNT} ${ESP_MOUNT}
    [ $? -eq 0 ] || err_exit_umount "${STR_RES[creating_partition_folder_failed]},${STR_RES[cancel_flashing]}" 10
    ${BUSYBOX} mount -t ntfs ${WIN_PATH} ${WIN_MOUNT} 
    [ $? -eq 0 ] || err_exit_umount "${STR_RES[mount_win]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
    ${BUSYBOX} mount -t vfat ${ESP_PATH} ${ESP_MOUNT}
    [ $? -eq 0 ] || err_exit_umount "${STR_RES[mount_esp]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
}

#安装efi
function install_efi(){
    ui_print "${STR_RES[create_win_system_bootleader]}..."
    ${BUSYBOX} mkdir -p ${ESP_MOUNT}/EFI/{Boot,Microsoft/Boot}
    [ $? -eq 0 ] || err_exit_umount "${STR_RES[create]}EFI${STR_RES[folder]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
    ${BUSYBOX} cp -r ${WIN_MOUNT}/Windows/Boot/EFI/* ${ESP_MOUNT}/EFI/Microsoft/Boot
    [ $? -eq 0 ] || err_exit_umount "${STR_RES[copying]}EFI${STR_RES[folder]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
    ${BUSYBOX} cp ${ESP_MOUNT}/EFI/Microsoft/Boot/bootmgfw.efi ${ESP_MOUNT}/EFI/Boot/bootaa64.efi
    [ $? -eq 0 ] || err_exit_umount "${STR_RES[copying]}EFI${STR_RES[file]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
    ${BUSYBOX} cp ${BASE_PATH}/BCD ${ESP_MOUNT}/EFI/Microsoft/Boot/
    [ $? -eq 0 ] || err_exit_umount "${STR_RES[copying]}BCD${STR_RES[file]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
    ${BASE_PATH_BIN}/bcdboot ${ESP_MOUNT}/EFI/Microsoft/Boot/BCD ${WIN_PATH}
    [ $? -eq 0 ] || err_exit_umount "${STR_RES[fix]}BCD${STR_RES[file]}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10
}

#安装boot
function install_boot(){
    local using_boot="/dev/block/by-name/boot$(${TOOLBOX} getprop ro.boot.slot_suffix)"
    ui_print "${STR_RES[install]}uefi boot..."
    [ -r ${SOURCES}/uefi.img ] || err_exit "${STR_RES[cant_found_file]}${SOURCES}/uefi.img" 404
    ${BUSYBOX} dd if=${SOURCES}/uefi.img of=${using_boot} bs=32M
    [ $? -eq 0 ] || err_exit "${STR_RES[install]}uefi boot${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10

}

check_umount $WIN_MOUNT
check_umount $ESP_MOUNT

mount_part
install_efi
install_boot

check_umount $WIN_MOUNT
check_umount $ESP_MOUNT
