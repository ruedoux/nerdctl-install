#!/bin/bash
set -e

RUNC_VERSION=1.2.2
CONTAINERD_VERSION=2.0.0
NERDCTL_VERSION=2.0.1
NERDCTL_CNI_VERSION=1.6.1
NERDCTL_BUILD_VERSION=0.18.0

ARCH_TYPE="amd64"
if test "$(uname -m)" = "aarch64"
then
    ARCH_TYPE="arm64"
fi

# runc
RUNC_DOWNLOAD="https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${ARCH_TYPE}"
echo "Downloading runc from $RUNC_DOWNLOAD"
wget "$RUNC_DOWNLOAD" -O /tmp/runc
chmod +x /tmp/runc
sudo install /tmp/runc /usr/local/bin
rm /tmp/runc

# containerd
CONTAINERD_DOWNLOAD="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH_TYPE}.tar.gz"
echo "Downloading containerd from $CONTAINERD_DOWNLOAD"
wget "$CONTAINERD_DOWNLOAD" -O /tmp/containerd.tar.gz
sudo tar -C /usr/local -xvzf /tmp/containerd.tar.gz
rm /tmp/containerd.tar.gz

# containerd config
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable --now containerd

# nerdctl
NERDCTL_DOWNLOAD="https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-${ARCH_TYPE}.tar.gz"
echo "Downloading nerdctl from $NERDCTL_DOWNLOAD"
wget "$NERDCTL_DOWNLOAD" -O /tmp/nerdctl.tar.gz
sudo tar -C /usr/local/bin -xvzf /tmp/nerdctl.tar.gz
rm /tmp/nerdctl.tar.gz

# nerdctl CNI plugins
NERDCTL_CNI_DOWNLOAD="https://github.com/containernetworking/plugins/releases/download/v${NERDCTL_CNI_VERSION}/cni-plugins-linux-${ARCH_TYPE}-v${NERDCTL_CNI_VERSION}.tgz"
echo "Downloading CNI plugins from $NERDCTL_CNI_DOWNLOAD"
wget "$NERDCTL_CNI_DOWNLOAD" -O /tmp/nerdctlcni.tar.gz
sudo mkdir -p /usr/local/libexec/cni
sudo tar -C /usr/local/libexec/cni -xvzf /tmp/nerdctlcni.tar.gz
rm /tmp/nerdctlcni.tar.gz

# nerdctl buildkit
NERDCTL_BUILD_DOWNLOAD="https://github.com/moby/buildkit/releases/download/v${NERDCTL_BUILD_VERSION}/buildkit-v${NERDCTL_BUILD_VERSION}.linux-${ARCH_TYPE}.tar.gz"
echo "Downloading buildkit from $NERDCTL_BUILD_DOWNLOAD"
wget "$NERDCTL_BUILD_DOWNLOAD" -O /tmp/nerdctlbuild.tar.gz
sudo tar -C /usr/local -xvzf /tmp/nerdctlbuild.tar.gz
rm /tmp/nerdctlbuild.tar.gz

sudo tee /etc/systemd/system/buildkit.service > /dev/null <<EOF
[Unit]
Description=BuildKit
Requires=buildkit.socket
After=buildkit.socket
Documentation=https://github.com/moby/buildkit

[Service]
Type=notify
ExecStart=/usr/local/bin/buildkitd --addr fd://

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/buildkit.socket > /dev/null <<EOF
[Unit]
Description=BuildKit
Documentation=https://github.com/moby/buildkit

[Socket]
ListenStream=%t/buildkit/buildkitd.sock
SocketMode=0660

[Install]
WantedBy=sockets.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable buildkit.socket
sudo systemctl start buildkit.socket

sudo nerdctl run --rm hello-world
sudo nerdctl image rm hello-world
