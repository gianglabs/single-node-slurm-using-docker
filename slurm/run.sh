#!/bin/bash
set -e

# Enable unprivileged user namespaces required by Singularity
sysctl -w kernel.unprivileged_userns_clone=1 || true

# Configure SLURM
cpus=${1:-2} 
memory=${2:-2048}

sed -e "s/<<CPUS>>/$cpus/g" -e "s/<<MEMORY>>/$memory/g" /etc/slurm/slurm.conf.template > /etc/slurm/slurm.conf
cat /etc/slurm/slurm.conf |grep NodeName
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
# ssh
/usr/sbin/sshd
# Wait for services to stabilize
sleep 10
# Configure SLURM accounts
sacctmgr -i add cluster localcluster
sacctmgr -i --quiet add account river Cluster=localcluster
sacctmgr -i --quiet add user river account=river DefaultAccount=root
service slurmdbd restart
service slurmctld restart
slurmd -D