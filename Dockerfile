FROM php:7.4-fpm AS php-fpm-laravel
LABEL maintainer="mujahed.altahle@gmail.com"

# Installing dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    mariadb-client \
    libpng-dev \
    libonig-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    locales \
    zip \
    unzip \
    supervisor \
    git \
    gnupg\
    && \
    curl -sL https://deb.nodesource.com/setup_15.x | bash - && \
    apt-get install -y nodejs\
    jpegoptim optipng pngquant gifsicle \
    libicu-dev libzip-dev 

# Installing extensions
RUN docker-php-ext-install pdo_mysql mbstring zip exif pcntl bcmath gd curl xml intl
RUN docker-php-ext-configure intl 
RUN pecl install -o -f redis && \
    rm -rf /tmp/pear  &&\
    docker-php-ext-enable redis

# Clear cache

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

RUN npm install --global yarn

COPY conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


RUN useradd -G www-data,root -u 1000 -d /home/aknan aknan -s /bin/bash
RUN mkdir -p /home/aknan/.composer && \
    chown -R aknan: /home/aknan


COPY ./  /var/www/html/

FROM php-fpm-laravel AS compose-packaging


RUN set -ex; \
        cd /var/www/html/; \
        # Creates laravel project if doesn't exists already \
        if [ -f composer.json ]; then \
            echo "Laravel project exists"; \ 
            if [ -d vendor ]; then \
                echo "Vendor folder exists not installing composer packages."; \
            else \
                echo "Install composer packages"; \
                composer install -vv; \
            fi	 \
        else \ 
            echo "Laravel project doesn't exist, creating new ..."; \
            composer -vvv create-project laravel/laravel /var/www/html/ --prefer-dist; \
        fi 
COPY ./scripts/ /usr/local/bin/
RUN  chmod +x /usr/local/bin/entrypoint.sh

FROM compose-packaging AS node-packaging

RUN chgrp -R www-data /var/www/html/storage; \
    chgrp -R www-data /var/www/html/bootstrap/cache; \
    chown -R aknan:www-data /var/www/html

USER aknan

RUN  if [ -f /var/www/html/package.json ]; then \
        if [ -d /var/www/html/node_modules ]; then \
            echo "Node modules already installed"; \
        else \
            echo "Install node modules"; \
            yarn install --non-interactive --network-timeout 600000 ; \
        fi	\
    else \
        echo "No package.json file"; \
    fi

RUN yarn dev --non-interactive

# Changing Workdir
WORKDIR /var/www/html/
EXPOSE 9000
USER root
RUN chown -R aknan:www-data /var/www/html; \
    chmod -R 777 /var/www/html/storage; 
#debuging tools
RUN apt update ; apt install -y nano \
    curl \
    iputils-ping\
    net-tools 

RUN docker-php-ext-install fileinfo 

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["entrypoint.sh"]


# extension=bz2
# extension=gettext

