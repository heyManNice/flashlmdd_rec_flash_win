#!/tmp/flash/bin/bash

if [ $DEBUG -eq 0 ]
then
    BACKUP_PATH="${IMAGES_PATH}/backups"
else
    BACKUP_PATH="/tmp/backups"
fi

backup_imgs=(
    "abl_a"
    "fsg"
    "fsc"
    "modemst1"
    "modemst2"
    "modem_a"
    "boot$(${TOOLBOX} getprop ro.boot.slot_suffix)"
)

[ -d $BACKUP_PATH ] || ${BUSYBOX} mkdir -p ${BACKUP_PATH}
[ -d $BACKUP_PATH ] || err_exit "${BACKUP_PATH}目录创建失败，取消刷机" 10

for img_name in ${backup_imgs[@]}
do
    local if_path="/dev/block/by-name/${img_name}"
    local of_path="${BACKUP_PATH}/${img_name}.img"
    if [ -r $of_path ]; then
        ui_print "[${img_name}]：${of_path}已存在，跳过备份"
        continue
    fi

    if [ ! -r $if_path ]; then
        ui_print "[${img_name}]：${if_path}不存在，跳过备份"
        continue
    fi
    ui_print "正在备份[${img_name}]..."
    ${BUSYBOX} dd if=${if_path} of=${of_path}
    [ $? -eq 0 ] || err_exit "备份${img_name}遇到错误，取消刷机" 10

    ui_print "[${img_name}]成功备份在${of_path}"
done