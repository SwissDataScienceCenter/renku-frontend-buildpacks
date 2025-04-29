ARG base_image=index.docker.io/paketobuildpacks/run-jammy-full:latest
FROM ${base_image}

ARG user_id=1000
ARG group_id=1000
ARG build_id=0

LABEL maintainer="Swiss Data Science Center <info@datascience.ch>"
LABEL io.buildpacks.rebasable=false

USER root

RUN usermod -s /bin/bash $(id -nu $(user_id))

SHELL [ "/bin/bash", "-c", "-o", "pipefail" ]

# Install additional dependencies and nice-to-have packages
RUN apt-get update && apt-get install -yq --no-install-recommends \
    build-essential \
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
    vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    wget -q https://github.com/git-lfs/git-lfs/releases/download/v3.3.0/git-lfs-linux-"$(dpkg --print-architecture)"-v3.3.0.tar.gz -P /tmp && \
    wget -q  https://github.com/justjanne/powerline-go/releases/download/v1.24/powerline-go-linux-"$(dpkg --print-architecture)" -O /usr/local/bin/powerline-shell && \
    chmod a+x /usr/local/bin/powerline-shell && \
    tar -zxvf /tmp/git-lfs-linux-"$(dpkg --print-architecture)"-v3.3.0.tar.gz -C /tmp && \
    /tmp/git-lfs-3.3.0/install.sh && \
    rm -rf /tmp/git-lfs* && \
    groupadd -f --gid ${group_id} renku && \
    useradd --gid ${group_id} --uid ${user_id} --create-home renku && \
    chsh -s /bin/bash renku

RUN echo $build_id

USER $user_id

COPY .bashrc /etc/skel
RUN cp /etc/skel/.bashrc $HOME/
