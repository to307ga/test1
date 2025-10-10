#!/bin/sh
##########################################################
#
# source_log_delete.sh
#
# 元のログ削除用スクリプト
# 必要ファイル：コンフィグファイルのみ
#
##########################################################

# コンフィグファイル指定
CONFIG_FILE=$1

# 実行ホスト確認
MY_HOST_NAME=`/bin/hostname -s`
echo $CONFIG_FILE |grep $MY_HOST_NAME > /dev/null
if [ $? -ne 0 ];
then
        echo "irregular hostname.exit."
        exit 1
fi

# メイン 
READ_LOG=`/bin/cat $CONFIG_FILE|grep -v ^#`

i=0
for line in $READ_LOG
do
        CONFIG_LINE[$i]=$line
        i=`expr $i + 1`
done

for line in ${CONFIG_LINE[@]}
do
        Dir_Source=`echo "$line" | awk 'BEGIN{FS=":"} {print $1}'`
        File_Erase=`echo "$line" | awk 'BEGIN{FS=":"} {print $2}'`
        DELDATE=`echo "$line" | awk 'BEGIN{FS=":"} {print $3}'`

        echo "Dir_Source = ${Dir_Source}" 
        echo "File_Erase = ${File_Erase}"
        echo "DELDATE = ${DELDATE}"

        # 旧ファイル消去(N日前)
        find ${Dir_Source} -daystart -name ${File_Erase}* -type f -mtime +${DELDATE} | xargs
        rm -f `find ${Dir_Source} -daystart -name ${File_Erase}* -type f -mtime +${DELDATE} | xargs`
done
echo "all done."
