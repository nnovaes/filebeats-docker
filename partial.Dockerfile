FROM phusion/baseimage:bionic-1.0.0
 
# Use baseimage-docker's init system.
#CMD ["/sbin/my_init"]
 
# Upgrade the OS
RUN apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confold"
 
# Give children processes 60 seconds to timeout
ENV KILL_PROCESS_TIMEOUT=60
# Give all other processes (such as those which have been forked) 60 seconds to timeout
ENV KILL_ALL_PROCESSES_TIMEOUT=60
 
### install prerequisites (cURL, gosu, JDK)
 
ENV GOSU_VERSION 1.12
ENV GOSU_GPG_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4
 
ARG DEBIAN_FRONTEND=noninteractive
RUN set -x \
&& apt-get update -qq \
&& apt-get install -qqy --no-install-recommends ca-certificates curl \
&& rm -rf /var/lib/apt/lists/* 
RUN curl -L -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
&& curl -L -o /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
&& export GNUPGHOME="$(mktemp -d)"; \
( gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GOSU_GPG_KEY" \
    || gpg --keyserver keyserver.pgp.com --recv-keys "$GOSU_GPG_KEY" ); \
gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
&& chmod +x /usr/local/bin/gosu \
&& gosu nobody true \
&& apt-get update -qq \
&& apt-get install -qqy openjdk-8-jdk \
&& apt-get clean \
&& set +x
 

### install filebeats

ENV FILEBEAT_VERSION 7.10.0
ENV TARBALL_SHA "509f0d7f2a16d70850c127dd20bea7c735fc749f8d90f8e797196d11887ceccf32d8d71e1177ae9dbe7c8d081133b7d75e431997123512fc17ee1e04e96a6bc5"
ENV FILEBEAT_GPG_KEY "46095ACC8548582C1A2699A9D27D666CD88E42B4"
ENV FILEBEAT_HOME /usr/share/filebeat
ENV DOWNLOAD_URL https://artifacts.elastic.co/downloads/beats/filebeat
ENV FILEBEAT_PACKAGE "${DOWNLOAD_URL}/filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz"
ENV FILEBEAT_TARBALL_ASC "${DOWNLOAD_URL}/filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz.asc"
ENV FILEBEAT_GID 992
ENV FILEBEAT_UID 992
 
RUN mkdir ${FILEBEAT_HOME} \
  && set -ex \
  && cd /tmp \
  && curl -L ${FILEBEAT_PACKAGE} -o filebeat.tar.gz; \
  if [ "$TARBALL_SHA" ]; then \
    echo "$TARBALL_SHA *filebeat.tar.gz" | sha512sum -c -; \
  fi; \
  \
  if [ "$TARBALL_ASC" ]; then \
    curl -L ${FILEBEAT_TARBALL_ASC} -o filebeat.tar.gz.asc; \
    export GNUPGHOME="$(mktemp -d)"; \
    ( gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$FILEBEAT_GPG_KEY" \
    || gpg --keyserver pgp.mit.edu --recv-keys "$FILEBEAT_GPG_KEY" \
    || gpg --keyserver keyserver.pgp.com --recv-keys "$FILEBEAT_GPG_KEY" ); \
    gpg --batch --verify filebeat.tar.gz.asc filebeat.tar.gz; \
    rm -rf "$GNUPGHOME" filebeat.tar.gz.asc || true; \
  fi; \
  tar xzf filebeat.tar.gz -C ${FILEBEAT_HOME} --strip-components=1 \
  && groupadd -r filebeat -g ${FILEBEAT_GID} \
  && useradd -r -s /usr/sbin/nologin -d ${FILEBEAT_HOME} -c "Filebeat service user" -u ${FILEBEAT_UID} -g filebeat filebeat \
  && chown -R filebeat:filebeat ${FILEBEAT_HOME}


# install aws cli, unzip, jq

RUN apt-get install -y unzip jq

RUN cd /tmp && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm awscliv2.zip 


### Clean up APT when done.
 
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


ADD entrypoint.sh /opt/entrypoint.sh
RUN sed -i -e 's#^LS_HOME=$#LS_HOME='$LOGSTASH_HOME'#' /opt/entrypoint.sh \
&& chmod +x /opt/entrypoint.sh
USER root
RUN chown root:filebeat /usr/share/filebeat/filebeat.yml
USER filebeat
# Override base image entrypoint and run logstash in foreground
ENTRYPOINT ["/opt/entrypoint.sh"]
