#!/bin/bash
cd "$(dirname "$0")"

set -e

echo "Building Dockerfile"
sudo docker build . -f Dockerfile -t glua
echo "Building Dockerfile.full"
sudo docker build . -f Dockerfile.full -t glua:full

echo "Building Dockerfile.54"
sudo docker build . -f Dockerfile.54 -t glua:5.4
echo "Building Dockerfile.54-full"
sudo docker build . -f Dockerfile.54-full -t glua:5.4-full
