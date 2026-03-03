FROM debian:trixie

ENV container=docker \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        systemd \
        systemd-sysv \
        cockpit \
        sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Units entfernen, die im Container nicht funktionieren oder nicht benötigt werden
RUN find /etc/systemd/system /lib/systemd/system \
        -path '*.wants/*' \
        \( -name '*getty*' \
        -o -name '*apt-daily*' \
        -o -name '*systemd-timesyncd*' \
        \) \
        -exec rm -f {} \; 2>/dev/null || true

# Cockpit über Socket-Aktivierung starten
RUN systemctl enable cockpit.socket

# Demo-Benutzer: admin / admin (nur für Lab-Zwecke)
RUN useradd -m -s /bin/bash admin && \
    echo 'admin:admin' | chpasswd && \
    usermod -aG sudo admin

EXPOSE 9090

# Sauberes Herunterfahren von systemd im Container
STOPSIGNAL SIGRTMIN+3

CMD ["/lib/systemd/systemd"]
