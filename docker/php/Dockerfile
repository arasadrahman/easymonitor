FROM php:8.4-fpm-alpine

# Runtime dependencies stay small; compilers and headers are removed afterward.
RUN apk add --no-cache \
      shadow bash postgresql-client redis nodejs npm iputils fcgi \
 && apk add --no-cache --virtual .build-deps \
      $PHPIZE_DEPS linux-headers postgresql-dev \
 && docker-php-ext-install -j$(nproc) \
      pdo_pgsql pgsql opcache sockets bcmath pcntl \
 && pecl install redis \
 && docker-php-ext-enable redis \
 && apk del .build-deps

# ––––– Composer –––––
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer

# Match www-data to the deployment host's application UID/GID.
ARG PUID=1000
ARG PGID=1000
RUN groupmod -o -g "${PGID}" www-data \
 && usermod  -o -u "${PUID}" -g "${PGID}" www-data

# ––––– Set working directory –––––
WORKDIR /var/www/html

# ––––– Entrypoint: ensure writable dirs on every start –––––
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/php-fpm-healthcheck
COPY health.conf /usr/local/etc/php-fpm.d/zz-health.conf
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/php-fpm-healthcheck

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
