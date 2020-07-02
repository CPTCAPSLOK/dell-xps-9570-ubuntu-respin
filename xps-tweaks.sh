#!/usr/bin/env bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

release=$(lsb_release -c -s)

# Check if the script is running under Ubuntu 18.04 Bionic Beaver
if [ "$release" != "bionic" ] && [ "$release" != "eoan" ] && [ "$release" != "focal" ] ; then
    >&2 echo -e "${RED}This script is made for Ubuntu 18.04/19.10/20.04!${NC}"
    exit 1
fi

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
    >&2 echo -e "${RED}Please run xps-tweaks as root!${NC}"
    exit 2
fi

# Enable universe and proposed
add-apt-repository -y universe
apt -y update
apt -y full-upgrade

# Install all the power management tools
if [ "$release" != "focal" ] ; then
    add-apt-repository -y ppa:linrunner/tlp
    apt -y update
fi
apt -y install thermald tlp tlp-rdw powertop

# Fix Sleep/Wake Bluetooth Bug
sed -i '/RESTORE_DEVICE_STATE_ON_STARTUP/s/=.*/=1/' /etc/tlp.conf
systemctl restart tlp

# Install the latest nVidia driver and codecs (not needed in Focal as it's all ready out-of-the-box)
if [ "$release" != "focal" ] ; then
    echo -e "${GREEN}Do you wish to enable PRIME Offloading on the NVIDIA GPU? This may increase battery drain but will allow dynamic switching of the NVIDIA GPU without having to log out.${NC}"
    select yn in "Yes" "No"; do
        case $yn in
            Yes )
                # Add repository with Xorg Builds containing required NVIDIA patches.
                if [ "$release" == "bionic" ]; then
                    add-apt-repository -y ppa:aplattner/ppa
                fi
                # Enable Proprietary GPU PPA
                add-apt-repository -y ppa:graphics-drivers/ppa

                apt -y update
                apt -y upgrade
                apt -y install nvidia-driver-440 nvidia-settings

                # Create simple script for launching programs on the NVIDIA GPU
                echo '__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME="nvidia" __VK_LAYER_NV_optimus="NVIDIA_only" exec "$@"' >> /usr/local/bin/prime
                chmod +x /usr/local/bin/prime

                # Create xorg.conf.d directory (If it doesn't already exist) and copy PRIME configuration file
                mkdir -p /etc/X11/xorg.conf.d/
                wget https://raw.githubusercontent.com/JackHack96/dell-xps-9570-ubuntu-respin/master/10-prime-offload.conf
                mv 10-prime-offload.conf /etc/X11/xorg.conf.d/

                # Enable modesetting on the NVIDIA Driver (Enables use of offloading and PRIME Sync)
                echo "options nvidia-drm modeset=1" >> /etc/modprobe.d/nvidia-drm.conf
                break;;
            No )
                apt -y update
                ubuntu-drivers autoinstall
                break;;
        esac
    done
fi

# Fix Audio Feedback/White Noise from Headphones on Battery Bug
echo -e "${GREEN}Do you wish to fix the headphone white noise on battery bug? (if you do not have this issue, there is no need to enable it) (may slightly impact battery life)${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) sed -i '/SOUND_POWER_SAVE_ON_BAT/s/=.*/=0/' /etc/tlp.conf; systemctl restart tlp; break;;
        No ) break;;
    esac
done

# Install codecs
echo -e "${GREEN}Do you wish to install video codecs for encoding and playing videos?${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) apt -y install ubuntu-restricted-extras va-driver-all vainfo libva2 gstreamer1.0-libav gstreamer1.0-vaapi; break;;
        No ) break;;
    esac
done

# Enable high quality audio
echo -e "${GREEN}Do you wish to enable high quality audio? (may impact battery life)${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo "# This file is part of PulseAudio.
#
# PulseAudio is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# PulseAudio is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with PulseAudio; if not, see <http://www.gnu.org/licenses/>.

## Configuration file for the PulseAudio daemon. See pulse-daemon.conf(5) for
## more information. Default values are commented out.  Use either ; or # for
## commenting.

daemonize = no
; fail = yes
; allow-module-loading = yes
; allow-exit = yes
; use-pid-file = yes
; system-instance = no
; local-server-type = user
; enable-shm = yes
; enable-memfd = yes
; shm-size-bytes = 0 # setting this 0 will use the system-default, usually 64 MiB
; lock-memory = no
; cpu-limit = no

high-priority = yes
nice-level = -11

realtime-scheduling = yes
realtime-priority = 9

; exit-idle-time = 20
; scache-idle-time = 20

; dl-search-path = (depends on architecture)

; load-default-script-file = yes
; default-script-file = /etc/pulse/default.pa

