FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && apt-get install -y \
    munge slurm-wlm slurm-wlm-basic-plugins slurmdbd \
    mariadb-server mariadb-client \
    build-essential vim curl wget git \
    openssh-server fuse3 fuse2fs net-tools \
    python3 python3-dev python3-pip python3-venv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user for the cluster and ssh login
RUN useradd -m -s /bin/bash river && echo "river:password" | chpasswd && \
    mkdir -p /home/river/.ssh && \
    chmod 700 /home/river/.ssh && \
    chown -R river:river /home/river/.ssh

COPY .ssh/id_rsa.pub /home/river/.ssh/authorized_keys
RUN chown -R river:river /home/river/.ssh
RUN chmod 700 /home/river/.ssh/authorized_keys

USER river
RUN curl -fsSL https://pixi.sh/install.sh | bash
RUN /home/river/.pixi/bin/pixi global install singularity
RUN rm -rf /home/river/.cache/rattler

USER root
# Setup system directories
RUN mkdir -p /run/sshd /etc/munge /var/log/munge /var/lib/munge /etc/slurm /var/spool/slurmd \
    && chown -R munge:munge /etc/munge /var/log/munge /var/lib/munge \
    && chmod 0700 /etc/munge /var/log/munge /var/lib/munge \
    && mkdir -p /var/log/slurm /var/run/mysqld /var/lib/slurm-llnl/slurmd /var/lib/slurm-llnl/slurmctld \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
    && chown -R slurm:slurm /var/lib/slurm-llnl /var/log/slurm /var/spool/slurmd

# Copy configuration templates
COPY slurm.conf.template /etc/slurm/slurm.conf.template
COPY slurmdbd.conf.template /etc/slurm/slurmdbd.conf.template
COPY my.cnf.template /etc/mysql/my.cnf.template

# Modify system user slurm
RUN usermod -s /bin/bash slurm
COPY run.sh /opt

# Expose necessary ports
EXPOSE 2222 6917 6918 6919 3307
CMD ["/opt/run.sh"]
