#!/tmp/flash/bin/bash

if [ $DEBUG -eq 0 ]
then
    BACKUP_PATH="${IMAGES_PATH}/backups"
else
    BACKUP_PATH="/tmp/backups"
fi

backup_imgs=(
    "abl_a"
    "xbl_a"
    "fsg"
    "fsc"
    "modemst1"
    "modemst2"
    "modem_a"
    "boot$(${TOOLBOX} getprop ro.boot.slot_suffix)"
)

[ -d $BACKUP_PATH ] || ${BUSYBOX} mkdir -p ${BACKUP_PATH}
[ -d $BACKUP_PATH ] || err_exitf str_creating_partition_folder_failed "${BACKUP_PATH}"

for img_name in ${backup_imgs[@]}
do
    local if_path="/dev/block/by-name/${img_name}"
    local of_path="${BACKUP_PATH}/${img_name}.img"
    if [ -r $of_path ]; then
        prints str_exists_skip_backup "${img_name}" "${of_path}"
        continue
    fi

    if [ ! -r $if_path ]; then
        prints str_not_exists_skip_backup "${img_name}" "${if_path}"
        continue
    fi
    prints str_backing_up "${img_name}"
    ${BUSYBOX} dd if=${if_path} of=${of_path}
    [ $? -eq 0 ] || err_exitf str_backup_failed "${img_name}"

    prints str_successfully_backed_up_in "${img_name}" "${of_path}"
done