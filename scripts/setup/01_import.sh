#!/bin/bash
set -e

echo "Esperando a que la base de datos esté lista..."
sleep 30

DUMP_FILE="/opt/oracle/dumps/dump.dmp"

if [ ! -f "$DUMP_FILE" ]; then
    echo "ADVERTENCIA: No se encuentra el archivo $DUMP_FILE"
    exit 0
fi

echo "Iniciando importación del dump..."

export ORACLE_SID=XE
export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
export PATH=$ORACLE_HOME/bin:$PATH

#
sqlplus -s sys/${ORACLE_PWD}@//localhost:1521/XEPDB1 as sysdba <<EOF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

CREATE OR REPLACE DIRECTORY DUMP_DIR AS '/opt/oracle/dumps';
GRANT READ, WRITE ON DIRECTORY DUMP_DIR TO SYSTEM;

EXIT;
EOF

echo "Directorio de Data Pump configurado"

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
  table_exists_action=REPLACE

if [ $? -eq 0 ]; then
    echo "Importación completada exitosamente"
else
    echo "Error en la importación. Revisa el log en /opt/oracle/dumps/"
    exit 1
fi