FROM scratch

ARG P5_VENDOR_TAR_FILENAME=awpst806-container.tar
ARG P5_VERSION=8.0.6

ADD vendor/${P5_VENDOR_TAR_FILENAME} /

LABEL org.opencontainers.image.title="Archiware P5 Local Lab"
LABEL org.opencontainers.image.version="${P5_VERSION}"
LABEL org.opencontainers.image.vendor="Archiware GmbH"
LABEL com.matx.p5-local-lab.wrapper-version="2"

EXPOSE 8000/tcp 9001/tcp
STOPSIGNAL SIGTERM
CMD ["/usr/local/aw/start.sh"]

