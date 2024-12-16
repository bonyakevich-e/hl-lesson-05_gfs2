### OTUS High Load Lesson #05 | Subject: ISCSI, multipath и кластерные файловые системы: GFS2 
---------------------------
### ЦЕЛЬ: Реализация GFS2 хранилища 
---------------------------
### ВЫПОЛНЕНИЕ

Стенд состоит из 3 виртуальных машин: 
1. одна виртуальная машина, на которой расшариваем диск по ISCSI с файловой системой GFS2. Имя виртуальной машины - `iscsi`
2. три виртуальных машины, собранны в кластер, которые будут получать совместный доступ к iscsi-диску

Стенд разворачивается с помощью Terraform. В процессе развёртывания создается и запускается Ansible playbook, который выполняет необходимые настройки.

На виртуальных машинах используется операционная система __Ubuntu 24.04__

Для настройки ISCSI сервера Ansible использует bash скрипт, который генерируется в процессе выполнения terraform манифеста.

Используются следующие переменные:

`cluster_size` - количество машины, из которых состоит кластер

`cluster_instance_name` - имя инстансов кластера, а также имя самого кластера. Например, если указана переменная mycluster, будет собран кластер с названием "mycluster", и три члена кластера "mycluster[1,2,3]"

`system_user` - пользователь для подключения к виртуальным машинам

`iqn_base` - база iqn, с которой будут строиться iqn сервера и iqn клиентов

`vg_name` - название VG, который будет создан поверх iscsi диска

`lv_name` - название LV, который будет создан поверх iscsi диска

`fs_name` - название файловой системы GFS2, которая буде создана поверх iscsi диска

1  lsblk
    2  vim /etc/corosync/corosync.conf

system {
        allow_knet_handle_fallback: yes
}

totem {
        version: 2
        cluster_name: fs01
        secauth: off
}

logging {
        to_syslog: yes
}

quorum {
        provider: corosync_votequorum
}

nodelist {

        node {
                name: cluster1
                nodeid: 1
                ring0_addr: 10.16.0.3
        }
        node {
                name: cluster2
                nodeid: 2
                ring0_addr: 10.16.0.8
        }
        node {
                name: cluster3
                nodeid: 3
                ring0_addr: 10.16.0.23
        }
}


    3  systemctl start corosync
    4  systemctl status corosync
    5  systemctl restart corosync
    6  systemctl status corosync
    7  corosync list
    8  corosync status
    9  man corosync 
   10  corosync_overview
   11  cat /etc/hosts
   12  vim /etc/corosync/corosync.conf
   13  corosync-cfgtool -R
   14  corosync status
   15  systemctl status corosync
   16  corosync-quorumtool
   17  systemctl status dlm
   18  vim /etc/dlm/dlm.conf
   19  mkdir  /etc/dlm/
   20  vim /etc/dlm/dlm.conf
   21  systemctl restart dlm
   22  systemctl status dlm
   23  dlm_tool status
   24  vim /etc/lvm/lvm.conf 
   25  systemctl start lvmlockd
   26  apt-get install lvm2-lockd
   27  systemctl start lvmlockd
   28  man lvchange
   29  lvmlockctl -i
   30  lvcreate --name lv01 --size=100%VG vg01
   31  lvcreate --name lv01 --size=100% vg01
   32  lvcreate --name lv01 --size=+100%FREE vg01
   33  lvcreate --name lv01 -l +100%FREE vg01
   34  systemctl status lvm2
   35  systemctl status lvm
   36  vgchange --lock-start
   37  lvcreate --name lv01 -l +100%FREE vg01
   38  mkfs.gfs2 -p lock_dlm -t cluster_name:fs01 -j 3 /dev/vg01/lv01
   39  mount /dev/vg01/lv01 /mnt
   40  ll /mnt/
   41  mount /dev/vg01/lv01 /mnt/
   42  dmesg
   43  :q
   44  vim /etc/lvm/lvm.conf 
   45  vim /etc/corosync/corosync.conf 
   46  systemctl restart corosync
   47  systemctl status corosync
   48* 
   49  systemctl stop lvmlockd
   50  lvchange -an
   51  lvchange -an lv01
   52  lvchange -an /dev/vg01/lv01
   53  dmesg
   54  kpartx -d /dev/vg01/lv01
   55  lvchange -an /dev/vg01/lv01
   56  vgchange --lock-stop
   57  systemctl dlm stop
   58  systemctl stop dlm
   59  systemctl stop corosync
   60  systemctl start corosync
   61  systemctl start dlm
   62  journalctl -xeu dlm.service
   63  lsblk
   64  systemctl start dlm
   65  journalctl -xeu dlm.service
   66  systemctl start lvmlockd
   67  history
