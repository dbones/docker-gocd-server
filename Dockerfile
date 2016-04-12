FROM travix/base-debian-git-jre8:latest

MAINTAINER Travix

# build time environment variables
ENV GO_VERSION=16.3.0-3183 \
    USER_NAME=go \
    USER_ID=999 \
    GROUP_NAME=go \
    GROUP_ID=999

# install go server
RUN groupadd -r -g $GROUP_ID $GROUP_NAME \
    && useradd -r -g $GROUP_NAME -u $USER_ID -d /var/go $USER_NAME \
    && curl -fSL "https://download.go.cd/binaries/$GO_VERSION/deb/go-server-$GO_VERSION.deb" -o go-server.deb \
    && dpkg -i go-server.deb \
    && rm -rf go-server.db \
    && sed -i -e "s/DAEMON=Y/DAEMON=N/" /etc/default/go-server

# runtime environment variables
ENV AGENT_KEY="" \
    GC_LOG="" \
    JVM_DEBUG="" \
    SERVER_MAX_MEM=1024m \
    SERVER_MAX_PERM_GEN=256m \
    SERVER_MEM=512m \
    SERVER_MIN_PERM_GEN=128m

# expose ports
EXPOSE 8153 8154

# define default command
CMD groupmod -g ${GROUP_ID} ${GROUP_NAME}; \
    usermod -g ${GROUP_ID} -u ${USER_ID} ${USER_NAME}; \
    chown ${USER_NAME}:${GROUP_NAME} /var/lib/go-server /var/lib/go-server/artifacts /var/lib/go-server/db; \
    chown -R ${USER_NAME}:${GROUP_NAME} /var/lib/go-server/plugins /var/log/go-server /etc/go; \
    (/bin/su - ${USER_NAME} -c "GC_LOG=$GC_LOG JVM_DEBUG=$JVM_DEBUG SERVER_MEM=$SERVER_MEM SERVER_MAX_MEM=$SERVER_MAX_MEM SERVER_MIN_PERM_GEN=$SERVER_MIN_PERM_GEN SERVER_MAX_PERM_GEN=$SERVER_MAX_PERM_GEN /usr/share/go-server/server.sh &"); \
    until curl -s -o /dev/null 'http://localhost:8153'; \
        do sleep 1; \
    done; \
    if [ -n "$AGENT_KEY" ]; \
        then sed -i -e 's/agentAutoRegisterKey="[^"]*" *//' -e 's#\(<server\)\(.*artifactsdir.*\)#\1 agentAutoRegisterKey="'$AGENT_KEY'"\2#' /etc/go/cruise-config.xml; \
    fi; \
    ps aux; \
    /bin/su - ${USER_NAME} -c "exec tail -F /var/log/go-server/*"
