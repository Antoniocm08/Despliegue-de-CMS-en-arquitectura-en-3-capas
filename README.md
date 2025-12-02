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

## 3. Scripts de aprovisionamiento (estructura, sin código)
Los scripts en **Bash** serán responsables de:  
- Configuración de hostnames (ejemplo: `BalanceadorAntonio`, `Web1Antonio`, `DBAntonio`).  
- Instalación de paquetes (Apache, NFS, MySQL/MariaDB).  
- Configuración de servicios (balanceo, exportación NFS, base de datos).  
- Personalización de WordPress con el nombre del alumno.  
- Configuración de seguridad (grupos de seguridad, permisos).  

> ⚠️ Los scripts deben incluir comentarios claros y buenas prácticas (`set -euo pipefail`).

---

## 4. Creación paso a paso de la VPC y sus subredes

### 4.1 Creación de la VPC


### 4.2 Creación de subredes públicas y privadas
 

### 4.3 Configuración de tablas de enrutamiento
 

### 4.4 Configuración de Internet Gateway y NAT Gateway
 

### 4.5 Configuración de grupos de seguridad y ACLs
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
