#!/tmp/flash/bin/bash


WIN_PART_NUM="$(get_part_value win Number )"
ESP_PART_NUM="$(get_part_value esp Number )"


[ -n "${WIN_PART_NUM}" ] || err_exit "win分区未找到，取消刷机" 10
[ -n "${ESP_PART_NUM}" ] || err_exit "esp分区未找到，取消刷机" 10

WIN_PATH="${DISK_PATH}${WIN_PART_NUM}"
WIN_MOUNT="/mnt/win"

ESP_PATH="${DISK_PATH}${ESP_PART_NUM}"
ESP_MOUNT="/mnt/esp"


ui_print "win分区:${WIN_PATH}"
ui_print "esp分区:${ESP_PATH}"

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
    ui_print "修复ntfs文件系统..."
    ${BASE_PATH_BIN}/ntfsfix ${WIN_PATH}
    [ $? -eq 0 ] || err_exit_umount "修复ntfs文件系统遇到错误，取消刷机" 10

    ui_print "挂载win和esp分区..."
    ${BUSYBOX} mkdir -p ${WIN_MOUNT} ${ESP_MOUNT}
    [ $? -eq 0 ] || err_exit_umount "创建分区文件夹遇到错误，取消刷机" 10
    ${BUSYBOX} mount -t ntfs ${WIN_PATH} ${WIN_MOUNT} 
    [ $? -eq 0 ] || err_exit_umount "挂载win分区遇到错误，取消刷机" 10
    ${BUSYBOX} mount -t vfat ${ESP_PATH} ${ESP_MOUNT}
    [ $? -eq 0 ] || err_exit_umount "挂载esp分区遇到错误，取消刷机" 10
}

#安装efi
function install_efi(){
    ui_print "建立win系统引导..."
    ${BUSYBOX} mkdir -p ${ESP_MOUNT}/EFI/{Boot,Microsoft/Boot}
    [ $? -eq 0 ] || err_exit_umount "创建EFI文件夹遇到错误，取消刷机" 10
    ${BUSYBOX} cp -r ${WIN_MOUNT}/Windows/Boot/EFI/* ${ESP_MOUNT}/EFI/Microsoft/Boot
    [ $? -eq 0 ] || err_exit_umount "复制EFI文件夹遇到错误，取消刷机" 10
    ${BUSYBOX} cp ${ESP_MOUNT}/EFI/Microsoft/Boot/bootmgfw.efi ${ESP_MOUNT}/EFI/Boot/bootaa64.efi
    [ $? -eq 0 ] || err_exit_umount "复制EFI文件遇到错误，取消刷机" 10
    ${BUSYBOX} cp ${BASE_PATH}/BCD ${ESP_MOUNT}/EFI/Microsoft/Boot/
    [ $? -eq 0 ] || err_exit_umount "复制BCD文件遇到错误，取消刷机" 10
    ${BASE_PATH_BIN}/bcdboot ${ESP_MOUNT}/EFI/Microsoft/Boot/BCD ${WIN_PATH}
    [ $? -eq 0 ] || err_exit_umount "修复BCD文件遇到错误，取消刷机" 10
}

#安装boot
function install_boot(){
    local using_boot="/dev/block/by-name/boot$(${TOOLBOX} getprop ro.boot.slot_suffix)"
    ui_print "安装uefi boot中..."
    [ -r ${SOURCES}/uefi.img ] || err_exit "找不到文件${SOURCES}/uefi.img" 404
    ${BUSYBOX} dd if=${SOURCES}/uefi.img of=${using_boot} bs=32M
    [ $? -eq 0 ] || err_exit "安装uefi boot遇到错误，取消刷机" 10

}

check_umount $WIN_MOUNT
check_umount $ESP_MOUNT

mount_part
install_efi
install_boot

check_umount $WIN_MOUNT
check_umount $ESP_MOUNT
