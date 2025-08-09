# Start from an official Drupal image.
FROM drupal:11.2.2-apache-bookworm

# Set the working directory to the Drupal root
WORKDIR /opt/drupal

# Run the composer commands to add security modules.
RUN composer require \
    'drupal/password_policy:^4.0' \
    'drupal/seckit:^2.0' \
    'drupal/login_security:^2.0' \
    'drupal/samlauth:^3.11'