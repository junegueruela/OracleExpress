# Creación de un contenedor Oracle 21 Express a partir de un dump.

Solución automatizada para migrar esquemas Oracle a contenedores Docker XE 21c con remap automático de tablespaces usando Data Pump. 
Esta es una solución ideal para crear entornos portables de desarrollo. Por simplicidad, todos los objetos importados se crearán en el 
tablespace USERS.

Esta solución automatiza completamente el proceso de:
-  Despliegue de Oracle XE 21c en Docker
-  Importación automática de dumps con Data Pump al crear el contenedor
-  Remap de tablespaces a USERS
-  Persistencia de datos en volúmenes locales

##  Prerequisitos

- Docker y Docker Compose instalados
- Dump Oracle generado con `expdp`
- Acceso a base de datos origen (para consultar tablespaces)
- Al menos 12GB de espacio en disco
- 2GB de RAM disponible


## Estructura del proyecto
```
oracle-docker-migration/
├── README.md
├── docker-compose.yml          # Configuración del contenedor
├── oracle-data/                # Datos de Oracle (persistencia)
├── dumps/                      # Dumps para importar
│   ├── dump.dmp               # Tu archivo dump
│   └── backup/                # Logs de importación
└── scripts/
    ├── setup/                 # Scripts de inicialización (solo primera vez)
    │   └── 01_import.sh       # Script de importación automática
    └── startup/               # Scripts que corren en cada inicio (vacío)
```

##  Configuración

### Variables de entorno (docker-compose.yml)
```yaml
environment:
  ORACLE_PWD: OraclePass123           # Contraseña para SYS, SYSTEM y PDBADMIN
  ORACLE_CHARACTERSET: AL32UTF8       # Character set de la BD
```


## 🚀 Uso rápido

### 1. Identificar tablespaces en la base de datos origen

Conecta a tu base de datos Oracle origen y ejecuta:
```sql
SELECT DISTINCT tablespace_name
FROM dba_segments
WHERE owner = '<USUARIO_A_EXPORTAR>' -- si son varios los usuarios, habrá que hacer con IN
ORDER BY tablespace_name;
```
Si no eres DBA y el volcado es de tu propio esqueme
```sql
SELECT DISTINCT tablespace_name
FROM user_segments
```
Anota los nombres de los tablespaces (ej: `DATA`, `IDATA`, etc.)

### 2. Exportar esquemas en base de datos origen con expdp.

### Copiar tu dump
```bash
cp /ruta/a/tu/<mi_dump> dumps/dump.dmp
```

### 3. Configurar tablespaces en el script

Edita `scripts/setup/01_import.sh` y ajusta la línea `remap_tablespace`:
```bash
# Reemplaza tus tablespaces del paso 1 por USERS. Añade o quita líneas de remap_tablespace según necesites
remap_tablespace=DATA:USERS \
remap_tablespace=TU_TABLESPACE_2:USERS \
remap_tablespace=TU_TABLESPACE_3:USERS \
```

### 4. Configurar permisos (solo Linux)
```bash
# Dar permisos al usuario oracle del contenedor (UID 54321)
sudo chown -R 54321:54321 oracle-data/
sudo chown -R 54321:54321 dumps/
sudo chmod -R 755 oracle-data/
sudo chmod -R 755 dumps/
```
### 5. Configurar puertos en docker-compose.yml

Edita `docker-compose.yml` y ajusta los puertos si ya están en uso en tu servidor:
```yaml
services:
  oracle21E:
    ports:
      - "1524:1521"  # Puerto para conexiones Oracle - cambiar 1524 si está ocupado
      - "5504:5500"  # Puerto para Enterprise Manager - cambiar 5504 si está ocupado
```

Verifica qué puertos están libres en tu servidor:
```bash
# Ver puertos en uso
netstat -tulpn | grep -E ':(1524|5504)' # Para linux
netstat -ano | findstr "1524 5504" # Para Windows

# Si están ocupados, elige otros puertos libres
# Por ejemplo: "1525:1521" y "5505:5500"
```

**Importante para múltiples contenedores:**
Si planeas crear varios contenedores Oracle en el mismo servidor, cada uno debe tener:
- **Nombre de contenedor difernete** en el docker-compose.yml.
- **Puertos diferentes** en el docker-compose.yml
- **Directorio diferente** para el proyecto (ya que `oracle-data/` almacena los datafiles de Oracle de cada instancia)

Ejemplo para segundo contenedor:
```bash
# Crear segundo proyecto en otro directorio
mkdir ../OracleExpress-Proyecto2
cd ../OracleExpress-Proyecto2
# Copiar archivos base
# Modificar docker-compose.yml con puertos diferentes (ej: 1525, 5505)
```

### 6. Ejecutar
```bash
# Levantar el contenedor
docker-compose up -d

# Ver logs en tiempo real
docker logs -f oracle21XE

# Esperar mensajes:
# - "DATABASE IS READY TO USE!" (~10-15 min)
# - "Importación completada exitosamente" (~5-10 min adicionales)
```

### 7. Conectar a la base de datos
```bash
# Desde línea de comandos
docker exec -it oracle21XE sqlplus system/OraclePass123@//localhost:1521/XEPDB1

# Desde herramientas externas
Host: localhost
Port: 1524
Service: XEPDB1
Usuario: system
Password: OraclePass123
```


