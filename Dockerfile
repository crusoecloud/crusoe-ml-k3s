FROM nvcr.io/nvidia/pytorch:23.10-py3

ARG NCCL_TESTS_VERSION=master
RUN apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated    \
    wget \
    curl \
    git \
    gcc \
    vim \
    kmod   \
    openssh-client   \
    openssh-server   \
    build-essential  \
    curl  \
    autoconf \
    libtool \
    gdb \
    automake \
    python3-distutils  \
    cmake  \
    apt-utils \
    devscripts \
    debhelper  \
    libsubunit-dev \
    check \
    pkg-config

RUN mkdir -p /var/run/sshd
RUN sed -i 's/[ #]\(.*StrictHostKeyChecking \).*/ \1no/g' /etc/ssh/ssh_config && \
    echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config &&  \
    sed -i 's/#\(StrictModes \).*/\1no/g' /etc/ssh/sshd_config

RUN git clone https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests \
    && cd /opt/nccl-tests \
    && git checkout ${NCCL_TESTS_VERSION} \
    && make MPI=1 MPI_HOME=/opt/hpcx/ompi CUDA_HOME=/usr/local/cuda

RUN wget -O "/opt/h100-80gb-sxm-ib.xml" "https://docs.crusoecloud.com/assets/files/h100-80gb-sxm-ib-b914fb7ebbe8cbad591dd43abb36d687.xml"
ENV NCCL_TOPO_FILE=/opt/h100-80gb-sxm-ib.xml
