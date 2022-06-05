FROM php:7.4-fpm-alpine3.13

#### PHP7 extensions ##############################
RUN apk add --update --no-cache --virtual .ext-deps \
        libjpeg-turbo-dev \
        libwebp-dev \
        libpng-dev \
        freetype-dev \
        libmcrypt-dev \
        autoconf \
        g++ \
        make \
        openssl-dev pcre-dev pcre-tools pcre \
        libmemcached zlib cyrus-sasl libmemcached-dev zlib-dev cyrus-sasl-dev \
        libzip-dev imagemagick-dev php7-pecl-imagick-dev \
        libjpeg-turbo-dev libjpeg libjpeg-turbo \
        icu-dev

RUN \
    docker-php-ext-configure pdo_mysql && \
    docker-php-ext-configure opcache && \
    docker-php-ext-configure exif && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-configure sockets && \
    docker-php-ext-configure intl && \
    docker-php-ext-install pdo_mysql opcache exif gd sockets mysqli calendar intl

RUN \
    pecl install redis && \
    pecl install mongodb && \
    pecl install memcached && \
    pecl install imagick && \
    pecl install zip && \
    pecl clear-cache && \
    docker-php-ext-enable redis.so && \
    docker-php-ext-enable mongodb.so && \
    docker-php-ext-enable memcached.so && \
    docker-php-ext-enable imagick.so && \
    docker-php-ext-enable zip.so && \
    docker-php-ext-enable intl && \
    docker-php-source delete

####  Setup OpenResty ###################
ENV OPENRESTY_VERSION 1.21.4.1
ENV OPENRESTY_PREFIX /opt/openresty
ENV NGINX_PREFIX /opt/openresty/nginx
ENV NGINX_CONF /opt/openresty/nginx/conf
ENV VAR_PREFIX /opt/openresty/nginx/var
ENV VAR_LOG_PREFIX /opt/openresty/nginx/logs

# NginX prefix is automatically set by OpenResty to $OPENRESTY_PREFIX/nginx
# look for $ngx_prefix in https://github.com/openresty/ngx_openresty/blob/master/util/configure

# Timezone
ENV TIMEZONE Asia/Bangkok
RUN echo "Install Timezone ===========>>" \
 && apk add --update tzdata \
 && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
 && echo "${TIMEZONE}" > /etc/timezone

RUN echo "==> Installing dependencies..." \
 && apk update \
 && apk add --virtual build-deps \
    make gcc musl-dev \
    pcre-dev openssl-dev zlib-dev ncurses-dev readline-dev \
    curl perl wget \
 && mkdir -p /root/ngx_openresty \
 && cd /root/ngx_openresty \
 && echo "==> Downloading OpenResty..." \
 && curl -sSL http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz | tar -zxv \
 && curl -sSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
 && cd openresty-* \
 && echo "==> Configuring OpenResty..." \
 && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
 && echo "using upto $NPROC threads" \
 && ./configure \
    --prefix=$OPENRESTY_PREFIX \
    --http-client-body-temp-path=$VAR_PREFIX/client_body_temp \
    --http-proxy-temp-path=$VAR_PREFIX/proxy_temp \
    --http-log-path=$VAR_LOG_PREFIX/access.log \
    --error-log-path=$VAR_LOG_PREFIX/error.log \
    --pid-path=$VAR_PREFIX/nginx.pid \
    --lock-path=$VAR_PREFIX/nginx.lock \
    --add-module=/root/ngx_openresty/ngx_cache_purge-2.3 \
    --with-luajit \
    --with-pcre-jit \
    --with-ipv6 \
    --with-http_stub_status_module \
    --with-http_ssl_module \
    --with-http_flv_module \
    --with-http_v2_module \
    --with-http_mp4_module \
    --with-http_sub_module \
    --with-http_stub_status_module \
    --without-http_ssi_module \
    --without-http_uwsgi_module \
    --without-http_scgi_module \
    -j${NPROC} \
 && echo "==> Building OpenResty..." \
 && make -j${NPROC} \
 && echo "==> Installing OpenResty..." \
 && make install \
 && echo "==> Finishing..." \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/nginx \
 && ln -sf $NGINX_PREFIX/sbin/nginx /usr/local/bin/openresty \
 && ln -sf $OPENRESTY_PREFIX/bin/resty /usr/local/bin/resty \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* $OPENRESTY_PREFIX/luajit/bin/lua \
 && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* /usr/local/bin/lua \
 && apk del build-deps tzdata \
 && apk update && apk upgrade \
 && apk add libpcrecpp libpcre16 libpcre32 openssl libssl1.1 pcre libgcc libstdc++ libuuid curl imagemagick ghostscript \
 && rm -rf /var/cache/apk/* \
 && rm -rf /root/ngx_openresty \
 && rm -f $NGINX_PREFIX/conf/*.default \
 && mkdir -p /var/log/nginx \
 && cd /var/tmp && wget -qO composer-setup.php https://getcomposer.org/installer \
 && php composer-setup.php --filename=composer && chmod +x composer \
 && mv -v composer /usr/local/bin/composer && rm -f composer-setup.php

WORKDIR $NGINX_CONF

ONBUILD RUN rm -rf conf/* html/*
ONBUILD COPY nginx $NGINX_PREFIX/

RUN echo '<?php if(isset($_REQUEST["printinfo"])) phpinfo();' > /var/www/html/index.php \
 && echo '?><a href=/?printinfo>see phpinfo()</a>' >> /var/www/html/index.php 
ADD  ./start.sh /start.sh
COPY ./nginx.conf ${NGINX_CONF}/nginx.conf
RUN chmod +x /start.sh

EXPOSE 80

ENTRYPOINT ["/start.sh",""]
