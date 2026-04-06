# Staged build: dependencies and CLI tools first
FROM rockylinux/rockylinux:9-ubi-init AS build
ENV MAGAOX_CONTAINER=1
ENV MAGAOX_ROLE=headless
RUN env
ADD . /opt/MagAOX/source/magao-x-setup
WORKDIR /opt/MagAOX/source/magao-x-setup
# work around weird issue where Rocky ARM base image
# has "---------- 1 root root    417 Nov 23 18:17 shadow"
# but apparently only in GitHub Actions Docker runs?
RUN chmod -v u=rw,g=,o= /etc/shadow /etc/shadow-
RUN dnf clean all && dnf makecache && dnf install -y sudo passwd && dnf autoremove && dnf clean all
RUN bash -x setup_users_and_groups.sh
RUN bash -x steps/ensure_dirs_and_perms.sh
RUN dnf clean all && dnf makecache && bash -lx install_third_party_deps.sh && dnf autoremove && dnf clean all

FROM scratch AS cli
COPY --from=build / /
RUN env
ENV MAGAOX_ROLE=headless
ENV MAGAOX_CONTAINER=1
RUN env
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN bash -lx provision.sh
USER xsup

FROM cli AS gui
USER root
ENV MAGAOX_ROLE=workstation
ENV MAGAOX_CONTAINER=1
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN dnf clean all && dnf makecache && bash -lx provision.sh && dnf autoremove && dnf clean all
USER xsup
