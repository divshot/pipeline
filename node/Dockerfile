FROM node:0.10

RUN apt-get -y update && \
    apt-get -y install sudo

RUN adduser --disabled-password --gecos '' build
RUN adduser build sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN mkdir -p /home/build

USER build
ENV HOME /home/build

RUN npm config set prefix ~/npm
RUN npm install -g bower grunt-cli gulp broccoli-cli ember-cli

ADD ./scripts /home/build/scripts

VOLUME /home/build/src
WORKDIR /home/build/src

USER root
CMD ["bash","/home/build/scripts/run.sh"]
