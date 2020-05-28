# Резервное копирование
### Настраиваем бэкапы с помощью BorgBackup

## Задачи
### Настроить стенд Vagrant с двумя виртуальными машинами server и backup.

* Настроить политику бэкапа директории /etc с клиента (server) на бекап сервер (backup):

1. Бекап делаем раз в час
2. Политика хранения бекапов: храним все за последние 30 дней, и по одному за предыдущие два месяца.
3. Настроить логирование процесса бекапа в /var/log/ - название файла на ваше усмотрение
4. Восстановить из бекапа директорию /etc с помощью опции Borg mount

* Результатом должен быть скрипт резервного копирования (политику хранения можно реализовать в нем же), а так же вывод команд терминала записанный с помощью script (или другой подобной утилиты)

* Задание * Настроить репозиторий для резервных копий с шифрованием ключом.

* Задание ** Настроить резервирование логического бекапа базы данных ( база на ваш выбор ) с помощью BorgBackup


## Выполнение

### Подготовка

При подготовке стенда необходимо учесть, что клиент, подключающийся к серверу borgbackup должен иметь возможность беспарольного доступа. В моем случае это было реализовано генерацией ssh-ключа на клиенте и копированием его публичной части в autorized_keys сервера.
Т.к. хост server является клиентом в процедуре бэкапирования, то возможна некоторая путаница с именованием хостов. Дабы ее минимизировать, буду именовать хост отправляющий бэкапы __server либо __бэкап-клиент. Соответственно, хост хранящий бэкапы будет называться __backup либо __бэкап-сервер.
Учитывая, что некоторые файлы в каталоге /etc доступны даже для чтения только для root, то и процедуры будут настраиваться для root-пользователя, соответственно, доступ для root по ssh на бэкап-сервере должен быть включен - производится соовтетствующая настройка на сервере borgbackup.

Также необходимо установить саму утилиту на обоих хостах. Я выбрал установку пакета из репозитория epel-release.


### Основные действия

Инициирую репозиторий для бэкапа /etc с бэкап-клиента на бэкапа-сервере.  Опция -e repokey дает возможность создания шифрованного репозитория.
```
[root@server ~]# borg init -e repokey root@192.168.11.107:BorgRepoEtc
Enter new passphrase:
Enter same passphrase again:
Do you want your passphrase to be displayed for verification? [yN]:

By default repositories initialized with this version will produce security
errors if written to with an older version (up to and including Borg 1.0.8).

If you want to use these older versions, you can disable the check by running:
borg upgrade --disable-tam ssh://root@192.168.11.107/./BorgRepoEtc

See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.

IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!
Use "borg key export" to export the key, optionally in printable format.
Write down the passphrase. Store both at safe place(s).
```
#### Отступление
Для задачи на 2 звезды необходимо реализовать бэкапирование логической копии какой-либо БД - я выбрал mariadb. Столкнулся со следующей проблемой: при копировании двух бэкапов в один репозиторий не смог разобраться с тем как настроить политику хранения сразу двух бэкапов, долго пытался подобрать настройки, чтобы после удаления лишних (устаревших) копий сохранялись оба бэкапа в уникальном состоянии за необходимый период, но всегда сохраняется только один из них. Такую проблему решил сохранением каждого бэкапа в свой репозиторий. Если есть на этот счет какие-либо best practies, буду рад познакомиться с ними поближе - сам не нагуглил.

Инициирую репозиторий для бэкапа БД.
```
[root@server ~]# borg init -e repokey root@192.168.11.107:BorgRepoMYSQL
Enter new passphrase:
Enter same passphrase again:
Do you want your passphrase to be displayed for verification? [yN]:

By default repositories initialized with this version will produce security
errors if written to with an older version (up to and including Borg 1.0.8).

If you want to use these older versions, you can disable the check by running:
borg upgrade --disable-tam ssh://root@192.168.11.107/./BorgRepoMYSQL

See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.

IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!
Use "borg key export" to export the key, optionally in printable format.
Write down the passphrase. Store both at safe place(s).
```

