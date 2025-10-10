#!/bin/sh
##########################################################
#
# log_compression.sh
#
# log003へログを集める前のログ圧縮用スクリプト
# 必要ファイル：コンフィグファイルのみ
#
##########################################################

# コンフィグファイル指定
CONFIG_FILE=$1

# 圧縮対象ファイル/ディレクトリ名日付指定
PASTDATE1=`date --date $2'day ago' '+%Y%m%d'`
PASTDATE2=`date --date $2'day ago' '+%Y-%m-%d'`
PASTDATE3=`date --date $2'day ago' '+%Y%m'`
PASTDATE4=`date --date $2'day ago' '+%d'`

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
        ORIG_IFS=$IFS
        IFS=":"
        j=0
        for config_piece in $line
        do
        IFS=$ORIG_IFS
                if [ $j -eq 0 ];
                then
                        File_Source=`echo $config_piece|sed s/'$PASTDATE1'/$PASTDATE1/ |sed  s/'$PASTDATE2'/$PASTDATE2/ \
                                        |sed  s/'$PASTDATE3'/$PASTDATE3/ |sed  s/'$PASTDATE4'/$PASTDATE4/`
                elif [ $j -eq 1 ];
                then
                        Dir_Dest=`echo $config_piece|sed s/'$PASTDATE1'/$PASTDATE1/ |sed  s/'$PASTDATE2'/$PASTDATE2/ \
                                        |sed  s/'$PASTDATE3'/$PASTDATE3/ |sed  s/'$PASTDATE4'/$PASTDATE4/`
                elif [ $j -eq 2 ];
                then
                        File_Dest=`echo $config_piece|sed s/'$PASTDATE1'/$PASTDATE1/ |sed  s/'$PASTDATE2'/$PASTDATE2/ \
                                        |sed  s/'$PASTDATE3'/$PASTDATE3/ |sed  s/'$PASTDATE4'/$PASTDATE4/`
                        File_Erase=`echo $config_piece|sed s/'$PASTDATE1'/*/ |sed  s/'$PASTDATE2'/*/ \
                                        |sed  s/'$PASTDATE3'/*/ |sed  s/'$PASTDATE4'/$PASTDATE4/`
                else
                        echo "error!irregular argument.exit."
                        exit 1
                fi
        j=`expr $j + 1`
        done
        # gzip後置き場確認
        if [ ! -d ${Dir_Dest} ];
        then
                echo "no DIR ${Dir_Dest} found. making now."
                mkdir -p ${Dir_Dest}
                chown log:log ${Dir_Dest}
        fi
        # gzip実施
        if [ -f ${File_Source} ];
        then
                /bin/gzip -c $File_Source > $Dir_Dest/$File_Dest
                echo "compressed $File_Dest."
                chown log:log $Dir_Dest/$File_Dest
        else
                echo "$File_Dest is not found."
        fi
        # 旧ファイル消去(7日前)
        rm -f `find $Dir_Dest -daystart -name $File_Erase -mtime +6 | xargs`
        echo "$File_Erase removed.(past 7days)"
done
echo "all done."
