#!/bin/bash
# Creates the Windows 11 test VM on a Linux KVM host, hands-free.
#
#   create-vm.sh WINDOWS_ISO UNATTEND_DIR
#
# UNATTEND_DIR holds autounattend.xml and firstlogon.ps1 with their
# placeholders (__PASSWORD__, __SSHKEY__) filled in. Needs passwordless sudo.
# The VM: 4 GB, 4 cores, 64 GB thin disk, UEFI with TPM 2.0, SATA disk and
# e1000e network (no extra drivers), NAT, VNC on localhost only. Windows
# installs, logs in as `tester` and enables OpenSSH: about 30 to 45 minutes.
set -euo pipefail
iso=$1; unattend=$2
name=critter-win11
img=/var/lib/libvirt/images

sudo apt-get install -y qemu-kvm libvirt-daemon-system virtinst swtpm swtpm-tools ovmf xorriso
sudo usermod -aG libvirt,kvm "$USER"
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default

xorriso -as mkisofs -quiet -J -r -V UNATTEND -o /tmp/unattend.iso "$unattend"
sudo install -m 644 "$iso" "$img/win11.iso"
sudo install -m 600 -o libvirt-qemu /tmp/unattend.iso "$img/unattend.iso"
rm -f /tmp/unattend.iso

sudo virt-install --connect qemu:///system --name "$name" \
	--memory 4096 --vcpus 4 --cpu host-passthrough --os-variant win11 \
	--boot uefi --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
	--disk path="$img/$name.qcow2",size=64,bus=sata,format=qcow2 \
	--cdrom "$img/win11.iso" \
	--disk path="$img/unattend.iso",device=cdrom,bus=sata \
	--network network=default,model=e1000e \
	--graphics vnc,listen=127.0.0.1 --video vga \
	--noautoconsole
# "Press any key to boot from CD or DVD": press it, but only while that
# prompt can be up. Setup's progress screen has Cancel focused, so a late
# Enter would cancel the install.
for i in $(seq 1 15); do sudo virsh send-key "$name" KEY_ENTER >/dev/null 2>&1 || true; sleep 1; done
sudo virsh autostart "$name"
# virt-install's install boot powers off at Setup's first restart rather
# than rebooting; start it again (later restarts use the saved config).
until [ "$(sudo virsh domstate "$name")" = "shut off" ]; do sleep 20; done
sudo virsh start "$name"
echo "Installing. Watch: sudo virsh domifaddr $name, then ssh tester@<ip>"
