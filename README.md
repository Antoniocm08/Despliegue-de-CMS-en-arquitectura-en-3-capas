# Despliegue-de-CMS-en-arquitectura-en-3-capas

# 📘 Documento Técnico: Despliegue de CMS WordPress en Alta Disponibilidad en AWS

## Índice
1. Introducción  
2. Componentes utilizados  
3. Scripts de aprovisionamiento (estructura, sin código)  
4. Creación paso a paso de la VPC y sus subredes  
   1. Creación de la VPC  
   2. Creación de subredes públicas y privadas  
   3. Configuración de tablas de enrutamiento  
   4. Configuración de Internet Gateway y NAT Gateway  
   5. Configuración de grupos de seguridad y ACLs  
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
- **ACLs de red**: control de tráfico entre subredes.  
- **Elastic IP**: IP pública fija para el balanceador.  
- **Apache**: balanceador y servidores web.  
- **NFS**: almacenamiento compartido para WordPress.  
- **MySQL/MariaDB**: base de datos del CMS.  
- **Certificados SSL**: para habilitar HTTPS.  

---

## 3. Scripts de aprovisionamiento

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

- MariaDB

- Balanceador

- NFS
  
### 4.7 Instancias creadas 
- Por ultimo voy a crear las diferentes estancias.
- Instancia de las webs

- Instancia de MariaDB

-Instancia del Balanceador

-Instancia del NFS

### 4.8 Configuración de grupos de seguridad y ACLs
- **Balanceador**: permitir tráfico HTTP/HTTPS desde Internet.  
- **Web/NFS**: permitir tráfico desde balanceador y NFS interno.  
- **DB**: permitir tráfico solo desde servidores web.  
- **ACLs**: bloquear conectividad directa entre capa 1 y capa 3.  

---

## 5. Pruebas de la infraestructura


---

## 6. Conclusión
La arquitectura propuesta garantiza:  
- **Alta disponibilidad** mediante balanceo de carga.  
- **Escalabilidad** con múltiples servidores web.  
- **Seguridad** reforzada con grupos de seguridad y ACLs.  
- **Automatización** mediante scripts de aprovisionamiento.  
- **Personalización** de WordPress con el nombre del alumno y dominio público.  

Este despliegue constituye una solución robusta y adaptable para entornos educativos y profesionales en AWS.
