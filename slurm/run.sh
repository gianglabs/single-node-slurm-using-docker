#!/bin/bash
set -e

# Enable unprivileged user namespaces required by Singularity
sysctl -w kernel.unprivileged_userns_clone=1 || true

# Configure SLURM
cpus=${1:-2}
memory=${2:-2048}
offset=${3:-0}

sshd_port=$((2222 + offset))
slurmctld_port=$((6917 + offset))
slurmd_port=$((6918 + offset))
slurmdbd_port=$((6919 + offset))
mysql_port=$((3307 + offset))

sed -e "s/<<CPUS>>/$cpus/g" \
    -e "s/<<MEMORY>>/$memory/g" \
    -e "s/<<SLURMCTLD_PORT>>/$slurmctld_port/g" \
    -e "s/<<SLURMD_PORT>>/$slurmd_port/g" \
    -e "s/<<SLURMDBD_PORT>>/$slurmdbd_port/g" \
    /etc/slurm/slurm.conf.template > /etc/slurm/slurm.conf
cat /etc/slurm/slurm.conf |grep NodeName

sed -e "s/<<DBD_PORT>>/$slurmdbd_port/g" \
    -e "s/<<STORAGE_PORT>>/$mysql_port/g" \
    /etc/slurm/slurmdbd.conf.template > /etc/slurm/slurmdbd.conf
chmod 600 /etc/slurm/slurmdbd.conf && chown slurm:slurm /etc/slurm/slurmdbd.conf

sed -e "s/<<MYSQL_PORT>>/$mysql_port/g" \
    /etc/mysql/my.cnf.template > /etc/mysql/my.cnf

# Start required services
# slurmdbd
service mariadb start
mysql -e "CREATE DATABASE IF NOT EXISTS slurm_acct_db;" && \
mysql -e "CREATE USER IF NOT EXISTS 'slurm'@'localhost' IDENTIFIED BY 'slurm';" && \
mysql -e "GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'localhost';" && \
mysql -e "FLUSH PRIVILEGES;"
service slurmdbd start
# slurmcltd
/etc/init.d/munge start
service slurmctld start
# ssh (on port 2222 + offset to avoid clashing with host sshd)
/usr/sbin/sshd -p $sshd_port
# Wait for services to stabilize
sleep 10
# Configure SLURM accounts
sacctmgr -i add cluster localcluster
sacctmgr -i --quiet add account river Cluster=localcluster
sacctmgr -i --quiet add user river account=river DefaultAccount=root
service slurmdbd restart
service slurmctld restart
slurmd -D
