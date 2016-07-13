#!/bin/bash
set -e

# set user and group
groupmod -g ${GROUP_ID} ${GROUP_NAME};
usermod -g ${GROUP_ID} -u ${USER_ID} ${USER_NAME};

# chown directories that might have been mounted as volume and thus still have root as owner
if [ -d "/var/lib/go-server" ]
then
  echo "Setting owner for /var/lib/go-server..."
  chown ${USER_NAME}:${GROUP_NAME} /var/lib/go-server
else
  echo "Directory /var/lib/go-server does not exist"
fi

if [ -d "/var/lib/go-server/artifacts" ]
then
  echo "Setting owner for /var/lib/go-server/artifacts..."
  chown ${USER_NAME}:${GROUP_NAME} /var/lib/go-server/artifacts
else
  echo "Directory /var/lib/go-server/artifacts does not exist"
fi

if [ -d "/var/lib/go-server/db" ]
then
  echo "Setting owner for /var/lib/go-server/db..."
  chown -R ${USER_NAME}:${GROUP_NAME} /var/lib/go-server/db
else
  echo "Directory /var/lib/go-server/db does not exist"
fi

if [ -d "/var/lib/go-server/plugins" ]
then
  echo "Setting owner for /var/lib/go-server/plugins..."
  chown -R ${USER_NAME}:${GROUP_NAME} /var/lib/go-server/plugins
else
  echo "Directory /var/lib/go-server/plugins does not exist"
fi

if [ -d "/var/log/go-server" ]
then
  echo "Setting owner for /var/log/go-server..."
  chown -R ${USER_NAME}:${GROUP_NAME} /var/log/go-server
else
  echo "Directory /var/log/go-server does not exist"
fi

if [ -d "/etc/go" ]
then
  echo "Setting owner for /etc/go..."
  chown -R ${USER_NAME}:${GROUP_NAME} /etc/go
else
  echo "Directory /etc/go does not exist"
fi

if [ -d "/var/go" ]
then
  echo "Setting owner for /var/go..."
  chown -R ${USER_NAME}:${GROUP_NAME} /var/go || echo "No write permissions"
else
  echo "Directory /var/go does not exist"
fi

if [ -d "/var/go/.ssh" ]
then

  # make sure ssh keys mounted from kubernetes secret have correct permissions
  echo "Setting owner for /var/go/.ssh..."
  chmod 400 /var/go/.ssh/* || echo "Could not write permissions for /var/go/.ssh/*"

  # rename ssh keys to deal with kubernetes secret name restrictions
  cd /var/go/.ssh
  for f in *-*
  do
    echo "Renaming $f to ${f//-/_}..."
    mv "$f" "${f//-/_}" || echo "No write permissions for /var/go/.ssh"
  done

  ls -latr /var/go/.ssh

else
  echo "Directory /var/go/.ssh does not exist"
fi

# start go.cd server as go user
echo "Starting go.cd server..."
(/bin/su - ${USER_NAME} -c "GC_LOG=$GC_LOG JVM_DEBUG=$JVM_DEBUG SERVER_MEM=$SERVER_MEM SERVER_MAX_MEM=$SERVER_MAX_MEM SERVER_MIN_PERM_GEN=$SERVER_MIN_PERM_GEN SERVER_MAX_PERM_GEN=$SERVER_MAX_PERM_GEN /usr/share/go-server/server.sh &")

# wait until server is up and running
echo "Waiting for go.cd server to be ready..."
until curl -s -o /dev/null 'http://localhost:8153'
do
  sleep 1
done

# set agent key in cruise-config.xml
if [ -n "$AGENT_KEY" ]
then
  echo "Setting agent key..."
  sed -i -e 's/agentAutoRegisterKey="[^"]*" *//' -e 's#\(<server\)\(.*artifactsdir.*\)#\1 agentAutoRegisterKey="'$AGENT_KEY'"\2#' /etc/go/cruise-config.xml
fi

# tail logs, to be replaced with logs that automatically go to stdout/stderr so go.cd crashing will crash the container
/bin/su - ${USER_NAME} -c "exec tail -F /var/log/go-server/*"
