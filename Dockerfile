ARG MONERO_TAG="v0.18.4.1"
# === Stage 1: Download, verify and extract ===
FROM debian:bookworm-slim AS builder

ARG MONERO_TAG
ARG monero_url="https://downloads.getmonero.org/cli/"
ARG monero_archive="monero-linux-x64-$MONERO_TAG.tar.bz2"
ARG monero_hashes="https://getmonero.org/downloads/hashes.txt"

RUN apt update && apt-get install -y \
      wget ca-certificates binutils gpg dirmngr gnupg bzip2 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN wget "$monero_url$monero_archive" && \
    wget "$monero_hashes" && \
    wget https://raw.githubusercontent.com/monero-project/monero/master/utils/gpg_keys/binaryfate.asc && \
    gpg --import binaryfate.asc && \
    gpg --verify hashes.txt || { echo '❌ Bad signature!'; exit 1; } && echo '✅ Signature OK' && \
    grep -E '^[a-f0-9]{64}  monero-linux-x64-v0.18.4.1.tar.bz2$' hashes.txt | sha256sum --check || { echo '❌ Hash mismatch!'; exit 1; } && echo '✅ Hash OK' && \
    tar --strip-components=1 -xvf "$monero_archive"

COPY extract-deps.sh /build/extract-deps.sh
RUN chmod +x extract-deps.sh && \
    /build/extract-deps.sh /build/monerod /out

# === Stage 2: Minimal runtime ===
FROM scratch
ARG MONERO_TAG

COPY --from=builder /out/bin /bin
COPY --from=builder /out/lib /lib
COPY --from=builder /out/usr /usr
COPY --from=builder /out/lib64 /lib64

LABEL org.opencontainers.image.title="monerod-zero" \
      org.opencontainers.image.description="A rootless, distroless, from-scratch Docker image for running monerod." \
      org.opencontainers.image.url="https://ghcr.io/lanjelin/monerod-zero" \
      org.opencontainers.image.source="https://github.com/Lanjelin/monerod-zero" \
      org.opencontainers.image.documentation="https://github.com/Lanjelin/monerod-zero" \
      org.opencontainers.image.version="$MONERO_TAG" \
      org.opencontainers.image.authors="Lanjelin" \
      org.opencontainers.image.licenses="GPL-3"

USER 1000:1000
ENTRYPOINT ["/bin/monerod"]

