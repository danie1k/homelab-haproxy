FROM clearlinux:latest  AS builder

ARG swupd_args
# Move to latest Clear Linux irelease to ensure
# that the swupd command line arguments are
# correct
RUN swupd update --no-boot-update $swupd_args

# Grab os-release info from the minimal base image so
# that the new content matches the exact OS version
COPY --from=clearlinux/os-core:latest /usr/lib/os-release /

# Install additional content in a target directory
# using the os version from the minimal base
RUN source /os-release \
 && mkdir /install_root \
 && swupd os-install -V ${VERSION_ID} \
    --path /install_root --statedir /swupd-state \
    --bundles=haproxy,clr-network-troubleshooter,iproute2 \
    --no-boot-update

# For some Host OS configuration with redirect_dir on,
# extra data are saved on the upper layer when the same
# file exists on different layers. To minimize docker
# image size, remove the overlapped files before copy.
RUN mkdir /os_core_install
COPY --from=clearlinux/os-core:latest / /os_core_install/
RUN cd / \
 && find os_core_install | sed -e 's/os_core_install/install_root/' | xargs rm -d &> /dev/null || true

FROM clearlinux/os-core:latest

COPY --from=builder /install_root /

RUN mkdir -p /usr/local/etc/haproxy

STOPSIGNAL SIGUSR1

COPY docker-entrypoint.sh /
COPY haproxy.cfg /usr/local/etc/haproxy

VOLUME /usr/local/etc/haproxy

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