Запускаю скрипт бэкапирования вручную, затем проверяю, что сохранилось в репозиториях
```
[root@server ~]# yes | borg list root@192.168.11.107:BorgRepoEtc
server_etc-2020-05-27_00:53:34       Wed, 2020-05-27 00:53:35 [5440c6c4b2d39128938d7e1709459293bc8d7e858760ff545996f9cc9a3ca794]
[root@server ~]# yes | borg list root@192.168.11.107:BorgRepoMYSQL
server_mysql-2020-05-27_00:53:39     Wed, 2020-05-27 00:53:40 [0116de48b89371578a97339f6faba6b294bf26c706885474a9f29413a4876f98]
```

Теперь, зная имя бэкапа, находящегося в репозитории, могут получить доступ к находящемся в нем файлам посредством команды borg mount
```
[root@server ~]# borg mount root@192.168.11.107:BorgRepoEtc /mnt
[root@server ~]#
```

Смотрю, какие файлы там находятся:
```
[root@server ~]# ll /mnt/server_etc-2020-05-27_00\:53\:34/etc/
total 815
-rw-r--r--. 1 root root       16 Jun  1  2019 adjtime
-rw-r--r--. 1 root root     1518 Jun  7  2013 aliases
-rw-r--r--. 1 root root    12288 May 24 11:27 aliases.db
drwxr-xr-x. 1 root root        0 May 26 23:11 alternatives
-rw-------. 1 root root      541 Nov 20  2018 anacrontab
drwxr-x---. 1 root root        0 Jun  1  2019 audisp
drwxr-x---. 1 root root        0 May 24 11:27 audit
drwxr-xr-x. 1 root root        0 Jun  1  2019 bash_completion.d
-rw-r--r--. 1 root root     2853 Oct 30  2018 bashrc
drwxr-xr-x. 1 root root        0 Apr 25  2019 binfmt.d
-rw-r--r--. 1 root root       38 Nov 23  2018 centos-release
-rw-r--r--. 1 root root       51 Nov 23  2018 centos-release-upstream
drwxr-xr-x. 1 root root        0 Aug  4  2017 chkconfig.d
-rw-r--r--. 1 root root     1108 Apr 12  2018 chrony.conf
-rw-r-----. 1 root chrony    481 Sep 15  2017 chrony.keys
drwxr-xr-x. 1 root root        0 Jun  1  2019 cifs-utils
drwxr-xr-x. 1 root root        0 Jun  1  2019 cron.d
drwxr-xr-x. 1 root root        0 Jun  1  2019 cron.daily
-rw-------. 1 root root        0 Nov 20  2018 cron.deny
drwxr-xr-x. 1 root root        0 Jun  9  2014 cron.hourly
drwxr-xr-x. 1 root root        0 Jun  9  2014 cron.monthly
-rw-r--r--. 1 root root      451 Jun  9  2014 crontab
drwxr-xr-x. 1 root root        0 Jun  9  2014 cron.weekly
-rw-------. 1 root root        0 Jun  1  2019 crypttab
-rw-r--r--. 1 root root     1620 Oct 30  2018 csh.cshrc
-rw-r--r--. 1 root root      866 Oct 30  2018 csh.login
drwxr-xr-x. 1 root root        0 Jun  1  2019 dbus-1
drwxr-xr-x. 1 root root        0 Jun  1  2019 default
drwxr-xr-x. 1 root root        0 Jun  1  2019 depmod.d
drwxr-x---. 1 root root        0 Jun  1  2019 dhcp
-rw-r--r--. 1 root root     5090 Oct 30  2018 DIR_COLORS
-rw-r--r--. 1 root root     5725 Oct 30  2018 DIR_COLORS.256color
-rw-r--r--. 1 root root     4669 Oct 30  2018 DIR_COLORS.lightbgcolor
-rw-r--r--. 1 root root     1285 Nov  2  2018 dracut.conf
drwxr-xr-x. 1 root root        0 Jun  1  2019 dracut.conf.d
-rw-r--r--. 1 root root      112 Oct 30  2018 e2fsck.conf
-rw-r--r--. 1 root root        0 Oct 30  2018 environment
-rw-r--r--. 1 root root     1317 Apr 11  2018 ethertypes
-rw-r--r--. 1 root root        0 Jun  7  2013 exports
drwxr-xr-x. 1 root root        0 Nov  7  2018 exports.d
-rw-r--r--. 1 root root       70 Oct 30  2018 filesystems
drwxr-x---. 1 root root        0 Jun  1  2019 firewalld
-rw-r--r--. 1 root root      346 Jun  1  2019 fstab
-rw-r--r--. 1 root root       38 Oct 30  2018 fuse.conf
drwxr-xr-x. 1 root root        0 Aug  2  2017 gcrypt
-rw-r--r--. 1 root root      842 Oct 30  2018 GeoIP.conf
-rw-r--r--. 1 root root      858 Oct 30  2018 GeoIP.conf.default
drwxr-xr-x. 1 root root        0 Jul 13  2018 gnupg
-rw-r--r--. 1 root root       94 Mar 24  2017 GREP_COLORS
drwxr-xr-x. 1 root root        0 Jun  1  2019 groff
-rw-r--r--. 1 root root      545 May 26 23:11 group
-rw-r--r--. 1 root root      533 May 26 22:45 group-
lrwxrwxrwx. 1 root root       22 Jun  1  2019 grub2.cfg -> ../boot/grub2/grub.cfg
drwx------. 1 root root        0 Jun  1  2019 grub.d
----------. 1 root root      435 May 26 23:11 gshadow
----------. 1 root root      425 May 26 22:45 gshadow-
drwxr-xr-x. 1 root root        0 Jun  1  2019 gss
drwxr-xr-x. 1 root root        0 Jun  1  2019 gssproxy
-rw-r--r--. 1 root root        9 Jun  7  2013 host.conf
-rw-r--r--. 1 root root        7 May 24 11:28 hostname
-rw-r--r--. 1 root root      182 May 24 11:28 hosts
-rw-r--r--. 1 root root      370 Jun  7  2013 hosts.allow
-rw-r--r--. 1 root root      460 Jun  7  2013 hosts.deny
-rw-r--r--. 1 root root     4849 Apr 11  2018 idmapd.conf
lrwxrwxrwx. 1 root root       11 Jun  1  2019 init.d -> rc.d/init.d
-rw-r--r--. 1 root root      511 Oct 30  2018 inittab
-rw-r--r--. 1 root root      942 Jun  7  2013 inputrc
drwxr-xr-x. 1 root root        0 Jun  1  2019 iproute2
-rw-r--r--. 1 root root       23 Nov 23  2018 issue
-rw-r--r--. 1 root root       22 Nov 23  2018 issue.net
-rw-r--r--. 1 root root      641 Jan 29  2019 krb5.conf
drwxr-xr-x. 1 root root        0 Jan 29  2019 krb5.conf.d
-rw-r--r--. 1 root root    22989 May 26 23:33 ld.so.cache
-rw-r--r--. 1 root root       28 Feb 27  2013 ld.so.conf
drwxr-xr-x. 1 root root        0 May 26 23:09 ld.so.conf.d
-rw-r-----. 1 root root      191 Jun 19  2018 libaudit.conf
drwxr-xr-x. 1 root root        0 Jun  1  2019 libnl
-rw-r--r--. 1 root root     2388 Jun  1  2019 libuser.conf
-rw-r--r--. 1 root root       19 Jun  1  2019 locale.conf
lrwxrwxrwx. 1 root root       25 Jun  1  2019 localtime -> ../usr/share/zoneinfo/UTC
-rw-r--r--. 1 root root     2043 Jun  1  2019 login.defs
-rw-r--r--. 1 root root      662 Jul 31  2013 logrotate.conf
drwxr-xr-x. 1 root root        0 May 26 23:11 logrotate.d
-r--r--r--. 1 root root       33 May 24 11:27 machine-id
-rw-r--r--. 1 root root      111 Oct 30  2018 magic
-rw-r--r--. 1 root root     5171 Oct 30  2018 man_db.conf
drwxr-xr-x. 1 root root        0 May 26 20:42 mc
-rw-r--r--. 1 root root      936 Oct 30  2018 mke2fs.conf
drwxr-xr-x. 1 root root        0 Jun  1  2019 modprobe.d
drwxr-xr-x. 1 root root        0 Apr 25  2019 modules-load.d
-rw-r--r--. 1 root root        0 Jun  7  2013 motd
lrwxrwxrwx. 1 root root       17 Jun  1  2019 mtab -> /proc/self/mounts
-rw-r--r--. 1 root root      570 Nov 27 16:24 my.cnf
drwxr-xr-x. 1 root root        0 May 26 23:11 my.cnf.d
-rw-r--r--. 1 root root      767 Oct 31  2018 netconfig
drwxr-xr-x. 1 root root        0 May 15  2018 NetworkManager
-rw-r--r--. 1 root root       58 Oct 30  2018 networks
-rw-r--r--. 1 root root      967 Nov  7  2018 nfs.conf
-rw-r--r--. 1 root root     3391 Nov  7  2018 nfsmount.conf
-rw-r--r--. 1 root root     1746 Jun  1  2019 nsswitch.conf
-rw-r--r--. 1 root root     1735 May  8  2019 nsswitch.conf.bak
drwxr-xr-x. 1 root root        0 Jun  1  2019 openldap
drwxr-xr-x. 1 root root        0 Apr 11  2018 opt
-rw-r--r--. 1 root root      393 Nov 23  2018 os-release
drwxr-xr-x. 1 root root        0 Jun  1  2019 pam.d
-rw-r--r--. 1 root root     1144 May 26 23:11 passwd
-rw-r--r--. 1 root root     1086 May 26 22:45 passwd-
drwxr-xr-x. 1 root root        0 Jun  1  2019 pkcs11
drwxr-xr-x. 1 root root        0 Jun  1  2019 pki
drwxr-xr-x. 1 root root        0 Jun  1  2019 pm
drwxr-xr-x. 1 root root        0 Jun  1  2019 polkit-1
drwxr-xr-x. 1 root root        0 Jun 10  2014 popt.d
drwxr-xr-x. 1 root root        0 Jun  1  2019 postfix
drwxr-xr-x. 1 root root        0 Jun  1  2019 ppp
drwxr-xr-x. 1 root root        0 Jun  1  2019 prelink.conf.d
-rw-r--r--. 1 root root      233 Jun  7  2013 printcap
-rw-r--r--. 1 root root     1819 Oct 30  2018 profile
drwxr-xr-x. 1 root root        0 May 26 22:22 profile.d
-rw-r--r--. 1 root root     6545 Oct 30  2018 protocols
drwxr-xr-x. 1 root root        0 Jun  1  2019 python
drwxr-xr-x. 1 root root        0 Jun  1  2019 qemu-ga
lrwxrwxrwx. 1 root root       10 Jun  1  2019 rc0.d -> rc.d/rc0.d
lrwxrwxrwx. 1 root root       10 Jun  1  2019 rc1.d -> rc.d/rc1.d
lrwxrwxrwx. 1 root root       10 Jun  1  2019 rc2.d -> rc.d/rc2.d
lrwxrwxrwx. 1 root root       10 Jun  1  2019 rc3.d -> rc.d/rc3.d
lrwxrwxrwx. 1 root root       10 Jun  1  2019 rc4.d -> rc.d/rc4.d
lrwxrwxrwx. 1 root root       10 Jun  1  2019 rc5.d -> rc.d/rc5.d
lrwxrwxrwx. 1 root root       10 Jun  1  2019 rc6.d -> rc.d/rc6.d
drwxr-xr-x. 1 root root        0 Jun  1  2019 rc.d
lrwxrwxrwx. 1 root root       13 Jun  1  2019 rc.local -> rc.d/rc.local
lrwxrwxrwx. 1 root root       14 Jun  1  2019 redhat-release -> centos-release
-rw-r--r--. 1 root root     1787 Jun 10  2014 request-key.conf
drwxr-xr-x. 1 root root        0 Jun  1  2019 request-key.d
-rw-r--r--. 1 root root       50 May 24 11:28 resolv.conf
-rw-r--r--. 1 root root     1634 Dec 25  2012 rpc
drwxr-xr-x. 1 root root        0 May 26 20:42 rpm
-rw-r--r--. 1 root root      458 Apr 25  2019 rsyncd.conf
-rw-r--r--. 1 root root     3232 Oct 30  2018 rsyslog.conf
drwxr-xr-x. 1 root root        0 Oct 30  2018 rsyslog.d
-rw-r--r--. 1 root root      966 Oct 30  2018 rwtab
drwxr-xr-x. 1 root root        0 Oct 30  2018 rwtab.d
drwxr-xr-x. 1 root root        0 Jun  1  2019 samba
drwxr-xr-x. 1 root root        0 Jun  1  2019 sasl2
-rw-------. 1 root root      221 Oct 30  2018 securetty
drwxr-xr-x. 1 root root        0 Jun  1  2019 security
drwxr-xr-x. 1 root root        0 May 24 23:05 selinux
-rw-r--r--. 1 root root   670293 Jun  7  2013 services
-rw-r--r--. 1 root root      216 Jan 29  2019 sestatus.conf
----------. 1 root root      665 May 26 23:11 shadow
----------. 1 root root      644 May 26 22:45 shadow-
-rw-r--r--. 1 root root       44 Oct 30  2018 shells
drwxr-xr-x. 1 root root        0 Apr 11  2018 skel
drwxr-xr-x. 1 root root        0 May 24 23:05 ssh
drwxr-xr-x. 1 root root        0 Jun  1  2019 ssl
-rw-r--r--. 1 root root      212 Oct 30  2018 statetab
drwxr-xr-x. 1 root root        0 Oct 30  2018 statetab.d
-rw-r--r--. 1 root root        0 Oct 30  2018 subgid
-rw-r--r--. 1 root root        0 Oct 30  2018 subuid
-rw-r-----. 1 root root     1786 Oct 30  2018 sudo.conf
-r--r-----. 1 root root     4328 Oct 30  2018 sudoers
drwxr-x---. 1 root root        0 Jun  1  2019 sudoers.d
-rw-r-----. 1 root root     3181 Oct 30  2018 sudo-ldap.conf
drwxr-xr-x. 1 root root        0 May 24 11:28 sysconfig
-rw-r--r--. 1 root root      449 Oct 30  2018 sysctl.conf
drwxr-xr-x. 1 root root        0 Jun  1  2019 sysctl.d
drwxr-xr-x. 1 root root        0 Jun  1  2019 systemd
lrwxrwxrwx. 1 root root       14 Jun  1  2019 system-release -> centos-release
-rw-r--r--. 1 root root       23 Nov 23  2018 system-release-cpe
drwxr-xr-x. 1 root root        0 Sep  6  2017 terminfo
drwxr-xr-x. 1 root root        0 Apr 25  2019 tmpfiles.d
drwxr-xr-x. 1 root root        0 Jun  1  2019 tuned
drwxr-xr-x. 1 root root        0 May 24 11:27 udev
-rw-r--r--. 1 root root       37 Jun  1  2019 vconsole.conf
-rw-r--r--. 1 root root     1982 Aug  9  2019 vimrc
-rw-r--r--. 1 root root     1982 Oct 30  2018 virc
drwxr-xr-x. 1 root root        0 Jun  1  2019 vmware-tools
drwxr-xr-x. 1 root root        0 Jun  1  2019 wpa_supplicant
drwxr-xr-x. 1 root root        0 Jun  1  2019 X11
drwxr-xr-x. 1 root root        0 Jun  1  2019 xdg
drwxr-xr-x. 1 root root        0 Apr 11  2018 xinetd.d
drwxr-xr-x. 1 root root        0 Jun  1  2019 yum
-rw-r--r--. 1 root root      970 Nov  5  2018 yum.conf
drwxr-xr-x. 1 root root        0 May 24 22:58 yum.repos.d
[root@server ~]#
```

Для размонтирования можно воспользоваться командой
```
borg umount /mnt
```

Добавляю скрипт в crontab для root для выполнения раз в час:
```
[root@server ~]# crontab -l
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * command to be executed

5 * * * * /root/backup.sh
```


## Итоги
Таким образом, получилось создать шифрованные репозитории для хранения файлов /etc и логической копии БД Mysql.

