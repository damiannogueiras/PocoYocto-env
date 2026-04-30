FROM ubuntu:22.04

# 1. Configuración de zona horaria y entorno no interactivo
ENV TZ=Europe/Madrid
ARG DEBIAN_FRONTEND=noninteractive
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 2. Instalación de dependencias (Combinadas para optimizar espacio)
# Se añaden dependencias específicas para el BSP de NXP y Yocto Scarthgap
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    software-properties-common \
    && add-apt-repository -y universe \
    && apt-get update && apt-get install -y --no-install-recommends \
    gawk wget git diffstat texinfo gcc build-essential chrpath socat cpio \
    unzip xz-utils debianutils iputils-ping xterm sudo \
    libsdl1.2-dev locales node-fs.realpath tzdata file lz4 zstd liblz4-tool \
    emacs-nox nano net-tools curl openssh-server \
    libacl1 python3 python3-pexpect python3-pip python3-git python3-jinja2 \
    python3-subunit efitools python3-distutils libssl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Configuración de SSH (Útil para depuración remota)
RUN mkdir /var/run/sshd && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'PermitRootLogin no' >> /etc/ssh/sshd_config

# 4. Configuración de Locales (Mandatorio para Yocto)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# 5. Configuración de Usuario (Ajustado para evitar problemas de permisos en Host)
ARG YOCTO_PASS=yocto
ARG HOST_UID=1000
RUN useradd -m -s /bin/bash -u ${HOST_UID} pocoyoctouser && \
    echo "pocoyoctouser:${YOCTO_PASS}" | chpasswd && \
    adduser pocoyoctouser sudo && \
    echo "pocoyoctouser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/pocoyoctouser && \
    chmod 0440 /etc/sudoers.d/pocoyoctouser

# 6. Preparación del entorno de trabajo
USER pocoyoctouser
WORKDIR /home/pocoyoctouser
RUN mkdir -p /home/pocoyoctouser/bin /home/pocoyoctouser/.pocoyocto-cache

# 7. Instalación de 'repo' y configuración de PATH
RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /home/pocoyoctouser/bin/repo && \
    chmod a+x /home/pocoyoctouser/bin/repo
ENV PATH="/home/pocoyoctouser/bin:${PATH}"

# 8. Descarga de Poky (Scarthgap) y Requerimientos de Toaster
RUN git clone git://git.yoctoproject.org/poky -b scarthgap --depth 1
RUN pip3 install --no-cache-dir -r /home/pocoyoctouser/poky/bitbake/toaster-requirements.txt

EXPOSE 22

# Nota: El i.MX95 requiere el uso de 'repo' con el manifiesto oficial de NXP 
# más adelante, pero tener Poky aquí ayuda con las dependencias iniciales.
CMD ["sudo", "/usr/sbin/sshd", "-D"]