ARG base_image=index.docker.io/paketobuildpacks/ubuntu-noble-run:0.0.31
FROM ${base_image}

ARG user_id=1000
ARG group_id=1000

LABEL maintainer="Swiss Data Science Center <info@datascience.ch>"
LABEL io.buildpacks.rebasable=false
LABEL org.opencontainers.image.source="https://github.com/SwissDataScienceCenter/renku-frontend-buildpacks"
LABEL org.opencontainers.image.description="Base image for Renku sessions built with buildpacks"

USER root

RUN usermod -s /bin/bash $(id -nu $(user_id))

SHELL [ "/bin/bash", "-c", "-o", "pipefail" ]

# Install additional dependencies and nice-to-have packages
RUN apt-get update && apt-get install -yq --no-install-recommends \
    build-essential \
    wget \
    curl \
    git \
    gnupg \
    graphviz \
    jq \
    less \
    libsm6 \
    libxext-dev \
    libxrender1 \
    libyaml-0-2 \
    libyaml-dev \
    lmodern \
    nano \
    netcat-traditional \
    rclone \
    unzip \
    tmux \
    vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    wget -q https://github.com/git-lfs/git-lfs/releases/download/v3.3.0/git-lfs-linux-"$(dpkg --print-architecture)"-v3.3.0.tar.gz -P /tmp && \
    wget -q  https://github.com/justjanne/powerline-go/releases/download/v1.24/powerline-go-linux-"$(dpkg --print-architecture)" -O /usr/local/bin/powerline-shell && \
    chmod a+x /usr/local/bin/powerline-shell && \
    tar -zxvf /tmp/git-lfs-linux-"$(dpkg --print-architecture)"-v3.3.0.tar.gz -C /tmp && \
    /tmp/git-lfs-3.3.0/install.sh && \
    rm -rf /tmp/git-lfs* && \
    (userdel $(getent passwd ${user_id}|cut -d: -f1) || true) && \
    groupadd -f --gid ${group_id} renku && \
    useradd --gid ${group_id} --uid ${user_id} --create-home renku && \
    chsh -s /bin/bash renku

# Add the start_tunnel script
COPY bin/start_tunnel.sh /usr/local/bin/start_tunnel

USER $user_id
WORKDIR /home/renku

COPY .bashrc /etc/skel
RUN cp /etc/skel/.bashrc $HOME/
