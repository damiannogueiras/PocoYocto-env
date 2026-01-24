FROM ubuntu:22.04

# Establecer la zona horaria para evitar advertencias durante la instalación de paquetes
ENV TZ=Europe/Madrid
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Evitar prompts interactivos durante la instalación
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    software-properties-common \
    && add-apt-repository -y universe \
    && apt-get update && apt-get install -y --no-install-recommends 
RUN apt install -y gawk wget git diffstat texinfo gcc build-essential chrpath socat cpio python3 python3-pip unzip xz-utils debianutils iputils-ping xterm sudo
RUN apt install -y python3-pexpect libsdl1.2-dev locales node-fs.realpath tzdata file lz4 zstd liblz4-tool
RUN apt install -y emacs-nox nano net-tools curl
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Configurar locales tienen que estar en ingles para evitar problemas con algunas herramientas de Yocto
RUN locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Crear un usuario no-root para trabajar con Yocto
ARG YOCTO_PASS
RUN useradd -m -s /bin/bash yoctouser && echo "yoctouser:${YOCTO_PASS}" | chpasswd && adduser yoctouser sudo
RUN usermod -s /bin/bash yoctouser

# Configurar sudo sin contraseña para yoctouser (más seguro que ahora)
RUN echo "yoctouser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/yoctouser && \
    chmod 0440 /etc/sudoers.d/yoctouser

# Pre-crear directorio de caché
RUN mkdir -p /home/yoctouser/.yocto-cache && \
    chown -R yoctouser:yoctouser /home/yoctouser

USER yoctouser
WORKDIR /home/yoctouser/yocto_projects

# instalamos herramienta repo utilizada documentacion de NXP
RUN mkdir -p ~/bin

# Clonar el repositorio poky
RUN git clone git://git.yoctoproject.org/poky -b scarthgap
RUN curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
RUN chmod a+x ~/bin/repo
RUN echo 'export PATH=$HOME/bin:$PATH' >> /home/yoctouser/.bashrc

# dependencias para toaster
RUN pip3 install -r /home/yoctouser/yocto_projects/poky/bitbake/toaster-requirements.txt

