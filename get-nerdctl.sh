#!/bin/bash
set -e

NERDCTL_VERSION=1.7.7
NERDCTL_CNI_VERSION=1.6.0
NERDCTL_BUILD_VERSION=0.16.0

ARCH_TYPE="amd64"
if test "$(uname -m)" = "aarch64"
then
    ARCH_TYPE="arm64"
fi

# ContainerdApi
sudo apt update
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable --now containerd

# Nerdctl
NERDCTL_DOWNLOAD="https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-${ARCH_TYPE}.tar.gz"
echo "pulling from "$NERDCTL_DOWNLOAD
wget "$NERDCTL_DOWNLOAD" -O /tmp/nerdctl.tar.gz
sudo tar Cxzvvf /usr/local/bin /tmp/nerdctl.tar.gz

# Nerdctl CNI
NERDCTL_CNI_DOWNLOAD="https://github.com/containernetworking/plugins/releases/download/v${NERDCTL_CNI_VERSION}/cni-plugins-linux-${ARCH_TYPE}-v${NERDCTL_CNI_VERSION}.tgz"
echo "pulling from "$NERDCTL_CNI_DOWNLOAD
wget "$NERDCTL_CNI_DOWNLOAD" -O /tmp/nerdctlcni.tar.gz
sudo mkdir -p /usr/local/libexec/cni
sudo tar Cxzvvf /usr/local/libexec/cni /tmp/nerdctlcni.tar.gz

# Nerdctl build
NERDCTL_BUILD_DOWNLOAD="https://github.com/moby/buildkit/releases/download/v${NERDCTL_BUILD_VERSION}/buildkit-v${NERDCTL_BUILD_VERSION}.linux-${ARCH_TYPE}.tar.gz"
echo "pulling from "$NERDCTL_BUILD_DOWNLOAD
wget "$NERDCTL_BUILD_DOWNLOAD" -O /tmp/nerdctlbuild.tar.gz
sudo tar Cxzvvf /usr/local /tmp/nerdctlbuild.tar.gz

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