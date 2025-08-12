FROM php:8.3-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    libicu-dev \
    zip \
    unzip \
    nodejs \
    npm \
    libzip-dev \
    && docker-php-ext-install pdo_pgsql pgsql mbstring exif pcntl bcmath gd zip intl

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy existing application directory contents
COPY . /var/www/html

# Copy existing application directory permissions
COPY --chown=www-data:www-data . /var/www/html

# Fix git ownership issue and allow composer superuser
RUN git config --global --add safe.directory /var/www/html
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install PHP dependencies  
RUN composer install --optimize-autoloader --no-dev --no-scripts

# Generate optimized autoload without running post-scripts
RUN composer dump-autoload --optimize --no-scripts

# Install Node dependencies and build assets
RUN npm install && npm run build

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Configure Apache
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Update Apache configuration to point to Laravel public directory
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage

EXPOSE 8080

# Create startup script
RUN echo '#!/bin/bash' > /usr/local/bin/start.sh && \
    echo 'php artisan migrate --force || true' >> /usr/local/bin/start.sh && \
    echo 'exec apache2-foreground' >> /usr/local/bin/start.sh && \
    chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
