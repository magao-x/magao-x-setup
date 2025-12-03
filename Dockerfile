# Staged build: dependencies and CLI tools first
FROM rockylinux/rockylinux:9-ubi-init AS build
ENV MAGAOX_ROLE=container
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
ADD ./_common.sh /setup/
ADD ./steps/install_rocky_9_packages.sh /setup/steps/
RUN dnf clean all && \
    dnf --refresh makecache && \
    dnf install -y 'dnf-command(config-manager)' && \
    dnf config-manager --set-enabled crb
RUN sed -i \
  -e 's|^mirrorlist=|#mirrorlist=|' \
  -e 's|^#baseurl=http|baseurl=http|' \
  /etc/yum.repos.d/rocky.repo
RUN dnf clean all && \
    dnf --refresh makecache && \
    bash /setup/steps/install_rocky_9_packages.sh
ADD ./steps/install_python.sh /setup/steps/
ADD ./setup_users_and_groups.sh /setup/
RUN bash /setup/setup_users_and_groups.sh
ADD ./steps/configure_rocky_9.sh /setup/steps/
RUN bash /setup/steps/configure_rocky_9.sh
ADD ./steps/ensure_dirs_and_perms.sh /setup/steps/
RUN bash /setup/steps/ensure_dirs_and_perms.sh
ADD . /opt/MagAOX/source/magao-x-setup
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN bash /setup/steps/install_python.sh
RUN dnf clean all && dnf makecache && bash -lx provision.sh

FROM scratch as cli
COPY --from=build / /
ENV MAGAOX_ROLE=container
USER xsup

FROM cli as gui
USER root
ENV MAGAOX_ROLE=workstation
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN dnf clean all && dnf makecache && bash -lx provision.sh
USER xsup
