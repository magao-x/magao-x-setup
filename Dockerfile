# Staged build: dependencies and CLI tools first
FROM rockylinux/rockylinux:9-ubi-init AS build
ENV MAGAOX_CONTAINER=1
ENV MAGAOX_ROLE=headless
ADD . /opt/MagAOX/source/magao-x-setup
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN ls -laR /etc
RUN dnf clean all && dnf makecache && dnf install -y sudo passwd && dnf autoremove && dnf clean all
RUN bash -x setup_users_and_groups.sh
RUN bash -x steps/ensure_dirs_and_perms.sh
RUN dnf clean all && dnf makecache && dnf install -y sudo && bash -lx install_third_party_deps.sh && dnf autoremove && dnf clean all

FROM scratch AS cli
COPY --from=build / /
ENV MAGAOX_ROLE=headless
ENV MAGAOX_CONTAINER=1
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
