# openbmc_readme.md

---
### Host PC
* Host PC: 122.116.228.96
* Username: fvp
* Password: demo123@
* OS: Ubuntu 22.04 (x86_64)
* Please remote access to the host PC and get the cpuinfo and meminfo


---
### Create a folder "./openbmc" in host PC and install the required package in the folder

```
sudo apt update
sudo apt install -y git gcc g++ make file wget gawk diffstat bzip2 cpio chrpath zstd lz4 bzip2 unzip xz-utils python3
```

---
### Install Docker in the host PC

```
curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
sudo usermod -aG docker $USER ; newgrp docker
```

---
### Install the repo

```
mkdir -p ~/.bin
PATH="${HOME}/.bin:${PATH}"
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo
chmod a+rx ~/.bin/repo
```

---
### Download and install the Arm FVP (RD-V3 r1) in host PC

```
mkdir -p ~/openbmc/fvp
cd ~/openbmc/fvp
wget https://developer.arm.com/-/cdn-downloads/permalink/FVPs-Neoverse-Infrastructure/RD-V3-r1/FVP_RD_V3_R1_11.29_35_Linux64_armv8l.tgz
tar -xvf FVP_RD_V3_R1_11.29_35_Linux64_armv8l.tgz
./FVP_RD_V3_R1.sh
```

---
### Initialize the build environment in host PC

```
mkdir -p ~/openbmc/host
cd ~/openbmc/host
~/.bin/repo init -u "https://git.gitlab.arm.com/infra-solutions/reference-design/infra-refdesign-manifests.git"  -m "pinned-rdv3r1-bmc.xml"  -b "refs/tags/RD-INFRA-2025.07.03"  --depth=1
repo sync -c -j $(nproc) --fetch-submodules --force-sync --no-clone-bundle
```

Apply required patches in host PC
```
cd ~/openbmc/host
git init
git remote add -f origin https://gitlab.arm.com/server_management/PoCs/fvp-poc
git config core.sparsecheckout true
echo /patch >> .git/info/sparse-checkout
git pull origin main
```

---
### Apply patch in BMC host

Create an "~/openbmc/apply_patch.sh" script inside the host PC
Paste in the following content. This script automatically applies the necessary patches to each firmware component:

```
FVP_DIR="host"
SOURCE="$HOME/openbmc/host"

GREEN='\033[0;32m'
NC='\033[0m'

pushd ${FVP_DIR} > /dev/null
echo -e "${GREEN}\n===== Apply patches to edk2 =====\n${NC}"
pushd uefi/edk2
git am --keep-cr ${SOURCE}/patch/edk2/*.patch
popd > /dev/null

echo -e "${GREEN}\n===== Apply patches to edk2-platforms =====\n${NC}"
pushd uefi/edk2/edk2-platforms > /dev/null
git am --keep-cr ${SOURCE}/patch/edk2-platforms/*.patch
popd > /dev/null

echo -e "${GREEN}\n===== Apply patches to edk2-redfish-client =====\n${NC}"
git clone https://github.com/tianocore/edk2-redfish-client.git
pushd edk2-redfish-client > /dev/null
git checkout 4f204b579b1d6b5e57a411f0d4053b0a516839c8
git am --keep-cr ${SOURCE}/patch/edk2-redfish-client/*.patch
popd > /dev/null

echo -e "${GREEN}\n===== Apply patches to buildroot =====\n${NC}"
pushd buildroot > /dev/null
git am ${SOURCE}/patch/buildroot/*.patch
popd > /dev/null

echo -e "${GREEN}\n===== Apply patches to build-scripts =====\n${NC}"
pushd build-scripts > /dev/null
git am ${SOURCE}/patch/build-scripts/*.patch
popd > /dev/null
popd > /dev/null
```


---
### Run the patch script in host PC:

```
cd ~/openbmc
chmod +x ./apply_patch.sh
./apply_patch.sh
```

---
### Build RDv3 R1 host Docker image in host PC

```
cd ~/openbmc/host/container-scripts
./container.sh build
```

---
### Run the docker in host PC and build busybox tests

```
cd ~/openbmc/host
docker run --rm \
  -v $HOME/openbmc/host:$HOME/host \
  -w $HOME/host \
  --env ARCADE_USER=$(id -un) \
  --env ARCADE_UID=$(id -u) \
  --env ARCADE_GID=$(id -g) \
  -t -i rdinfra-builder \
  bash -c "./build-scripts/rdinfra/build-test-busybox.sh -p rdv3r1 all"
```

---
### Verify the build artifacts in host PC:

```
ls -la ~/openbmc/host/output/rdv3r1/rdv3r1/
```

---
### Build the OpenBMC image in host PC

```
cd ~/openbmc
git clone https://github.com/openbmc/openbmc.git
cd ~/openbmc/openbmc
source setup fvp
bitbake obmc-phosphor-image
```

















