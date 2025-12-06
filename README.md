# 📘 Documento Técnico: Despliegue de CMS WordPress en Alta Disponibilidad en AWS  

## Índice
1. Introducción  
2. Componentes utilizados  
3. Scripts de aprovisionamiento (estructura, sin código)  
4. Creación paso a paso de la VPC y sus subredes  
   1. Creación de la VPC  
   2. Creación de subredes públicas y privadas  
   3. Creación de la red a Internet (Internet Gateway)  
   4. Creación de la puerta NAT (NAT Gateway + Elastic IP)  
   5. Configuración de tablas de enrutamiento  
   6. Creación de los grupos de seguridad  
   7. Instancias creadas (Web, MariaDB, Balanceador, NFS)  
   8. Configuración de grupos de seguridad.  
5. Pruebas de la infraestructura  
6. Conclusión  

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
-Balanceador
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
---

## 4. Creación paso a paso de la VPC y sus subredes

### 4.1 Creación de la VPC
- Lo primero es irte al apartado del VPC, despues seleciona tus VPCS y por ultimo le das a crear la VPC.


- Lo siguiente es configurar la propia VPC.

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

### 4.8 Configuración de grupos de seguridad y ACLs
- **Balanceador**: permitir tráfico HTTP/HTTPS desde Internet.  
- **Web/NFS**: permitir tráfico desde balanceador y NFS interno.  
- **DB**: permitir tráfico solo desde servidores web.  
 

---

## 5. Pruebas de la infraestructura


---

## 6. Conclusión
La arquitectura propuesta garantiza:  
- **Alta disponibilidad** mediante balanceo de carga.  
- **Escalabilidad** con múltiples servidores web.  
- **Seguridad** reforzada con grupos de seguridad.  
- **Automatización** mediante scripts de aprovisionamiento.  
- **Personalización** de WordPress con el nombre del alumno y dominio público.  

Este despliegue constituye una solución robusta y adaptable para entornos educativos y profesionales en AWS.
