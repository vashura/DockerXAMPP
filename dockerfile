# Establece versión PHP por defecto y usa multi-stage build
ARG PHP_VERSION=8.2 # <-- se pude cambiar la version del php para una instalacion personalizada
FROM php:${PHP_VERSION}-apache AS builder

# Argumentos obligatorios con valores por defecto
ARG COMPOSER_VERSION=2.6                #Define la versión de Composer que se instalará.
ARG APACHE_USER=jarvis                  #Establece el nombre del usuario que ejecutará el servidor Apache.
ARG USER_ID=1000                        #Define el ID numérico del usuario (APACHE_USER)
ARG APACHE_RUN_GROUP=${APACHE_USER}     #Asigna el grupo del usuario de Apache.

LABEL maintainer="Valerio Lopez valerio.lopez @outlook.com" version="1.0" description="Imagen personalizada con PHP y Apache"

# Configuración de usuario y permisos
RUN adduser --uid ${USER_ID} --gecos 'Apache User' --disabled-password "${APACHE_USER}" && \
    chown -R "${APACHE_USER}:${APACHE_RUN_GROUP}" /var/lock/apache2 /var/run/apache2 /var/www/html

# Variables de entorno para Magento
    # Usuario para Apache
ENV APACHE_RUN_USER=${APACHE_USER} \        
    # Grupo del usuario
    APACHE_RUN_GROUP=${APACHE_RUN_GROUP} \  
    # Límite de RAM para PHP
    PHP_MEMORY_LIMIT=2G \                   
    # Tamaño máximo de uploads
    PHP_UPLOAD_MAX_FILESIZE=64M \           
    # Tiempo máximo de scripts
    PHP_MAX_EXECUTION_TIME=1800             

# Instalación de dependencias y extensiones PHP 
RUN apt-get update && apt-get install -y \
    nano \
    cron \
    gzip \
    libbz2-dev \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libsodium-dev \
    libssh2-1-dev \
    libxslt1-dev \
    libssl-dev \
    libonig-dev \
    libxml2-dev \
    lsof \
    vim \
    zip \
    jq \
    unzip \
    git \
    libzip-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configuración de extensiones PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    bcmath \
    bz2 \
    calendar \
    exif \
    gd \
    gettext \
    intl \
    mysqli \
    opcache \
    pcntl \
    pdo_mysql \
    soap \
    sockets \
    sodium \
    sysvmsg \
    sysvsem \
    sysvshm \
    xsl \
    zip \
    mbstring \
    xml && \
    pecl install redis && docker-php-ext-enable redis && \
    docker-php-source delete && \
    rm -rf /tmp/pear  # Limpia caché de PECL

# Configuración de Apache
COPY ./.apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY ./.ssl/* /etc/apache2/ssl/
RUN a2enmod ssl rewrite headers && \
    a2ensite 000-default

# Instalación simple y confiable
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');" && \
    chmod +x /usr/local/bin/composer
    

# Configuración de MailHog
RUN curl -Lo /usr/local/bin/mhsendmail https://github.com/mailhog/mhsendmail/releases/download/v0.2.0/mhsendmail_linux_amd64 && \
    chmod +x /usr/local/bin/mhsendmail

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost/ || exit 1