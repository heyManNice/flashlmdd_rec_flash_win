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
[ -d $BACKUP_PATH ] || err_exit "${BACKUP_PATH}${STR_RES[mkdir_failed]},${STR_RES[cancel_flashing]}" 10

for img_name in ${backup_imgs[@]}
do
    local if_path="/dev/block/by-name/${img_name}"
    local of_path="${BACKUP_PATH}/${img_name}.img"
    if [ -r $of_path ]; then
        ui_print "[${img_name}]：${of_path}${STR_RES[exists_skip_backup]}"
        continue
    fi

    if [ ! -r $if_path ]; then
        ui_print "[${img_name}]：${if_path}${STR_RES[not_exists_skip_backup]}"
        continue
    fi
    ui_print "${STR_RES[backing_up]}[${img_name}]..."
    ${BUSYBOX} dd if=${if_path} of=${of_path}
    [ $? -eq 0 ] || err_exit "${STR_RES[backup]}${img_name}${STR_RES[failed]},${STR_RES[cancel_flashing]}" 10

    ui_print "[${img_name}]${STR_RES[successfully_backed_up_in]}${of_path}"
done