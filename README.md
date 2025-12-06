# 📘 Documento Técnico: Despliegue de CMS WordPress en Alta Disponibilidad en AWS  

## Índice
1. [Introducción](#1-introducción)  
2. [Componentes utilizados](#2-componentes-utilizados)  
3. [Scripts de aprovisionamiento](#3-scripts-de-aprovisionamiento)
   - [Balanceador](#balanceador)  
   - [NFS](#nfs)  
   - [MariaDB](#mariadb)  
   - [Webs](#webs)
4. [Creación paso a paso de la VPC y sus subredes](#4-creación-paso-a-paso-de-la-vpc-y-sus-subredes)  
   1. [Creación de la VPC](#41-creación-de-la-vpc)  
   2. [Creación de subredes públicas y privadas](#42-creación-de-subredes-públicas-y-privadas)  
   3. [Creación de la red a Internet (Internet Gateway)](#43-creacion-de-la-red-a-internet)  
   4. [Creación de la puerta NAT (NAT Gateway + Elastic IP)](#44-creamos-la-puerta-nat)  
   5. [Configuración de tablas de enrutamiento](#45-configuración-de-tablas-de-enrutamiento)  
   6. [Creación de los grupos de seguridad](#46-creacion-de-los-grupos-de-seguridad)  
   7. [Instancias creadas (Web, MariaDB, Balanceador, NFS)](#47-instancias-creadas)  
   8. [Configuración de grupos de seguridad ](#48-configuración-de-grupos-de-seguridad)  
5. [Pruebas de la infraestructura](#5-pruebas-de-la-infraestructura)
6. [Pruebas del dominio](#6-pruebas-del-dominio)
7. [Conclusión](#7-conclusión)  

---

## 1. Introducción
Este documento describe el despliegue de un CMS **WordPress** en AWS con una arquitectura de **alta disponibilidad** y **escalabilidad**.  
El proyecto se organiza en **tres capas**:
- **Capa pública**: balanceador de carga.  
- **Capa privada A**: servidores web + NFS.  
- **Capa privada B**: servidor de base de datos.  

El objetivo es garantizar seguridad, rendimiento y automatización mediante scripts de aprovisionamiento.

---

## 2. Componentes utilizados
- **AWS VPC**: red virtual para aislar la infraestructura.  
- **Subred pública**: balanceador de carga.  
- **Subred privada A**: servidores web y NFS.  
- **Subred privada B**: servidor de base de datos.  
- **Internet Gateway**: acceso a Internet para la capa pública.  
- **NAT Gateway**: acceso controlado a Internet para servidores privados.  
- **Grupos de seguridad (SG)**: reglas de firewall a nivel de instancia.   
- **Elastic IP**: IP pública fija para el balanceador.  
- **Apache**: balanceador y servidores web.  
- **NFS**: almacenamiento compartido para WordPress.  
- **MySQL/MariaDB**: base de datos del CMS.  
- **Certificados SSL**: para habilitar HTTPS.  

---

## 3. Scripts de aprovisionamiento
### Balanceador
```
#!/bin/bash

# Cambiamos el nombre del host del servidor a "AntonioBalanceador" para identificarlo fácilmente.
sudo hostnamectl set-hostname AntonioBalanceador

# Actualizamos la lista de paquetes disponibles en el sistema.
sudo apt update

# Instalamos Apache2, el servidor web que usaremos como balanceador de carga.
sudo apt install apache2 -y

# Habilitamos los módulos necesarios de Apache:
# - proxy: permite el uso de Apache como proxy inverso.
# - proxy_http: soporte para proxy HTTP.
# - proxy_balancer: habilita balanceo de carga entre varios servidores backend.
# - lbmethod_byrequests: balancea basándose en la cantidad de solicitudes.
# - proxy_connect: permite conexiones proxy a través de HTTPS.
# - ssl: habilita soporte para SSL/TLS.
# - headers: permite manipular cabeceras HTTP.
sudo a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests proxy_connect ssl headers

# Reiniciamos Apache para que los módulos habilitados se carguen correctamente.
sudo systemctl restart apache2


# Configuración HTTP (puerto 80) para forzar redirección a HTTPS

# Creamos una copia del archivo de configuración por defecto de Apache.
sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/load-balancer.conf

# Sobrescribimos la configuración HTTP para redirigir todo el tráfico HTTP a HTTPS.
sudo tee /etc/apache2/sites-available/load-balancer.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName antonio2005c.ddns.net
    ServerAdmin webmaster@localhost

    # Redirección permanente: cualquier petición HTTP será enviada automáticamente a HTTPS
    Redirect permanent / https://antonio2005c.ddns.net/

    # Archivos de registro para errores y accesos HTTP
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF


# Configuración HTTPS (puerto 443) con terminación SSL y balanceo de carga

sudo tee /etc/apache2/sites-available/load-balancer-ssl.conf > /dev/null <<EOF
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    ServerName antonio2005c.ddns.net

    # Activamos SSL/TLS para cifrar la comunicación
    SSLEngine On
    SSLCertificateFile /etc/letsencrypt/live/antonio2005c.ddns.net/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/antonio2005c.ddns.net/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf

    # Configuración del balanceo de carga
    <Proxy balancer://mycluster>
        # Sticky sessions: mantiene al mismo usuario siempre en el mismo servidor backend
        ProxySet stickysession=JSESSIONID|ROUTEID

        # Servidores backend que recibirán el tráfico balanceado
        BalancerMember http://10.0.2.99:80 route=1
        BalancerMember http://10.0.2.104:80 route=2 
    </Proxy>

    # Redirige todas las solicitudes entrantes al grupo de balanceo definido arriba
    ProxyPass / balancer://mycluster/
    ProxyPassReverse / balancer://mycluster/

    # Archivos de registro para errores y accesos HTTPS
    ErrorLog \${APACHE_LOG_DIR}/ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/ssl_access.log combined

</VirtualHost>
</IfModule>
EOF


# Habilitamos la configuración personalizada y deshabilitamos la por defecto

# Deshabilitamos el sitio por defecto para evitar conflictos.
sudo a2dissite 000-default.conf

# Habilitamos los sitios personalizados para HTTP y HTTPS (balanceador de carga).
sudo a2ensite load-balancer.conf
sudo a2ensite load-balancer-ssl.conf

# Recargamos Apache para que todas las configuraciones nuevas se apliquen sin reiniciar todo el servicio.
sudo systemctl reload apache2

```
### NFS
```
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

```
### MariaDB
```
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

```
### Webs
```
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

```
---

## 4. Creación paso a paso de la VPC y sus subredes

### 4.1 Creación de la VPC
- Lo primero es irte al apartado del VPC, despues seleciona tus VPCS y por ultimo le das a crear la VPC.
<img width="1894" height="920" alt="Captura de pantalla 2025-12-06 161113" src="https://github.com/user-attachments/assets/a8fdb497-6dbb-4b7b-8b94-93cc5fa37cfb" />


- Lo siguiente es configurar la propia VPC
- le pones el nombre que necesites y puse esta ip 10.0.0.0/16.
<img width="1866" height="910" alt="Captura de pantalla 2025-12-06 161712" src="https://github.com/user-attachments/assets/3d5987b7-dfc5-4d0b-a4f7-f470ca0ded4e" />

<img width="1893" height="847" alt="Captura de pantalla 2025-12-06 161141_Mi_VPC" src="https://github.com/user-attachments/assets/89aa950d-c31c-460b-b620-27f4098b1137" />

### 4.2 Creación de subredes públicas y privadas
- Lo siguiente que voy hacer es crear una subred publica y otras dos subredes privadas (una de ellas para la base de datos).
- Subred Publica

- Subred Privada

- Subred Privada Base de datos

### 4.3 Creacion de la red a internet
- Voy a crear la gateway, para esto nos vamos a VPC, le damos al apartado de gateway nat y por ultimo le doy a crear gateway nat.

- Lo siguiente es asociar esta gateway a nuestra VPC, para hacer esto debemos selecionar nuestra puerta de enlace darle al apartado de acciones y por ultimo conectar a VPC.

### 4.4 Creamos la puerta NAT
- Lo primero seria crear la ip elastica que se encuentra en el EC2 y exactamente en el apartado de red y seguridad.

- Luego creamos la propia puerta NAT, que se encuentra en VPC y puerta de enlace
 
### 4.5 Configuración de tablas de enrutamiento
- Voy a crear la ruta publica y privada para la base de datos.
- Creacion de la ruta de enrutamiento publica
 
- Creacion de la ruta de enrutamiento privada
  
### 4.6 Creacion de los grupos de seguridad
- Aqui creare los diferentes grupos de seguridad para cada uno.

- Webs
<img width="1919" height="833" alt="Webs" src="https://github.com/user-attachments/assets/12566aa5-40b7-48da-ae42-218f8049e888" />

- MariaDB
<img width="1919" height="843" alt="Base de datos" src="https://github.com/user-attachments/assets/8001a9ff-549e-4119-b01d-2d11b9c8c35f" />

- Balanceador
  
<img width="1918" height="830" alt="Balanceador" src="https://github.com/user-attachments/assets/c570b3cf-0383-42c5-9c8c-265e97ab8396" />

- NFS
<img width="1919" height="852" alt="nfs" src="https://github.com/user-attachments/assets/8983e419-10c3-4e33-9074-4f56ce67ab28" />

### 4.7 Instancias creadas 

- Por ultimo voy a crear las diferentes estancias.
  
- Instancia de las webs

- Instancia de MariaDB

- Instancia del Balanceador

- Instancia del NFS

### 4.8 Configuración de grupos de seguridad
- **Balanceador**: permitir tráfico HTTP/HTTPS desde Internet.  
- **Web/NFS**: permitir tráfico desde balanceador y NFS interno.  
- **DB**: permitir tráfico solo desde servidores web.  
---

## 5. Pruebas de la infraestructura

<img width="1792" height="956" alt="Captura de pantalla 2025-12-06 140916_BLOG_ANTONIO" src="https://github.com/user-attachments/assets/b21794c8-ebe7-4f23-8f5f-36765533da87" />

---
## 6. Pruebas del dominio
- Mi dominio es : (https://antonio2005c.ddns.net/)
  <img width="1895" height="695" alt="Captura de pantalla 2025-12-06 155935" src="https://github.com/user-attachments/assets/c9fcdf4a-f886-4186-b268-9bee4130e3fe" />

---
## 7. Conclusión
La arquitectura propuesta garantiza:  
- **Alta disponibilidad** mediante balanceo de carga.  
- **Escalabilidad** con múltiples servidores web.  
- **Seguridad** reforzada con grupos de seguridad.  
- **Automatización** mediante scripts de aprovisionamiento.  
- **Personalización** de WordPress con el nombre del alumno y dominio público.  

Este despliegue constituye una solución robusta y adaptable para entornos profesionales en AWS.
