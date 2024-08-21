#!/tmp/flash/bin/bash


WIN_PART_NUM="$(get_part_value win Number )"
ESP_PART_NUM="$(get_part_value esp Number )"


[ -n "${WIN_PART_NUM}" ] || err_exitf str_cant_found_partition win
[ -n "${ESP_PART_NUM}" ] || err_exitf str_cant_found_partition esp

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

#显示格式化错误并且取消分区挂载
#报错显示的内容
#报错返回代码
function err_exit_umountf(){
    check_umount $WIN_MOUNT
    check_umount $ESP_MOUNT
    err_exitf $@
}

#挂载分区
function mount_part(){
    prints str_msg_fix_file_system ntfs
    ${BASE_PATH_BIN}/ntfsfix ${WIN_PATH}
    [ $? -eq 0 ] || err_exit_umountf str_msg_fix_file_system_failed ntfs

    prints str_mount_partition "win,esp"
    ${BUSYBOX} mkdir -p ${WIN_MOUNT} ${ESP_MOUNT}
    [ $? -eq 0 ] || err_exit_umountf str_creating_partition_folder_failed "win,esp"
    ${BUSYBOX} mount -t ntfs ${WIN_PATH} ${WIN_MOUNT} 
    [ $? -eq 0 ] || err_exit_umountf str_mount_partition_failed win
    ${BUSYBOX} mount -t vfat ${ESP_PATH} ${ESP_MOUNT}
    [ $? -eq 0 ] || err_exit_umountf str_mount_partition_failed esp
}

#安装efi
function install_efi(){
    prints str_create_uefi_bootleader
    ${BUSYBOX} mkdir -p ${ESP_MOUNT}/EFI/{Boot,Microsoft/Boot}
    [ $? -eq 0 ] || err_exit_umountf str_creating_partition_folder_failed EFI
    ${BUSYBOX} cp -r ${WIN_MOUNT}/Windows/Boot/EFI/* ${ESP_MOUNT}/EFI/Microsoft/Boot
    [ $? -eq 0 ] || err_exit_umountf str_copying_files_failed EFI
    ${BUSYBOX} cp ${ESP_MOUNT}/EFI/Microsoft/Boot/bootmgfw.efi ${ESP_MOUNT}/EFI/Boot/bootaa64.efi
    [ $? -eq 0 ] || err_exit_umountf str_copying_files_failed "bootaa64.efi"
    ${BUSYBOX} cp ${BASE_PATH}/BCD ${ESP_MOUNT}/EFI/Microsoft/Boot/
    [ $? -eq 0 ] || err_exit_umountf str_copying_files_failed BCD
    ${BASE_PATH_BIN}/bcdboot ${ESP_MOUNT}/EFI/Microsoft/Boot/BCD ${WIN_PATH}
    [ $? -eq 0 ] || err_exit_umountf str_fix_files_failed BCD
}

#安装boot
function install_boot(){
    local using_boot="/dev/block/by-name/boot$(${TOOLBOX} getprop ro.boot.slot_suffix)"
    prints str_installing_boot
    [ -r ${SOURCES}/uefi.img ] || err_exitf str_cant_found_file "${SOURCES}/uefi.img"
    ${BUSYBOX} dd if=${SOURCES}/uefi.img of=${using_boot} bs=32M
    [ $? -eq 0 ] || err_exitf str_installing_boot_failed

}

check_umount $WIN_MOUNT
check_umount $ESP_MOUNT

mount_part
install_efi
install_boot

check_umount $WIN_MOUNT
check_umount $ESP_MOUNT
