# Staged build: dependencies and CLI tools first
FROM rockylinux/rockylinux:9-ubi-init as cli
ENV MAGAOX_ROLE=container
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
ADD ./_common.sh /setup/
RUN dnf install -y 'dnf-command(config-manager)' sudo
ADD ./steps/install_rocky_9_packages.sh /setup/steps/
RUN bash /setup/steps/install_rocky_9_packages.sh
ADD ./setup_users_and_groups.sh /setup/
RUN bash /setup/setup_users_and_groups.sh
ADD ./steps/configure_rocky_9.sh /setup/steps/
RUN bash /setup/steps/configure_rocky_9.sh
ADD . /opt/MagAOX/source/magao-x-setup
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN bash -lx provision.sh
USER xsup

# Now reuse previous layers to build all the GUIs
FROM cli as gui
USER root
ENV MAGAOX_ROLE=workstation
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN bash -lx provision.sh
USER xsup
