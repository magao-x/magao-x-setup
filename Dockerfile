# Staged build: dependencies and CLI tools first
FROM rockylinux/rockylinux:9-ubi-init AS build
ENV MAGAOX_CONTAINER=1
ENV MAGAOX_ROLE=headless
RUN env
ADD ./_common.sh /opt/MagAOX/source/magao-x-setup/
ADD ./configure_system/setup_users_and_groups.sh /opt/MagAOX/source/magao-x-setup/configure_system/
ADD ./configure_system/configure_container_sudoers.sh /opt/MagAOX/source/magao-x-setup/configure_system/
# work around weird issue where Rocky ARM base image
# has "---------- 1 root root    417 Nov 23 18:17 shadow"
# but apparently only in GitHub Actions Docker runs?
RUN chmod -v u=rw,g=,o= /etc/shadow /etc/shadow-
RUN dnf clean all && dnf makecache && dnf install -y sudo passwd && dnf autoremove && dnf clean all
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN bash -lx configure_system/setup_users_and_groups.sh
# xsup gets passwordless sudo within the container as
# an escape hatch
RUN bash -lx configure_system/configure_container_sudoers.sh
# For the container we pull out the OS-specific stuff because it's unlikely to change
# as often as the third_party and configure_system folders overall (more cached layer
# reuse)
ADD third_party/install_rocky_9_packages.sh /opt/MagAOX/source/magao-x-setup/third_party/
ADD configure_system/configure_rocky_9.sh /opt/MagAOX/source/magao-x-setup/configure_system/
RUN dnf clean all && dnf makecache && bash -lx third_party/install_rocky_9_packages.sh && dnf autoremove && dnf clean all
# Bespoke install scripts will expect the directory structure in `/opt/MagAOX`
ADD ./configure_system/ensure_dirs_and_perms.sh /opt/MagAOX/source/magao-x-setup/configure_system/
RUN bash -lx configure_system/ensure_dirs_and_perms.sh

# The scripts in third_party/ depend on stuff in some of the other folders
ADD ./conda_envs/ /opt/MagAOX/source/magao-x-setup/conda_envs/
ADD ./jupyterhub/ /opt/MagAOX/source/magao-x-setup/jupyterhub/
ADD ./third_party/ /opt/MagAOX/source/magao-x-setup/third_party/

# Lower-velocity dependencies should be built and cached:
ADD ./install/install_third_party_deps.sh /opt/MagAOX/source/magao-x-setup/install/install_third_party_deps.sh
RUN bash -lx install/install_third_party_deps.sh

# first-party build deps are a moving target (i.e. MILK / CACAO),
# so here's where we give up on cache reuse
ADD . /opt/MagAOX/source/magao-x-setup/
RUN bash -lx install/install_build_deps.sh

FROM scratch AS cli
COPY --link --from=build / /
ENV MAGAOX_ROLE=headless
ENV MAGAOX_CONTAINER=1
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN bash -lx install/provision.sh

USER xsup

FROM scratch AS gui
COPY --link --from=build / /
USER root
ENV MAGAOX_ROLE=workstation
ENV MAGAOX_CONTAINER=1
RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh
WORKDIR /opt/MagAOX/source/magao-x-setup
RUN dnf clean all && dnf makecache && bash -lx install/provision.sh && dnf autoremove && dnf clean all
USER xsup
