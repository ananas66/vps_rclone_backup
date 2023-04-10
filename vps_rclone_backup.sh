#!/bin/bash



# 关键参数，需自行修改

BACKUP_NAME="vps_app" # 压缩后的文件名

BACKUP_PATH="/home/app" # 备份目标文件夹

BACKUP_NUM=5 # 历史备份总数

PASSWD="yourpasswd" # 压缩密码

TMP_PATH="/home/backup" # 临时文件路径

REMOTE_PATH="gd:backup/vps_app" # 远程目录

NEW_BACKUP="$BACKUP_NAME-$(date "+%Y-%m-%d")"



check_tmp_path(){

# 创建备份目录

if [ ! -d "$TMP_PATH" ]; then

  mkdir -p "$TMP_PATH"

fi

cd $TMP_PATH

}



upload(){

  check_tmp_path

  # 创建临时备份目录

  echo -e "[Starting time: `date +'%Y-%m-%d %H:%M:%S'`]"

  TIME_START=$(date +%s)

  mkdir -p $NEW_BACKUP



  # 复制备份和加密打包压缩

  cp -rdp $BACKUP_PATH $NEW_BACKUP

  tar -zcf - $NEW_BACKUP | openssl des3 -salt -k $PASSWD | dd of=$NEW_BACKUP.tar.gz

  rm -rf $NEW_BACKUP



  # 通过rclone远程备份

  CUR_BACKUP_NUM=$(/usr/bin/rclone ls $REMOTE_PATH | awk '{print $2}' | grep -E $BACKUP_NAME | grep -E ".tar.gz" | sort -nr | wc -l)

  while [ "$CUR_BACKUP_NUM" -ge "$BACKUP_NUM" ]

  do

    OLDEST_BACK_UP=$(/usr/bin/rclone ls $REMOTE_PATH | awk '{print $2}' | grep -E $BACKUP_NAME | grep -E ".tar.gz" | sort -n | awk 'NR==1{print}')

    /usr/bin/rclone deletefile $REMOTE_PATH/$OLDEST_BACK_UP

    sleep 5

    CUR_BACKUP_NUM=$(/usr/bin/rclone ls $REMOTE_PATH | awk '{print $2}' | grep -E $BACKUP_NAME | grep -E ".tar.gz" | sort -nr | wc -l)

  done

  /usr/bin/rclone move -vP $TMP_PATH/$NEW_BACKUP.tar.gz $REMOTE_PATH



  echo -e "[End time: `date +'%Y-%m-%d %H:%M:%S'`]"

  TIME_END=$(date +%s)

  echo -e "The latest backup has been uploaded to $REMOTE_PATH"

}



download(){

  check_backup_path

  

  # 输出远程目录的备份文件名

  BACKUP_LIST=$(/usr/bin/rclone ls $REMOTE_PATH | awk '{print $2}' | grep -E $BACKUP_NAME | grep -E ".tar.gz" | sort -nr | head -n $BACKUP_NUM)

  idx=1

  echo -e "Select the file you want to download."

  for backup in $BACKUP_LIST; do

    echo -e "$idx : $backup"

    idx=$((idx+1))

  done



  # 获取目标备份

  read -p "Please input the index of backup: " input_idx

  TARGET_BACKUP=$(/usr/bin/rclone ls $REMOTE_PATH | awk '{print $2}' | grep -E $BACKUP_NAME | grep -E ".tar.gz" | sort -nr | awk 'NR=='$input_idx'{print}')

  /usr/bin/rclone copy -vP $REMOTE_PATH/$TARGET_BACKUP .

  dd if=$TARGET_BACKUP | openssl des3 -d -k $MYSQL_ROOT_PASSWD | tar -zxf -

  rm -rf $TARGET_BACKUP

  echo -e "The latest backup has been downloaded to $TMP_PATH."

}



case "$1" in

        upload|download)

        $1

        ;;

        *)

        echo "Usage: bash $0 { upload | download }"

        RETVAL=1

        ;;

esac

exit $RETVA



exit 0

