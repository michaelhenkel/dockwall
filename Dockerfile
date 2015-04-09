# Use phusion/baseimage as base image. To make your builds
# reproducible, make sure you lock down to a specific version, not
# to `latest`! See
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
# for a list of version numbers.
FROM phusion/baseimage

# Use baseimage-docker's init system.
#CMD ["/sbin/my_init"]
CMD ["/usr/bin/supervisord"]

# ...put your own build instructions here...

COPY rt /etc/dhcp/dhclient-exit-hooks.d/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 22

# Clean up APT when done.
#RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN \
  sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
  apt-get update && \
  apt-get install -y tcpdump iptables openssh-server supervisor && \
  mkdir -p /var/run/sshd /var/log/supervisor && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

