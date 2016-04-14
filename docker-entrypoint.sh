#!/bin/bash
set -e

# set user and group
groupmod -g ${GROUP_ID} ${GROUP_NAME};
usermod -g ${GROUP_ID} -u ${USER_ID} ${USER_NAME};

# chown directories that might have been mounted as volume and thus still have root as owner
if [ -d "/var/lib/go-server" ];
then
  chown ${USER_NAME}:${GROUP_NAME} /var/lib/go-server;
fi

if [ -d "/var/lib/go-server/artifacts" ];
then
  chown ${USER_NAME}:${GROUP_NAME} /var/lib/go-server/artifacts;
fi

if [ -d "/var/lib/go-server/db" ];
then
  chown -R ${USER_NAME}:${GROUP_NAME} /var/lib/go-server/db;
fi

if [ -d "/var/lib/go-server/plugins" ];
then
  chown -R ${USER_NAME}:${GROUP_NAME} /var/lib/go-server/plugins;
fi

if [ -d "/var/log/go-server" ];
then
  chown -R ${USER_NAME}:${GROUP_NAME} /var/log/go-server;
fi

if [ -d "/etc/go" ];
then
  chown -R ${USER_NAME}:${GROUP_NAME} /etc/go;
fi

if [ -d "/var/go/.ssh" ];
then
  chown -R ${USER_NAME}:${GROUP_NAME} /var/go/.ssh;

  # make sure ssh keys mounted from kubernetes secret have correct permissions
  chmod 400 /var/go/.ssh/*;

  # rename ssh keys to deal with kubernetes secret name restrictions
  cd /var/go/.ssh;
  for f in *-*;
    do mv "$f" "${f//-/_}";
  done;

fi

# start go.cd server as go user
(/bin/su - ${USER_NAME} -c "GC_LOG=$GC_LOG JVM_DEBUG=$JVM_DEBUG SERVER_MEM=$SERVER_MEM SERVER_MAX_MEM=$SERVER_MAX_MEM SERVER_MIN_PERM_GEN=$SERVER_MIN_PERM_GEN SERVER_MAX_PERM_GEN=$SERVER_MAX_PERM_GEN /usr/share/go-server/server.sh &")

# wait until server is up and running
until curl -s -o /dev/null 'http://localhost:8153';
    do sleep 1;
done;

# set agent key in cruise-config.xml
if [ -n "$AGENT_KEY" ]; \
    then sed -i -e 's/agentAutoRegisterKey="[^"]*" *//' -e 's#\(<server\)\(.*artifactsdir.*\)#\1 agentAutoRegisterKey="'$AGENT_KEY'"\2#' /etc/go/cruise-config.xml; \
fi; \

# tail logs, to be replaced with logs that automatically go to stdout/stderr so go.cd crashing will crash the container
/bin/su - ${USER_NAME} -c "exec tail -F /var/log/go-server/*";
