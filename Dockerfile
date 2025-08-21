## This sets up a Drupal Core environment with some recommended security modules.
## 
## For Drupal CMS, I used a Dockerfile in a /separate repo/ to build and push to Docker Hub.

# Start from an official Drupal image.
FROM drupal:11.2.3-apache-bookworm

# Set the working directory to the Drupal root
WORKDIR /opt/drupal

# Run the composer commands to add security and other modules.
RUN composer require \
    'drupal/password_policy:^4.0' \
    'drupal/seckit:^2.0' \
    'drupal/login_security:^2.0' \
    'drupal/samlauth:^3.11' \
    'drush/drush:^13.6.2'