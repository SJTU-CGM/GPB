# fGPB: Flow-based Graph Pangenome Browser
# Dockerfile

FROM ubuntu:22.04

LABEL maintainer="fGPB Team"       
LABEL description="fGPB: Flow-based Graph Pangenome Browser"       
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    wget \
    ca-certificates \
    perl \
    libperl-dev \
    libjson-perl \
    pkg-config \
    libjemalloc-dev \
    libatomic-ops-dev \
    libhts-dev \
    libjansson-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libboost-all-dev \
    libbz2-dev \
    liblzma-dev \
    libcurl4-gnutls-dev \
    libssl-dev \
    libncurses5-dev \
    libncursesw5-dev \
    zlib1g-dev \
    python3 \
    python3-pip \
    file \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /app/build

RUN git clone --recursive https://github.com/pangenome/odgi.git && \
    cd odgi && \
    cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -- -j4 && \
    cmake --install build --prefix /usr/local && \
    cd .. && rm -rf odgi

RUN wget https://github.com/samtools/samtools/releases/download/1.20/samtools-1.20.tar.bz2 && \
    tar -xjf samtools-1.20.tar.bz2 && \
    cd samtools-1.20 && \
    ./configure --prefix=/usr/local && \
    make -j4 && \
    make install && \
    cd .. && rm -rf samtools-1.20 samtools-1.20.tar.bz2

RUN wget https://github.com/samtools/bcftools/releases/download/1.20/bcftools-1.20.tar.bz2 && \
    tar -xjf bcftools-1.20.tar.bz2 && \
    cd bcftools-1.20 && \
    ./configure --prefix=/usr/local && \
    make -j4 && \
    make install && \
    cd .. && rm -rf bcftools-1.20 bcftools-1.20.tar.bz2

RUN ldconfig

WORKDIR /app

COPY . /app/fGPB/ 

WORKDIR /app/fGPB

RUN chmod +x fgpb

RUN if [ -f ext/bin/vg ]; then \
        chmod +x ext/bin/vg &&  \
        ln -sf /app/fGPB/ext/bin/vg /usr/local/bin/vg; \
    else \
        echo "WARNING: VG not found at ext/bin/vg"; \
    fi

ENV PATH="/app/fGPB:/app/fGPB/ext/bin:${PATH}" 
ENV PERL5LIB="/app/fGPB/lib"

RUN echo "=== Verifying installations ===" && \
    odgi version && \
    vg version | head -1 && \
    samtools --version | head -1 && \
    bcftools --version | head -1 && \
    perl --version | head -2 | tail -1 && \
    fgpb --help

WORKDIR /data
VOLUME ["/data"]

ENTRYPOINT ["fgpb"]
CMD ["--help"]
