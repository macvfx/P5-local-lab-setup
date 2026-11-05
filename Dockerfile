FROM scratch

ADD vendor/awpst806-container.tar /

LABEL org.opencontainers.image.title="Archiware P5 Local Lab"
LABEL org.opencontainers.image.version="8.0.6"
LABEL org.opencontainers.image.vendor="Archiware GmbH"
LABEL com.matx.p5-local-lab.wrapper-version="1"

EXPOSE 8000/tcp
STOPSIGNAL SIGTERM
CMD ["/usr/local/aw/start.sh"]

