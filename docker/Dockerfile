FROM phusion/baseimage:0.9.22
CMD ["/sbin/my_init"]

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    libcurl4-openssl-dev libxml2 libxml2-dev libexpat1-dev zlib1g-dev libssl-dev \
    libjpeg-dev libpng-dev libgif-dev \
    git \
    && rm -rf /var/lib/apt/lists/* && apt-get clean

RUN useradd -ms /bin/bash app;

USER app
ADD install-perlbrew.sh /tmp/install-perlbrew.sh
RUN /tmp/install-perlbrew.sh

USER root
RUN apt-get update && apt-get install -y \
    libpq-dev \
    postgresql-client \
&& rm -rf /var/lib/apt/lists/* && apt-get clean

USER app

ADD install-cpan-modules.sh /tmp/install-cpan-modules.sh
RUN /tmp/install-cpan-modules.sh

USER root
RUN apt-get update && apt-get install -y \
    imagemagick \
    shared-mime-info \
    xvfb \
    poppler-utils \
    xfonts-75dpi \
    libdb-dev \
&& rm -rf /var/lib/apt/lists/* && apt-get clean

ADD install-wkhtmltopdf.sh /tmp/install-wkhtmltopdf.sh
RUN /tmp/install-wkhtmltopdf.sh

USER app

ADD Makefile_local.PL /tmp/Makefile.PL
ADD install-cpan-extra-modules.sh /tmp/install-cpan-extra-modules.sh
RUN /tmp/install-cpan-extra-modules.sh

USER root
RUN echo "0 */3 * * * su - app -c 'cd /src; ./script/refresh_random_indicator_cache.sh'\n" | crontab -

RUN mkdir /etc/service/omlpi
COPY omlpi.sh /etc/service/omlpi/run

RUN mkdir /etc/service/omlpi-minion-worker
COPY omlpi-minion-worker.sh /etc/service/omlpi-minion-worker/run
