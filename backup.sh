#!/bin/bash

LOCKFILE=/tmp/borg.lock
if [ -e ${LOCKFILE} ] && kill -0 $(cat ${LOCKFILE}); then
        echo "borgbackup is already running..."
        exit
fi

trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ >${LOCKFILE}

LOG=/var/log/borgbackup.log
BACKUP_USER="root"
BORG_HOST="192.168.11.107"
BORG_REPO_ETC=BorgRepoEtc
BORG_REPO_MYSQL=BorgRepoMYSQL
OPTIONS="${BACKUP_USER}@${BORG_HOST}"
DBDUMPPATH=/root/db_dump.sql


/bin/mysqldump -uroot -p1qaz2wsx3edc4rfv --all-databases >${DBDUMPPATH}

yes | /bin/borg create --list -v --stats ${OPTIONS}:${BORG_REPO_ETC}::"server_etc-{now:%Y-%m-%d_%H:%M:%S}" /etc >>${LOG} 2>&1
yes | /bin/borg create --list -v --stats ${OPTIONS}:${BORG_REPO_MYSQL}::"server_mysql-{now:%Y-%m-%d_%H:%M:%S}" ${DBDUMPPATH} >>${LOG} 2>&1
rm -f ${DBDUMPPATH}

/bin/borg prune --list -v ${OPTIONS}:${BORG_REPO_ETC} --keep-daily=30 --keep-monthly=2 >>${LOG} 2>&1
/bin/borg prune --list -v ${OPTIONS}:${BORG_REPO_MYSQL} --keep-daily=30 --keep-monthly=2 >>${LOG} 2>&1

rm -f ${LOCKFILE}
