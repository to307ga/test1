#!/bin/sh
##############################################
#
# log_Harvester.sh
#
# コンフィグファイルを読み込み、対象ホストの
# 対象DIRからファイルを収集するスクリプト
#
##############################################
# 必要ファイル：$CONFIGS_DIR/Sendmail.pl
# 使用方法： CONFIG_FILESに、対象とするファイルを記載して実行。
#            コンフィグの記述方法はコンフィグのヘルプを参照
##############################################
# コンフィグファイル、Sendmail.pl配置DIR
CONFIGS_DIR="/home/idclog/gathering_log"

# コンフィグファイル配列
CONFIG_FILES=( "logharvest_gooid_batch00x" "logharvest_gooid_edb00x" "logharvest_gooid_fgw00x" "logharvest_gooid_hlp00x" "logharvest_gooid_host00x" "logharvest_gooid_log00x" "logharvest_gooid_mdb00x" "logharvest_gooid_msg00x" "logharvest_gooid_oidc00x" "logharvest_gooid_rproxy00x" "logharvest_gooid_sdb00x" "logharvest_gooid_web00x" "logharvest_idhub_batch00x" "logharvest_idhub_hlp00x" "logharvest_idhub_mdb00x" "logharvest_idhub_rproxy00x" "logharvest_idhub_sdb00x" "logharvest_idhub_web00x")

# 失敗メール送信アドレス
MAIL_TO="r-yama@nttr.co.jp"

# 収穫したログファイルを配置するDIR
DEST_DIR_PREFIX="/logs"

# 取得先使用ユーザ
HARVESTING_USER="log"

# ファイル/ディレクトリ名日付指定
PASTDATE1=`date --date $1'day ago' '+%Y%m%d'`
PASTDATE2=`date --date $1'day ago' '+%Y-%m-%d'`
PASTDATE3=`date --date $1'day ago' '+%Y%m'`

# エラーログ用意
ERROR_LOG="Report the SCP failure occurred on mt-top0-os9000-slog\n"
ERROR_FLAG=0

