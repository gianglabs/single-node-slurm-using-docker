#!/bin/bash
set -e

# Enable unprivileged user namespaces required by Singularity
sysctl -w kernel.unprivileged_userns_clone=1 || true

# Configuration
ENABLE_ACCOUNTING=${ENABLE_ACCOUNTING:-true}
ENABLE_SSHD=${ENABLE_SSHD:-true}

# Configure SLURM
cpus=${1:-2}
memory=${2:-2048}
offset=${3:-0}

sshd_port=$((2222 + offset))
slurmctld_port=$((6917 + offset))
slurmd_port=$((6918 + offset))
slurmdbd_port=$((6919 + offset))
mysql_port=$((3307 + offset))

if [ "$ENABLE_ACCOUNTING" = "true" ]; then
    sed -e "s/<<CPUS>>/$cpus/g" \
        -e "s/<<MEMORY>>/$memory/g" \
        -e "s/<<SLURMCTLD_PORT>>/$slurmctld_port/g" \
        -e "s/<<SLURMD_PORT>>/$slurmd_port/g" \
        -e "s/<<SLURMDBD_PORT>>/$slurmdbd_port/g" \
        /etc/slurm/slurm.conf.template > /etc/slurm/slurm.conf
else
    sed -e "s/<<CPUS>>/$cpus/g" \
        -e "s/<<MEMORY>>/$memory/g" \
        -e "s/<<SLURMCTLD_PORT>>/$slurmctld_port/g" \
        -e "s/<<SLURMD_PORT>>/$slurmd_port/g" \
        -e "/^# ACCOUNTING/,/^JobAcctGatherFrequency/c\# ACCOUNTING (disabled)\nAccountingStorageType=accounting_storage\/none\nJobCompType=jobcomp\/none" \
        /etc/slurm/slurm.conf.template > /etc/slurm/slurm.conf
fi
cat /etc/slurm/slurm.conf |grep NodeName

# Start required services
if [ "$ENABLE_ACCOUNTING" = "true" ]; then
    sed -e "s/<<DBD_PORT>>/$slurmdbd_port/g" \
        -e "s/<<STORAGE_PORT>>/$mysql_port/g" \
        /etc/slurm/slurmdbd.conf.template > /etc/slurm/slurmdbd.conf
    chmod 600 /etc/slurm/slurmdbd.conf && chown slurm:slurm /etc/slurm/slurmdbd.conf

    sed -e "s/<<MYSQL_PORT>>/$mysql_port/g" \
        /etc/mysql/my.cnf.template > /etc/mysql/my.cnf

    # slurmdbd
    service mariadb start
    mysql -e "CREATE DATABASE IF NOT EXISTS slurm_acct_db;" && \
    mysql -e "CREATE USER IF NOT EXISTS 'slurm'@'localhost' IDENTIFIED BY 'slurm';" && \
    mysql -e "GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'localhost';" && \
    mysql -e "FLUSH PRIVILEGES;"
    service slurmdbd start
fi

# munge + slurmctld
/etc/init.d/munge start
service slurmctld start

# ssh
if [ "$ENABLE_SSHD" = "true" ]; then
    /usr/sbin/sshd -p $sshd_port
fi

# Wait for services to stabilize
sleep 10

# Configure SLURM accounts
if [ "$ENABLE_ACCOUNTING" = "true" ]; then
    sacctmgr -i add cluster localcluster
    sacctmgr -i --quiet add account river Cluster=localcluster
    sacctmgr -i --quiet add user river account=river DefaultAccount=root
    service slurmdbd restart
    service slurmctld restart
fi

slurmd -D
