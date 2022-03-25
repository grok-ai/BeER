#! /bin/bash
# Adapted from http://cowlet.org/2018/05/21/accessing-gpus-from-a-docker-swarm-service.html and
# https://gist.github.com/tomlankhorst/33da3c4b9edbde5c83fc1244f010815c

# TODO: mandatory?
sudo mkdir -p /etc/systemd/system/docker.service.d

# https://stackoverflow.com/a/17841619
function join_by { local IFS="$1"; shift; echo "$*"; }

GPU_IDS=$(nvidia-smi -a | grep UUID | awk '{print $4}')

gpu_resources=()
for gpu_id in $GPU_IDS; do
    gpu_resources+=("\"GPU=$gpu_id\"")
done

gpus_list=$(join_by , "${gpu_resources[@]}")

# This solution needs nvidia-container-runtime to be available!
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "node-generic-resources": [
    $gpus_list
  ],
  "runtimes": {
      "nvidia": {
          "path": "/usr/bin/nvidia-container-runtime",
          "runtimeArgs": []
      }
  },
  "default-runtime": "nvidia"
}
EOF

## Allow the GPU to be advertised as a swarm resource
sudo sed -i '/swarm-resource = "DOCKER_RESOURCE_GPU/d' /etc/nvidia-container-runtime/config.toml
sudo sed -i '1iswarm-resource = "DOCKER_RESOURCE_GPU"' /etc/nvidia-container-runtime/config.toml

# Reload the Docker daemon
sudo systemctl daemon-reload
sudo systemctl restart docker
