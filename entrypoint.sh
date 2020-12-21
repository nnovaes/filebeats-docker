#!/bin/sh
#exec /sbin/setuser filebeat ${FILEBEAT_HOME}/filebeat >> /proc/1/fd/1 &
exec ${FILEBEAT_HOME}/filebeat --path.config $FILEBEAT_HOME