; log-target = auto
; log-level = notice
; log-meta = no
; log-time = no
; log-backtrace = 0

resample-method = soxr-vhq
avoid-resampling = true
; enable-remixing = yes
; remixing-use-all-sink-channels = yes
enable-lfe-remixing = no
; lfe-crossover-freq = 0

flat-volumes = no

; rlimit-fsize = -1
; rlimit-data = -1
; rlimit-stack = -1
; rlimit-core = -1
; rlimit-as = -1
; rlimit-rss = -1
; rlimit-nproc = -1
; rlimit-nofile = 256
; rlimit-memlock = -1
; rlimit-locks = -1
; rlimit-sigpending = -1
; rlimit-msgqueue = -1
; rlimit-nice = 31
rlimit-rtprio = 9
; rlimit-rttime = 200000

default-sample-format = float32le
default-sample-rate = 48000
alternate-sample-rate = 44100
default-sample-channels = 2
default-channel-map = front-left,front-right

default-fragments = 2
default-fragment-size-msec = 125

; enable-deferred-volume = yes
deferred-volume-safety-margin-usec = 1
; deferred-volume-extra-delay-usec = 0" > /etc/pulse/daemon.conf; break;;
        No ) break;;
    esac
done

# Enable LDAC, APTX, APTX-HD, AAC support in PulseAudio Bluetooth (for Ubuntu 18.04)
if [ "$release" == "bionic" ]; then
    add-apt-repository ppa:eh5/pulseaudio-a2dp
    apt-get update
    apt-get install libavcodec58 libldac pulseaudio-modules-bt
fi

# Intel microcode
apt -y install intel-microcode iucode-tool

# Enable power saving tweaks for Intel chip
if [[ $(uname -r) == *"4.15"* ]]; then
    echo "options i915 enable_fbc=1 enable_guc_loading=1 enable_guc_submission=1 disable_power_well=0 fastboot=1" > /etc/modprobe.d/i915.conf
else
    echo "options i915 enable_fbc=1 enable_guc=3 disable_power_well=0 fastboot=1" > /etc/modprobe.d/i915.conf
fi

# Let users check fan speed with lm-sensors
echo "options dell-smm-hwmon restricted=0 force=1" > /etc/modprobe.d/dell-smm-hwmon.conf
if < /etc/modules grep "dell-smm-hwmon" &>/dev/null; then
    echo "dell-smm-hwmon is already in /etc/modules!"
else
    echo "dell-smm-hwmon" >> /etc/modules
fi
update-initramfs -u

# Tweak grub defaults
GRUB_OPTIONS_VAR_NAME="GRUB_CMDLINE_LINUX_DEFAULT"
GRUB_OPTIONS="quiet splash acpi_rev_override=1 acpi_osi=Linux nouveau.modeset=0 pcie_aspm=force drm.vblankoffdelay=1 scsi_mod.use_blk_mq=1 nouveau.runpm=0 mem_sleep_default=deep "
echo -e "${GREEN}Do you wish to disable SPECTRE/Meltdown patches for performance?${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
            if [[ $(uname -r) == *"4.15"* ]]; then
                GRUB_OPTIONS+="noibrs noibpb nopti nospectre_v2 nospectre_v1 l1tf=off nospec_store_bypass_disable no_stf_barrier mds=off mitigations=off"
            else
                GRUB_OPTIONS+="mitigations=off"
            fi
            break;;
        No ) break;;
    esac
done
GRUB_OPTIONS_VAR="$GRUB_OPTIONS_VAR_NAME=\"$GRUB_OPTIONS\""

if < /etc/default/grub grep "$GRUB_OPTIONS_VAR" &>/dev/null; then
    echo -e "${GREEN}Grub is already tweaked!${NC}"
else
    sed -i "s/^$GRUB_OPTIONS_VAR_NAME=.*/$GRUB_OPTIONS_VAR_NAME=\"$GRUB_OPTIONS\"/g" /etc/default/grub
    update-grub
fi

# Ask for disabling tracker
echo -e "${GREEN}Do you wish to disable GNOME tracker (it uses a lot of power)?${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) systemctl mask tracker-extract.desktop tracker-miner-apps.desktop tracker-miner-fs.desktop tracker-store.desktop; break;;
        No ) break;;
    esac
done

# Ask for disabling fingerprint reader
echo -e "${GREEN}Do you wish to disable the fingerprint reader to save power (no linux driver is available for this device)?${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo "# Disable fingerprint reader
        SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"27c6\", ATTRS{idProduct}==\"5395\", ATTR{authorized}=\"0\"" > /etc/udev/rules.d/fingerprint.rules; break;;
        No ) break;;
    esac
done

echo -e "${GREEN}FINISHED! Please reboot the machine!${NC}"
