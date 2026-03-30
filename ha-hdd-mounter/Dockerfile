ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.19
FROM ${BUILD_FROM}

RUN apk add --no-cache util-linux e2fsprogs xfsprogs ntfs-3g bash jq

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD [ "/run.sh" ]
