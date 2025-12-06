#!/bin/bash

# Cambiamos el nombre del host del servidor a "Web1Antonio" para identificarlo fácilmente.
sudo hostnamectl set-hostname Web1Antonio

# Actualizamos la lista de paquetes disponibles.
sudo apt update

# Instalamos el cliente de NFS y los módulos esenciales de PHP para WordPress:
# - apache2: servidor web
# - php y extensiones: soporte de PHP, conexión a MySQL, manipulación de imágenes, XML, llamadas HTTP, etc.
sudo apt install nfs-common apache2 php libapache2-mod-php php-mysql php-curl php-gd php-xml php-mbstring php-xmlrpc -y

# Creamos la carpeta local donde se montará el recurso NFS compartido por el servidor de archivos.
sudo mkdir -p /nfs/general

# Montamos manualmente la carpeta compartida del servidor NFS en la ruta local.
sudo mount 10.0.2.156:/var/nfs/general /nfs/general

# Automatizamos el montaje al iniciar el sistema agregando la entrada al fichero /etc/fstab.
# Opciones:
# - _netdev: espera a la red antes de montar
# - auto: monta automáticamente al inicio
# - nofail: evita que el arranque falle si no está disponible
# - noatime, nolock, intr, tcp, actimeo=1800: optimizaciones de rendimiento y tolerancia de red
echo "10.0.2.156:/var/nfs/general  /nfs/general  nfs _netdev,auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" | sudo tee -a /etc/fstab

# Configuración del VirtualHost para servir contenido desde la carpeta NFS

# Copiamos el archivo de configuración por defecto de Apache para crear uno específico de WordPress.
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/wordpress.conf

# Sobrescribimos el VirtualHost para que sirva los archivos de WordPress desde /nfs/general/wordpress.
sudo tee /etc/apache2/sites-available/wordpress.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName antonio2005c.ddns.net
    ServerAdmin webmaster@localhost
    DocumentRoot /nfs/general/wordpress/

    <Directory /nfs/general/wordpress>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>

    # Archivos de registro para errores y accesos HTTP
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Deshabilitamos el sitio por defecto de Apache para evitar conflictos.
sudo a2dissite 000-default.conf

# Habilitamos el nuevo sitio de WordPress que apunta al NFS.
sudo /usr/sbin/a2ensite wordpress.conf

# Recargamos Apache para aplicar la nueva configuración sin reiniciar todo el servicio.
sudo systemctl reload apache2
