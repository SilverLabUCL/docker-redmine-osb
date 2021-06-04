FROM ubuntu:xenial-20180705 AS add-apt-repositories

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv E1DD270288B4E6030699E45FA1715D88E1DF1F24 \
 && echo "deb http://ppa.launchpad.net/git-core/ppa/ubuntu xenial main" >> /etc/apt/sources.list \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv 80F70E11F0F0D5F10CB20E62F5DA5F09C3173AA6 \
 && echo "deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu xenial main" >> /etc/apt/sources.list \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv 8B3981E7A6852F782CC4951600A6F0A3C300EE8C \
 && echo "deb http://ppa.launchpad.net/nginx/stable/ubuntu xenial main" >> /etc/apt/sources.list \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' > /etc/apt/sources.list.d/pgdg.list

FROM ubuntu:xenial-20180705

LABEL maintainer="sameer@damagehead.com"

ENV RUBY_VERSION=2.5 \
    REDMINE_VERSION=3.4.6 \
    REDMINE_USER="redmine" \
    REDMINE_HOME="/home/redmine" \
    REDMINE_LOG_DIR="/var/log/redmine" \
    REDMINE_ASSETS_DIR="/etc/docker-redmine" \
    RAILS_ENV=production

ENV REDMINE_INSTALL_DIR="${REDMINE_HOME}/redmine" \
    REDMINE_DATA_DIR="${REDMINE_HOME}/data" \
    REDMINE_BUILD_ASSETS_DIR="${REDMINE_ASSETS_DIR}/build" \
    REDMINE_RUNTIME_ASSETS_DIR="${REDMINE_ASSETS_DIR}/runtime"

COPY --from=add-apt-repositories /etc/apt/trusted.gpg /etc/apt/trusted.gpg

COPY --from=add-apt-repositories /etc/apt/sources.list /etc/apt/sources.list

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      sendmail supervisor logrotate nginx mysql-client postgresql-client ca-certificates sudo tzdata \
      imagemagick subversion git cvs bzr mercurial darcs rsync ruby${RUBY_VERSION} locales openssh-client \
      gcc g++ make patch pkg-config gettext-base ruby${RUBY_VERSION}-dev libc6-dev zlib1g-dev libxml2-dev \
      libmysqlclient20 libpq5 libyaml-0-2 libcurl3 libssl1.0.0 uuid-dev xz-utils \
      libxslt1.1 libffi6 zlib1g gsfonts \
 && update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX \
 && gem install sprockets -v 3.7.2 \
 && gem install rails -v 4.2.7.1 \
 && gem install bundler -v 1.17.3 \
 && rm -rf /var/lib/apt/lists/*

COPY assets/build/ ${REDMINE_BUILD_ASSETS_DIR}/

RUN bash ${REDMINE_BUILD_ASSETS_DIR}/install.sh

COPY assets/runtime/ ${REDMINE_RUNTIME_ASSETS_DIR}/


COPY assets/tools/ /usr/bin/

COPY entrypoint.sh /sbin/entrypoint.sh

RUN chmod 755 /sbin/entrypoint.sh \
 && sed -i '/session    required     pam_loginuid.so/c\#session    required   pam_loginuid.so' /etc/pam.d/cron
EXPOSE 80/tcp 443/tcp

ARG SERVER_IP
ARG GEPPETTO_IP

ENV SERVER_IP=${SERVER_IP:-"http://localhost:80/"}
ENV GEPPETTO_IP=${GEPPETTO_IP:-"http://localhost:8080/"}

COPY config/props.yml ${REDMINE_INSTALL_DIR}/config/props.yml
COPY config/configuration.yml ${REDMINE_INSTALL_DIR}/config/configuration.yml
RUN sed -i -e 's~serverIP:~serverIP: '$SERVER_IP'~g' ${REDMINE_INSTALL_DIR}/config/props.yml
RUN sed -i -e 's~geppettoIP:~geppettoIP: '$GEPPETTO_IP'~g' ${REDMINE_INSTALL_DIR}/config/props.yml

RUN mkdir -p ${REDMINE_INSTALL_DIR}/public/geppetto/tmp
RUN chown -R redmine:redmine ${REDMINE_INSTALL_DIR}/public/geppetto/tmp
RUN rm -rf ${REDMINE_INSTALL_DIR}/plugins/recaptcha 
RUN git clone "https://github.com/cdwertmann/recaptcha" ${REDMINE_INSTALL_DIR}/plugins/recaptcha
# delete view provided by recaptcha plugin (interferes with our redmine mods)
RUN rm -rf ${REDMINE_INSTALL_DIR}/plugins/recaptcha/app/views/account
RUN mkdir -p /home/svnsvn/myGitRepositories
#RUN SELECT value FROM custom_values WHERE custom_field_id=14 and value!='';  
RUN chown -R redmine:redmine /home/svnsvn

WORKDIR ${REDMINE_INSTALL_DIR}
ENTRYPOINT ["/sbin/entrypoint.sh"]

CMD ["app:start"]
