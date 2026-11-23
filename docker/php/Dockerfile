FROM php:8.2-fpm-bookworm

# نصب پیش‌نیازهای سیستمی و کتابخانه‌های کامپایل
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        bcmath \
        gd \
        zip \
        exif \
    && rm -rf /var/lib/apt/lists/*

# افزودن کامپوزر از ایمیج رسمی
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html
