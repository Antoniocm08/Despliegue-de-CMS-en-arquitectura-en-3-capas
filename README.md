# 📘 Documento Técnico: Despliegue de CMS WordPress en Alta Disponibilidad en AWS  

## Índice
1. [Introducción](#1-introducción)  
2. [Componentes utilizados](#2-componentes-utilizados)  
3. [Scripts de aprovisionamiento](#3-scripts-de-aprovisionamiento)  
   3.1 [Balanceador](#31-balanceador)  
   3.2 [NFS](#32-nfs)  
   3.3 [MariaDB](#33-mariadb)  
   3.4 [Webs](#34-webs)  
4. [Creación paso a paso de la VPC y sus subredes](#4-creación-paso-a-paso-de-la-vpc-y-sus-subredes)  
   4.1 [Creación de la VPC](#41-creación-de-la-vpc)  
   4.2 [Creación de subredes públicas y privadas](#42-creación-de-subredes-públicas-y-privadas)  
   4.3 [Creación de la red a Internet (Internet Gateway)](#43-creacion-de-la-red-a-internet)  
   4.4 [Creamos la puerta NAT](#44-creamos-la-puerta-nat)  
   4.5 [Configuración de tablas de enrutamiento](#45-configuración-de-tablas-de-enrutamiento)  
   4.6 [Creacion de los grupos de seguridad](#46-creacion-de-los-grupos-de-seguridad)  
   4.7 [Instancias creadas (Web, MariaDB, Balanceador, NFS)](#47-instancias-creadas)  
   4.8 [Configuración de grupos de seguridad](#48-configuración-de-grupos-de-seguridad)  
5. [Pruebas de la infraestructura](#5-pruebas-de-la-infraestructura)  
6. [Pruebas del dominio](#6-pruebas-del-dominio)  
7. [ Instrucciones de uso](#7-instruciones-de-uso)  
8. [Conclusión](#8-conclusión)
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
### 3.1 Balanceador
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
### 3.2 NFS
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
### 3.3 MariaDB
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
### 3.4 Webs
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
- Lo siguiente que voy hacer es crear una subred publica y otras dos subredes privadas (una de ellas para la base de datos).Esto tambien se encuentra en el VPC.
<img width="1893" height="920" alt="image" src="https://github.com/user-attachments/assets/5de015d1-03d3-4d56-84c7-970a98977886" />

- Subred Publica
<img width="1877" height="906" alt="image" src="https://github.com/user-attachments/assets/d300460d-f3e2-4334-9b89-db881cbb25ac" />

- Subred Privada
<img width="1917" height="862" alt="image" src="https://github.com/user-attachments/assets/84f70736-ece4-482e-9055-8831e7f5fc91" />

- Subred Privada Base de datos
<img width="1879" height="863" alt="image" src="https://github.com/user-attachments/assets/34ded032-cd81-402e-b493-7cecdef83e7b" />

### 4.3 Creacion de la red a internet
- Voy a crear la gateway, para esto nos vamos a VPC, le damos al apartado de gateway nat y por ultimo le doy a crear gateway nat.
<img width="1906" height="697" alt="image" src="https://github.com/user-attachments/assets/d66be34e-bda5-4589-806b-b754a309cbc1" />
- Conecto la puerta de enlace internet a mi vpc.
<img width="1917" height="618" alt="Captura de pantalla 2025-12-06 162305" src="https://github.com/user-attachments/assets/2026251e-84ca-45b7-9b8b-b50e40c07a5e" />

- Lo siguiente es asociar esta gateway a nuestra VPC, para hacer esto debemos selecionar nuestra puerta de enlace darle al apartado de acciones y por ultimo conectar a VPC.
<img width="1874" height="810" alt="image" src="https://github.com/user-attachments/assets/0c3d63b4-c58c-4ec1-8038-0c38c269f4d1" />


### 4.4 Creamos la puerta NAT
- Lo primero seria crear la ip elastica que se encuentra en el EC2 y exactamente en el apartado de red y seguridad.
<img width="1917" height="801" alt="image" src="https://github.com/user-attachments/assets/b6e061c5-32fb-4ea9-bf3d-095163dd1d45" />

- Luego creamos la propia puerta NAT, que se encuentra en VPC y puerta de enlace
 <img width="1909" height="690" alt="image" src="https://github.com/user-attachments/assets/61a66759-f835-4041-87dc-410b06a42abe" />

### 4.5 Configuración de tablas de enrutamiento
- Voy a crear la ruta publica y privada para la base de datos, esto se encuentra tambien en el VPC.
  <img width="1897" height="823" alt="image" src="https://github.com/user-attachments/assets/a3b2e2a7-b4e5-4c7f-a0aa-e1b3327dd896" />

- Creacion de la ruta de enrutamiento publica
 <img width="1906" height="827" alt="image" src="https://github.com/user-attachments/assets/225dbd81-2a0c-49c3-b94e-2658f8c1cfb1" />

- Creacion de la ruta de enrutamiento privada, contiene la privada del nfs y la de base de datos.
  <img width="1890" height="836" alt="image" src="https://github.com/user-attachments/assets/51cddf86-f0a8-4f8c-81d6-baa22db6ffda" />

### 4.6 Creacion de los grupos de seguridad
- Aqui creare los diferentes grupos de seguridad para cada uno.
<img width="1888" height="902" alt="image" src="https://github.com/user-attachments/assets/1f613747-7703-41a8-9ca7-79a0846976c4" />

- Webs
- Contiene el puerto del NFS,HTTP,HTPPS y SSH, con la ip 0.0.0.0/0
<img width="1917" height="772" alt="image" src="https://github.com/user-attachments/assets/c9a851dd-ac11-426d-b8b1-c3e65d0fbfbe" />


- MariaDB(base de datos)
- Tiene el puerto ssh y mysql/aurora con su ip 10.0.2.0/24
<img width="1917" height="780" alt="image" src="https://github.com/user-attachments/assets/bdbc008a-f5ab-454c-bd35-e2c6a47e6a24" />


- Balanceador
- Contiene el puerto del HTTP,HTTPS y SSH
<img width="1912" height="790" alt="image" src="https://github.com/user-attachments/assets/f0b48438-90b3-41da-be9e-806210dd7fa2" />


- NFS
- Contiene los puertos del SSH y NFS
<img width="1911" height="731" alt="image" src="https://github.com/user-attachments/assets/8c963fa1-6aca-4b35-b3a2-89d0da441190" />


### 4.7 Instancias creadas 

- Por ultimo voy a crear las diferentes estancias., esto se encuentra en EC2.
<img width="1918" height="882" alt="image" src="https://github.com/user-attachments/assets/9dfcc592-88ed-4670-bdc6-0238bcb68dac" />

- Instancia de las webs, al crearla pones su grupo de seguridad, el nombre , el vockey.
<img width="1895" height="857" alt="image" src="https://github.com/user-attachments/assets/292de62e-ba73-410e-86a7-535999e10155" />
- Tambien lo debes vincular con tu vpc creada.
<img width="1901" height="876" alt="image" src="https://github.com/user-attachments/assets/92d067c5-a41f-44b5-bfc6-2b8ba5f2dca8" />
- Y selecionar la subred en la que pertenece.
<img width="1892" height="842" alt="image" src="https://github.com/user-attachments/assets/6cf4d007-80ac-43b6-8a81-78dfdba3d64a" />

- Instancia de MariaDB, al crearla hacemos lo mismo que en la web pero ponemos su grupo de seguridad, y la subred privada para la base de datos.
<img width="1911" height="877" alt="image" src="https://github.com/user-attachments/assets/b9854003-48fe-4129-875d-dbc89ebd0246" />

- Instancia del Balanceador, al crear aqui ponemos la subred publica y su grupo de seguridad.
<img width="1892" height="872" alt="image" src="https://github.com/user-attachments/assets/7a2c5c3d-e5e3-45a3-9edd-ed75382b28a5" />

- Instancia del NFS, al crearla ponemos su subred privada y su grupo de seguridad.
<img width="1918" height="901" alt="image" src="https://github.com/user-attachments/assets/a4da3212-794b-4fc2-87f9-675371206688" />

### 4.8 Configuración de grupos de seguridad
- **Balanceador**: permitir tráfico HTTP/HTTPS desde Internet.  
- **Web/NFS**: permitir tráfico desde balanceador y NFS interno.  
- **DB**: permitir tráfico solo desde servidores web.  
---

## 5. Pruebas de la infraestructura
- Prueba de como se inicia en el woordpress.
<img width="1792" height="956" alt="Captura de pantalla 2025-12-06 140916_BLOG_ANTONIO" src="https://github.com/user-attachments/assets/b21794c8-ebe7-4f23-8f5f-36765533da87" />

---
## 6. Pruebas del dominio
- Mi dominio es : (https://antonio2005c.ddns.net/)
  <img width="1895" height="695" alt="Captura de pantalla 2025-12-06 155935" src="https://github.com/user-attachments/assets/c9fcdf4a-f886-4186-b268-9bee4130e3fe" />

---
## 7. Instrucciones de uso

Para poder utilizar correctamente la infraestructura desplegada y acceder al CMS WordPress, sigue estos pasos:

1. **Encender las instancias en AWS**  
   - Accede al servicio **EC2** en la consola de AWS.  
   - Verifica que las instancias del **Balanceador**, **Web1**, **Web2**, **NFS** y **MariaDB** estén en estado `running`.  
   - Si alguna está detenida, selecciónala y pulsa **Start Instance**.

2. **Comprobar conectividad interna**  
   - Desde el balanceador, asegúrate de que puedes hacer ping a las IP privadas de los servidores web y al NFS.  
   - Comprueba también que los servidores web pueden conectarse a la base de datos MariaDB.

3. **Acceder al CMS WordPress**  
   - Una vez que las instancias estén encendidas y funcionando, abre un navegador web.  
   - Introduce el **dominio configurado** o la **IP pública del balanceador**.   
   - Si configuraste certificados SSL, asegúrate de usar `https://`.

4. **Instalación inicial de WordPress**  
   - Al acceder por primera vez, WordPress mostrará el asistente de instalación.  
   - Introduce los datos de conexión a la base de datos (nombre de la BD, usuario y contraseña creados en MariaDB).  
   - Configura el nombre del sitio, usuario administrador y contraseña.

5. **Acceso al panel de administración**  
   - Una vez instalado, accede al panel de administración de WordPress en:  
   - Desde ahí podrás gestionar usuarios, instalar plugins y personalizar el sitio.

---

### Nota importante
- Si cambias el dominio o la IP pública del balanceador, recuerda actualizar la configuración en Apache y en WordPress.  
 

## 8. Conclusión
La arquitectura propuesta garantiza:  
- **Alta disponibilidad** mediante balanceo de carga.  
- **Escalabilidad** con múltiples servidores web.  
- **Seguridad** reforzada con grupos de seguridad.  
- **Automatización** mediante scripts de aprovisionamiento.  
- **Personalización** de WordPress con el nombre del alumno y dominio público.  

Este despliegue constituye una solución robusta y adaptable para entornos profesionales en AWS.
