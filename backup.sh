#-----------------
# Writer : Mico Cheng
# Version: 2005100701
# use for : backup var & etc to EMC Storage (200g_1)
#-----------------
#!/usr/bin/bash

/usr/local/bin/tar zcvBpf /export/home/backup/db01-etc-`date +%Y%m%d`.tar.gz /etc >> /export/home/backup/a.txt 2>&1
/usr/local/etc/mysql/bin/mysqldump -u root -p4jc2Dsbc mail_db > /export/home/backup/db01-mysqldump-`date +%Y%m%d`.sql
/usr/local/bin/tar zcvBpf /export/home/backup/db01-mysqldump-`date +%Y%m%d`.tar.gz /export/home/backup/db01-mysqldump-`date +%Y%m%d`.sql  >> /export/home/backup/a.txt 2>&1

/usr/bin/chmod 600 /export/home/backup/db01-* >> /export/home/backup/a.txt 2>&1
/usr/local/bin/scp /export/home/backup/db01-etc-`date +%Y%m%d`.tar.gz backup_acc@210.200.211.17:/backup/etc  >> /export/home/backup/a.txt 2>&1
/usr/local/bin/scp /export/home/backup/db01-mysqldump-`date +%Y%m%d`.tar.gz backup_acc@210.200.211.17:/backup/db >> /export/home/backup/a.txt 2>&1
/usr/bin/rm /export/home/backup/*
