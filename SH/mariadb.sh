#!/bin/bash

# Cambiamos el nombre del host del servidor a "AntonioBaseDeDatos" para identificarlo fácilmente.
sudo hostnamectl set-hostname AntonioBaseDeDatos

# Actualizamos la lista de paquetes disponibles.
sudo apt update

# Instalamos MariaDB Server y el cliente, que serán usados para la base de datos de WordPress.
sudo apt install mariadb-server mariadb-client -y

# Creamos la base de datos llamada "wordpress" con codificación UTF-8,
# adecuada para soportar todos los caracteres y acentos.
sudo mariadb -e "CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"

# Creamos un usuario llamado 'Antonio' para el servidor Web1 (IP 10.0.2.99)
# y le asignamos contraseña '123456'.
sudo mariadb -e "CREATE USER 'Antonio'@'10.0.2.99' IDENTIFIED BY '123456';"

# Concedemos todos los privilegios sobre la base de datos 'wordpress' al usuario creado.
sudo mariadb -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'Antonio'@'10.0.2.99';"

# Creamos un usuario para el servidor Web2 (IP 10.0.2.104) con los mismos permisos.
sudo mariadb -e "CREATE USER 'Antonio'@'10.0.2.104' IDENTIFIED BY '123456';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'Antonio'@'10.0.2.104';"

# Aplicamos los cambios de privilegios para que se hagan efectivos inmediatamente.
sudo mariadb -e "FLUSH PRIVILEGES;"

# Configuramos MariaDB para aceptar conexiones remotas
# cambiando la dirección de enlace a 0.0.0.0 (acepta conexiones desde cualquier IP).
sudo sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

# Reiniciamos el servicio MariaDB para aplicar los cambios de configuración.
sudo systemctl restart mariadb
