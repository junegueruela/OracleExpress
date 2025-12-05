#!/bin/bash
set -e

echo "Esperando a que la base de datos esté lista..."
sleep 30

DUMP_FILE="/opt/oracle/dumps/dump.dmp"
## Comprueba que está el archivo dump antes de intentar importarlo
if [ ! -f "$DUMP_FILE" ]; then
    echo "ADVERTENCIA: No se encuentra el archivo $DUMP_FILE"
    exit 0
fi

echo "Iniciando importación del dump..."

export ORACLE_SID=XE
export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
export PATH=$ORACLE_HOME/bin:$PATH

#Me conecto a mi pdb y creo el directorio de oracle para data pump
sqlplus -s sys/${ORACLE_PWD}@//localhost:1521/XEPDB1 as sysdba <<EOF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

CREATE OR REPLACE DIRECTORY DUMP_DIR AS '/opt/oracle/dumps';
GRANT READ, WRITE ON DIRECTORY DUMP_DIR TO SYSTEM;

EXIT;
EOF

echo "Directorio de Data Pump configurado"
# Comienza el proceso de importación. Se pueden ignorar fallos derivados de roles o usuarios inexistentes a los que
# se les intenta otorgar permisos. También puede dar fallos en vistas o PL/SQL que hagan referencia a objetos que no existen,
# sobre todo si son de otros esquemas que no se han importado.
# Usar ${ORACLE_PWD} también aquí
echo "Importando dump con remap de tablespaces..."
## En remap tablespaces
impdp system/${ORACLE_PWD}@//localhost:1521/XEPDB1 \
  directory=DUMP_DIR \
  dumpfile=dump.dmp \
  logfile=importacion_$(date +%Y%m%d_%H%M%S).log \
  remap_tablespace=DATA:USERS \
  # Añadir tantos rempaps como tablespaces distintas existan con objetos del dump
  # remap_tablespace=IDATA:USERS \  
  TRANSFORM=SEGMENT_ATTRIBUTES:N \
  table_exists_action=REPLACE

if [ $? -eq 0 ]; then
    echo "Importación completada exitosamente"
else
    echo "Error en la importación. Revisa el log en /opt/oracle/dumps/"
    exit 1
fi