# コンフィグ毎ループ開始
for CONFIG in ${CONFIG_FILES[@]}
do
        # ホストリストの読み込み
        unset hostlist[@]
        READ_HOST_LIST=`/bin/cat $CONFIGS_DIR/$CONFIG | grep -v ^# | grep "^hostlist"`
        i=0
        j=0
        for temp_host in $READ_HOST_LIST
        do
                if [ $i -ne 0 ];
                then
                        hostlist[$j]=$temp_host
                        i=`expr $i + 1`
                        j=`expr $j + 1`
                else
                        i=`expr $i + 1`
                fi
        done

        all_host_num=`expr $j - 1`

        unset hostlist[$all_host_num]

        # ログリストの読み込み(エラー報告あり)
        unset loglist[@]
        i=0
        READ_LOG_LIST=`/bin/cat $CONFIGS_DIR/$CONFIG | grep -v ^# | grep "^LogList"`
        for temp_list in $READ_LOG_LIST
        do
                loglist[$i]=$temp_list
                i=`expr $i + 1`
        done

        # ログリストの読み込み(エラー報告なし)
        unset loglist_noerror[@]
        i=0
        READ_LOG_LIST_noerror=`/bin/cat $CONFIGS_DIR/$CONFIG | grep -v ^# | grep "^NOERROR_LogList"`
        for temp_list in $READ_LOG_LIST_noerror
        do
                loglist_noerror[$i]=$temp_list
                i=`expr $i + 1`
        done

        # 対象ホスト毎の実行
        for host in ${hostlist[@]}
        do
        echo $host
        # ログリスト毎の実行(エラー報告あり)
                for log_line in ${loglist[@]}
                do
                        # ログリスト分解
                        ORIG_IFS=$IFS
                        IFS=":"
                        i=0
                        for log_hash in $log_line
                        do
                                if [ $i -eq 1 ];
                                then
                                        source_DIR=`echo $log_hash|sed s/'$PASTDATE1'/$PASTDATE1/ |sed  s/'$PASTDATE2'/$PASTDATE2/ \
                                         |sed  s/'$PASTDATE3'/$PASTDATE3/ |sed s/'$HOSTNAME'/$host/`
                                elif [ $i -eq 2 ];
                                then
                                        source_FILENAME=`echo $log_hash|sed s/'$PASTDATE1'/$PASTDATE1/ |sed  s/'$PASTDATE2'/$PASTDATE2/ \
                                        |sed  s/'$PASTDATE3'/$PASTDATE3/ |sed s/'$HOSTNAME'/$host/`
                                elif [ $i -eq 3 ];
                                then
                                        dest_DIR=$log_hash
                                fi
                        i=`expr $i + 1`
                        done

                        # HOSTNAME 変換
                        DEST_DIR_CONV=`echo $dest_DIR|sed s/'$HOSTNAME'/$host/ |sed s/'$PASTDATE1'/$PASTDATE1/ \
                                        |sed  s/'$PASTDATE2'/$PASTDATE2/ |sed  s/'$PASTDATE3'/$PASTDATE3/`

                        IFS=$ORIG_IFS

                        # ログファイル置き場確認
                        if [ ! -d ${DEST_DIR_PREFIX}${DEST_DIR_CONV} ];
                        then
                                echo "no DIR ${DEST_DIR_PREFIX}${DEST_DIR_CONV} found. making now."
                                mkdir -p ${DEST_DIR_PREFIX}${DEST_DIR_CONV}
                        fi
                        # ログファイル取得実行
                        scp -p $HARVESTING_USER@${host}:${source_DIR}${source_FILENAME} ${DEST_DIR_PREFIX}${DEST_DIR_CONV}
                        if [ $? -eq 0 ];
                        then
                                echo "Get ${source_FILENAME} from ${host} succeed."
                        else
                                echo "Failed to get ${source_FILENAME} from ${host}."
                        fi
                        # エラーログ保存
                        if [ ! -f ${DEST_DIR_PREFIX}${DEST_DIR_CONV}${source_FILENAME} ];
                        then
                                ERROR_LOG=$ERROR_LOG"[${host}] FAIL TO GET LOGFILE -> ${source_DIR}${source_FILENAME} \n"
                                ERROR_FLAG=1
                        fi
                done
                # ログリスト毎の実行(エラー報告なし)
                for log_line in ${loglist_noerror[@]}
                do
                        # ログリスト分解
                        ORIG_IFS=$IFS
                        IFS=":"
                        i=0
                        for log_hash in $log_line
                        do
                                if [ $i -eq 1 ];
                                then
                                        source_DIR=`echo $log_hash|sed s/'$PASTDATE1'/$PASTDATE1/ |sed  s/'$PASTDATE2'/$PASTDATE2/ \
                                                |sed  s/'$PASTDATE3'/$PASTDATE3/ |sed s/'$HOSTNAME'/$host/`
                                elif [ $i -eq 2 ];
                                then
                                        source_FILENAME=`echo $log_hash|sed s/'$PASTDATE1'/$PASTDATE1/ |sed  s/'$PASTDATE2'/$PASTDATE2/ \
                                                |sed  s/'$PASTDATE3'/$PASTDATE3/ |sed s/'$HOSTNAME'/$host/`
                                elif [ $i -eq 3 ];
                                then
                                        dest_DIR=$log_hash
                                fi
                        i=`expr $i + 1`
                        done

                        # HOSTNAME 変換
                        DEST_DIR_CONV=`echo $dest_DIR|sed s/'$HOSTNAME'/$host/ |sed s/'$PASTDATE1'/$PASTDATE1/ \
                                                |sed  s/'$PASTDATE2'/$PASTDATE2/ |sed  s/'$PASTDATE3'/$PASTDATE3/`

                        IFS=$ORIG_IFS

                        # ログファイル置き場確認
                        if [ ! -d ${DEST_DIR_PREFIX}${DEST_DIR_CONV} ];
                        then
                                echo "no DIR ${DEST_DIR_PREFIX}${DEST_DIR_CONV} found. making now."
                                mkdir -p ${DEST_DIR_PREFIX}${DEST_DIR_CONV}
                        fi
                        # ログファイル取得実行
                        scp -p $HARVESTING_USER@${host}:${source_DIR}${source_FILENAME} ${DEST_DIR_PREFIX}${DEST_DIR_CONV}
                        if [ $? -eq 0 ];
                        then
                               echo "Get ${source_FILENAME} from ${host} succeed."
                        else
                                echo "Failed to get ${source_FILENAME} from ${host}."
                        fi
                done
        done
done
# エラーメール送信
#if [ $ERROR_FLAG -eq 1 ];
#then
#        echo -e "$ERROR_LOG"|$CONFIGS_DIR/Sendmail.pl "LOG_HARVESTER'S FAIL LOGGER@mt-top0-os9000-slog" "$MAIL_TO"
#        echo "Getting some files was failed. send the report mail."
#else
#        echo "Getting All files was done."
#fi
