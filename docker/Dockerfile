FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt upgrade -y && \
    apt install -y build-essential liblzma-dev git isolinux \
    tftpd-hpa nginx wget uuid-dev nano

RUN mkdir -p /pxeboot/{config,firmware,os-images}

COPY nginx.conf /etc/nginx/sites-available/ipxe
RUN ln -sf /etc/nginx/sites-available/ipxe /etc/nginx/sites-enabled/ipxe && \
    rm -f /etc/nginx/sites-enabled/default

COPY tftpd-hpa /etc/default/tftpd-hpa
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/pxeboot"]

EXPOSE 69/udp 65100

ENTRYPOINT ["/entrypoint.sh"]