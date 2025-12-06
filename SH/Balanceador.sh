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
