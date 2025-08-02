# =============================================================================
# Imagem de Desenvolvimento BotCity com Python 3.11
# =============================================================================
# Baseada na imagem oficial botcity-python-desktop com melhorias para 
# desenvolvimento, incluindo SSH, VNC e Chrome/ChromeDriver
# =============================================================================

FROM botcity/botcity-python-desktop

# Metadados da imagem
LABEL maintainer="Vinicius Batista viniciusfranciscob@hotmail.com.br"
LABEL description="Ambiente de desenvolvimento BotCity com Python 3.11, SSH e VNC"
LABEL version="1.0"

# =============================================================================
# VARIÁVEIS DE AMBIENTE
# =============================================================================
ENV USER=root
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Sao_Paulo
ENV CHROME_DIR=/opt/chrome
ENV CHROMEDRIVER_DIR=/opt/chromedriver
ENV NO_AT_BRIDGE=1

# Portas de serviços
ENV VNC_PORT=5910
ENV SSH_PORT=2222

# Senhas (serão sobrescritas via docker-compose)
ENV ROOT_PASSWORD=defaultpassword
ENV VNC_PASSWORD=vncpassword

# URLs dos binários
ENV CHROME_URL=https://storage.googleapis.com/chrome-for-testing-public/130.0.6723.91/linux64/chrome-linux64.zip
ENV CHROMEDRIVER_URL=https://storage.googleapis.com/chrome-for-testing-public/130.0.6723.91/linux64/chromedriver-linux64.zip

# =============================================================================
# INSTALAÇÃO DE DEPENDÊNCIAS DO SISTEMA
# =============================================================================
RUN apt-get update && apt-get install -y \
    # Ferramentas essenciais
    wget \
    curl \
    sudo \
    git \
    unzip \
    build-essential \
    gnupg \
    # Dependências Python
    libncursesw5-dev \
    libssl-dev \
    libsqlite3-dev \
    libgconf-2-4 \
    libpq-dev \
    tk-dev \
    libgdbm-dev \
    libc6-dev \
    libbz2-dev \
    libffi-dev \
    zlib1g-dev \
    # Interface gráfica e VNC
    xfce4 \
    xfce4-goodies \
    tightvncserver \
    dbus-x11 \
    xfonts-base \
    autocutsel \
    # SSH e desenvolvimento
    openssh-server \
    # Banco de dados
    unixodbc \
    unixodbc-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# =============================================================================
# CONFIGURAÇÃO DE TIMEZONE
# =============================================================================
RUN ln -sf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata

# =============================================================================
# INSTALAÇÃO DO PYTHON 3.11
# =============================================================================
RUN wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tgz \
    && tar -xf Python-3.11.0.tgz \
    && cd Python-3.11.0 \
    && ./configure --enable-optimizations \
    && make -j$(nproc) \
    && make altinstall \
    && cd .. \
    && rm -rf Python-3.11.0 Python-3.11.0.tgz \
    && ln -sf /usr/local/bin/python3.11 /usr/bin/python3 \
    && ln -sf /usr/local/bin/pip3.11 /usr/bin/pip3 \
    && ln -sf /usr/local/bin/pip3.11 /usr/bin/pip

# =============================================================================
# CONFIGURAÇÃO DO SSH SERVER
# =============================================================================
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config \
    && echo 'UseDNS no' >> /etc/ssh/sshd_config

# =============================================================================
# CONFIGURAÇÃO DO VNC
# =============================================================================
RUN mkdir -p /root/.vnc \
    && touch /root/.Xauthority

# =============================================================================
# INSTALAÇÃO E CONFIGURAÇÃO DO CHROME + CHROMEDRIVER
# =============================================================================
# Download e instalação do Chrome
RUN mkdir -p $CHROME_DIR \
    && wget -O /tmp/chrome-linux64.zip $CHROME_URL \
    && unzip /tmp/chrome-linux64.zip -d $CHROME_DIR \
    && ln -s $CHROME_DIR/chrome-linux64/chrome /usr/local/bin/google-chrome \
    && rm /tmp/chrome-linux64.zip

# Download e instalação do ChromeDriver
RUN mkdir -p $CHROMEDRIVER_DIR \
    && wget -O /tmp/chromedriver-linux64.zip $CHROMEDRIVER_URL \
    && unzip /tmp/chromedriver-linux64.zip -d $CHROMEDRIVER_DIR \
    && chmod +x $CHROMEDRIVER_DIR/chromedriver-linux64/chromedriver \
    && ln -s $CHROMEDRIVER_DIR/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver \
    && rm /tmp/chromedriver-linux64.zip


# Adicionar ao PATH
ENV PATH="$CHROMEDRIVER_DIR:$PATH:/usr/local/bin"

# =============================================================================
# CONFIGURAÇÃO DE PERMISSÕES
# =============================================================================
RUN find /usr -name geckodriver 2>/dev/null | xargs -r chmod +x

# =============================================================================
# CÓPIA E CONFIGURAÇÃO DO WRAPPER
# =============================================================================
COPY botcity/wrapper.sh /botcity/wrapper.sh
RUN chmod +x /botcity/wrapper.sh

# =============================================================================
# EXPOSIÇÃO DE PORTAS
# =============================================================================
EXPOSE $VNC_PORT $SSH_PORT

# =============================================================================
# PONTO DE ENTRADA E COMANDO PADRÃO
# =============================================================================
ENTRYPOINT ["/botcity/wrapper.sh"]
CMD ["/bin/bash"]