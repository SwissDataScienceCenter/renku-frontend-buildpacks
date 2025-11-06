ARG base_image=index.docker.io/paketobuildpacks/ubuntu-noble-run:0.0.38
FROM ${base_image}

ARG cnb_run_uid=1000
ARG cnb_run_gid=1000
ARG cnb_build_uid=1001
ARG cnb_build_gid=1001

LABEL maintainer="Swiss Data Science Center <info@datascience.ch>"
LABEL io.buildpacks.rebasable=false
LABEL org.opencontainers.image.source="https://github.com/SwissDataScienceCenter/renku-frontend-buildpacks"
LABEL org.opencontainers.image.description="Base image for Renku sessions built with buildpacks"

USER root


SHELL [ "/bin/bash", "-c", "-o", "pipefail" ]

# Install additional dependencies and nice-to-have packages
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && apt-get install -yq --no-install-recommends \
    build-essential \
    curl \
    gdb \
    git \
    gnupg \
    graphviz \
    inetutils-inetd \
    jq \
    lcov \
    less \
    libbz2-dev \
    libffi-dev \
    libgdbm-compat-dev \
    libgdbm-dev \
    liblzma-dev \
    libmpdec-dev \
    libncurses5-dev \
    libreadline6-dev \
    libsm6 \
    libsqlite3-dev \
    libssl-dev \
    libxext-dev \
    libxrender1 \
    libyaml-0-2 \
    libyaml-dev \
    libzstd-dev \
    lmodern \
    lzma \
    lzma-dev \
    nano \
    netcat-traditional \
    openssl \
    pkg-config \
    rclone \
    tini \
    tk-dev \
    tmux \
    unzip \
    uuid-dev \
    wget \
    zlib1g-dev \
    vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    wget -q https://github.com/git-lfs/git-lfs/releases/download/v3.3.0/git-lfs-linux-"$(dpkg --print-architecture)"-v3.3.0.tar.gz -P /tmp && \
    wget -q  https://github.com/justjanne/powerline-go/releases/download/v1.24/powerline-go-linux-"$(dpkg --print-architecture)" -O /usr/local/bin/powerline-shell && \
    chmod a+x /usr/local/bin/powerline-shell && \
    tar -zxvf /tmp/git-lfs-linux-"$(dpkg --print-architecture)"-v3.3.0.tar.gz -C /tmp && \
    /tmp/git-lfs-3.3.0/install.sh && \
    rm -rf /tmp/git-lfs* && \
    (userdel $(getent passwd ${cnb_run_uid}|cut -d: -f1) || true) && \
    (groupdel $(getent group ${cnb_run_uid}|cut -d: -f1) || true) && \
    (groupdel $(getent group ${cnb_build_uid}|cut -d: -f1) || true) && \
    groupadd -f --gid ${cnb_build_gid} renku_build && \
    useradd --gid ${cnb_build_gid} --uid ${cnb_build_uid} renku_build && \
    groupadd -f --gid ${cnb_run_gid} renku && \
    useradd --gid ${cnb_run_gid} --uid ${cnb_run_uid} -s /bin/bash --create-home renku && \
    usermod -aG renku_build renku && \
    chsh -s /bin/bash renku

# Add the start_tunnel script
COPY bin/start_tunnel.sh /usr/local/bin/start_tunnel

COPY .bashrc /etc/skel

FROM base AS run

ENV CNB_USER_ID=${cnb_run_uid}
ENV CNB_GROUP_ID=${cnb_run_gid}
USER $cnb_run_uid

WORKDIR /home/renku
RUN cp /etc/skel/.bashrc $HOME/

FROM base AS build

ENV CNB_USER_ID=${cnb_build_uid}
ENV CNB_GROUP_ID=${cnb_build_gid}
USER $cnb_build_uid
