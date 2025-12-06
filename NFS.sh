#!/bin/bash

# Cambiamos el nombre del host del servidor a "AntonioNFS" para identificarlo fácilmente.
sudo hostnamectl set-hostname AntonioNFS

# Actualizamos la lista de paquetes disponibles.
sudo apt update

# Instalamos el servidor NFS, que permitirá compartir carpetas con los servidores web.
sudo apt install nfs-kernel-server -y

# Creamos el directorio que queremos compartir a través de NFS.
sudo mkdir -p /var/nfs/general

# Cambiamos el propietario del directorio a 'nobody:nogroup',
# para que NFS maneje permisos de manera segura para clientes anónimos.
sudo chown nobody:nogroup /var/nfs/general

# Añadimos los servidores web como clientes permitidos en NFS
# y configuramos opciones:
# - rw: lectura y escritura
# - sync: operaciones sincrónicas
# - no_subtree_check: mejora rendimiento evitando comprobación de subdirectorios
echo "/var/nfs/general 10.0.2.99(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
echo "/var/nfs/general 10.0.2.104(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports

# Instalamos 'unzip' para descomprimir archivos.
sudo apt install unzip -y

# Descargamos la última versión de WordPress en el directorio compartido.
sudo wget -O /var/nfs/general/latest.zip https://wordpress.org/latest.zip

# Descomprimimos WordPress en el directorio NFS.
sudo unzip /var/nfs/general/latest.zip -d /var/nfs/general/

# Cambiamos el propietario de los archivos de WordPress a 'www-data' para Apache.
sudo chown -R www-data:www-data /var/nfs/general/wordpress

# Establecemos permisos estándar:
# - Carpetas: 755 (lectura y ejecución para todos, escritura solo para propietario)
# - Archivos: 644 (lectura para todos, escritura solo para propietario)
sudo find /var/nfs/general/wordpress/ -type d -exec chmod 755 {} \;
sudo find /var/nfs/general/wordpress/ -type f -exec chmod 644 {} \;

# Reiniciamos el servidor NFS para aplicar los cambios.
sudo systemctl restart nfs-kernel-server

# Exportamos todas las configuraciones de NFS definidas en /etc/exports.
sudo exportfs -a
