# Staged build: dependencies and CLI tools first
FROM rockylinux/rockylinux:9-ubi-init AS build
ENV MAGAOX_ROLE=container
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
RUN sed -i \
  -e 's|^mirrorlist=|#mirrorlist=|' \
  -e 's|^#baseurl=http|baseurl=http|' \
  /etc/yum.repos.d/rocky.repo
ADD . /opt/MagAOX/source/magao-x-setup
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN dnf clean all && dnf makecache && bash -lx provision.sh && dnf autoremove && dnf clean all

FROM scratch as cli
COPY --from=build / /
ENV MAGAOX_ROLE=container
USER xsup

FROM cli as gui
USER root
ENV MAGAOX_ROLE=workstation
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN dnf clean all && dnf makecache && bash -lx provision.sh && dnf autoremove && dnf clean all
USER xsup
