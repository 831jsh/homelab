# Proxmox VM Setup

This section will cover mostly everything related to the setup of the Kubernetes cluster VMs in Proxmox. I chose to document this process because I'm frustrated with the lack of support for infrastructure-as-code for bare-metal clusters in general. [Terraform](https://www.terraform.io/) has pretty good support for `vSphere` and `OpenStack` and some 3rd-party providers do exist for Proxmox (for example: [https://github.com/Telmate/terraform-provider-proxmox](https://github.com/Telmate/terraform-provider-proxmox)).

I really wanted this homelab repository to contain my infrastructure state with [Terraform](https://terraform.io) and code for generating OS images with [Packer](https://packer.io) but after a lot of research and practice on this topic, I kind of sidestepped the "infrastructure-as-code" rule for Terraform/Packer.

I spent a great deal of time researching the best way to add support for Terraform and after doing so, it really seems like overkill for a 6-VM Kubernetes cluster that probably won't ever grow larger; this would normally go against all of my own preachings as a Kubernetes Architect @ VMWare but it's my homelab and ~~I'll cry if I want to~~ I'm going to do what I want to.

Terraform and Packer aside, I'm still going to do the least amount of non-code-reproducible work as possible; I'll be using [Ansible](https://ansible.com) to provision all of the VMs and perform regular maintenance to them.

## Overview

Here's a diagram that attempts to portray what the architecture of VMs will look like after setting everything up:

![Proxmox VM Architecture](./images/proxmox-vm-architecture.svg)

Note: the blue lines indicate that the IP addresses are using the same private subnet.

## VM Resource Allocation

Proxmox itself has a set of hardware requirements to follow (which can be found [here](https://www.proxmox.com/en/proxmox-ve/requirements)). Below, I've organized the resource utilizations for each node (so I don't exceed quota).

### Node 1

This host has 16 cores, 136GB RAM and 900GB HDD to utilize. Here is a table that indicates how those resources are being split.

| Item | Cores | Memory | HDD |
|:-----|:-----:|:------:|:---:|
| Proxmox | 2 | 4GB | 100GB |
| k8s-master-01 | 4 | 16GB | 100GB |
| k8s-worker-01 | 10 | 116GB | 700GB |

### Node 2

This host has 16 cores, 192GB RAM and 587GB HDD to utilize. Here is a table that indicates how those resources are being split.

| Item | Cores | Memory | HDD |
|:-----|:-----:|:------:|:---:|
| Proxmox | 2 | 4GB | 100GB |
| k8s-master-02 | 4 | 16GB | 100GB |
| k8s-worker-02 | 10 | 172GB | 387GB |

### Node 3

This host has 16 cores, 136GB RAM and 900GB HDD to utilize. Here is a table that indicates how those resources are being split.

| Item | Cores | Memory | HDD |
|:-----|:-----:|:------:|:---:|
| Proxmox | 2 | 4GB | 100GB |
| k8s-master-03 | 4 | 16GB | 100GB |
| k8s-worker-03 | 10 | 116GB | 700GB |

## Setup

### Prerequisites

To proceed with the rest of this "Setup" section, it's recommended that you have a healthy 3+ node Proxmox cluster already installed and configured properly. For more information on how to install proxmox, check the [Get Started](https://www.proxmox.com/en/proxmox-ve/get-started) page on their website.

### Step 1

Pick an operating system distribution of your choice; for this homelab, I chose to run with Ubuntu 18.04 LTS (information on LTS support for Ubuntu can be found [here](https://www.ubuntu.com/about/release-cycle)). To get your VMs up and running, download the `.iso` to your local computer (can be found [here](https://www.ubuntu.com/download/server)). Once downloaded, upload the `.iso` to each node's `local` storage by using the Proxmox Web UI (found at the `https://<proxmox-node-ip>):8006`).

![Upload an ISO](./images/proxmox-upload-iso.png)

### Step 2

Next, right click on the first node in your proxmox cluster and click `Create VM`. Upon doing so, you'll be presented a wizard to walk you through the very painless steps of creating a VM. Here are some screenshots to show the process:

![Create VM - Step 01](./images/proxmox-create-vm-01.png)

I'd recommend coming up with a naming schema for your cluster VMs (just to keep yourself organized).

![Create VM - Step 02](./images/proxmox-create-vm-02.png)

Be sure to select the `.iso` you uploaded in Step 1.

![Create VM - Step 03](./images/proxmox-create-vm-03.png)

Make sure you change the disk size to the correct amount (as indicated in the resource allocations section above).

![Create VM - Step 04](./images/proxmox-create-vm-04.png)

A CPU socket is where you'd physically install a CPU chip on a motherboard. With KVM, a socket is only for emulation purposes; whether or not you choose 1 socket and 8 cores or 2 sockets and 4 cores -- it doesn't really matter.

*I typically like to emulate real server combinations when I configure socket/cores.*

In some cases, the number of sockets/cores might affect the software licensing you're installing on the VM; this is probably the only case where it actually matters how you configure sockets/cores.

![Create VM - Step 05](./images/proxmox-create-vm-05.png)

Make sure you change the memory to the correct amount (as indicated in the resource allocations section above). Remember, this screen asks for the number in `MiB`; to calculate the number, simply multiply the number of `GB` you want by `1024`.

![Create VM - Step 06](./images/proxmox-create-vm-06.png)

No change is necessary for this step.

![Create VM - Step 07](./images/proxmox-create-vm-07.png)

This step is just a recap of all the previous steps and a confirmation to move forward with actually creating the VM.

### Step 3

Repeat step 2 for each of the other 5 VMs for this Kubernetes cluster; be sure to refer to the "Resource Allocation" section above when configuring each VM.

When you're done doing so, you're Proxmox side-panel should look something like this:

![Side Panel Before](./images/proxmox-side-panel-before.png)

### Step 4

Make sure that each VM you created will start at boot (when the Proxmox node itself boots). Here is a screenshot that shows where to make the change:

![Start at boot](./images/proxmox-start-at-boot.png)

### Step 5

Start your `k8s-master-01` VM (or whatever you may have called it). When your Ubuntu 18.04 VM has booted, you should see the following screen:

![Step 01](./images/proxmox-ubuntu-boot-01.png)

Proceed by selecting your language of choice; I chose `English` since that's what I speak primarily.

![Step 02](./images/proxmox-ubuntu-boot-02.png)

I chose the default keyboard layouts; not really much to do here - this is pretty standard.

![Step 03](./images/proxmox-ubuntu-boot-03.png)

Choose `Install Ubuntu` and press `Enter`.

![Step 04a](./images/proxmox-ubuntu-boot-04a.png)

Now you have the option to configure the network settings for the VM. By default, Ubuntu will pick DHCP but I chose to statically define my IP addresses because I need things to be in a deterministic state (in order to automate everything).

![Step 04b](./images/proxmox-ubuntu-boot-04b.png)

Choose `Manual` to statically define this VMs IP configuration; press `Enter` to move forward.

![Step 04c](./images/proxmox-ubuntu-boot-04c.png)

Fill out the static IP configuration for this VM. It's important to note that the `Subnet` input requires a CIDR block notation `192.168.13.1/24` as opposed to the standard subnet mask notation `255.255.255.0`

![Step 05](./images/proxmox-ubuntu-boot-05.png)

Unless your Proxmox cluster has special needs, it's best to not use a proxy here.

![Step 06](./images/proxmox-ubuntu-boot-06.png)

It's a good idea to leave this the default Mirror address.

![Step 07a](./images/proxmox-ubuntu-boot-07a.png)

Choose `Use An Entire Disk` and press `Enter`.

![Step 07b](./images/proxmox-ubuntu-boot-07b.png)

Nothing to change here; press `Enter` to proceed.

![Step 07c](./images/proxmox-ubuntu-boot-07c.png)

Nothing to change here; press `Enter` to proceed.

![Step 07d](./images/proxmox-ubuntu-boot-07d.png)

Select `Continue` and press `Enter` to proceed.

![Step 07e](./images/proxmox-ubuntu-boot-07e.png)

At this point, the installation of Ubuntu will start as a background process and the status will be tracked in the bottom of this GUI. On this screen, fill out your information; when you've done so, select `Done` and press `Enter` to continue.

![Step 07f](./images/proxmox-ubuntu-boot-07f.png)

I chose to `Install OpenSSH Server` (not selected by default). I also specified that I wanted this to import my SSH identity (public keys) from GitHub using my GitHub username; this is a super cool feature that makes SSH access to this VM really easy. When you've specified your settings, select `Done` and press `Enter` to continue.

![Step 10a](./images/proxmox-ubuntu-boot-10a.png)

At this point, the installation wizard pulled my GitHub public SSH keys and asked me to confirm if they were correct (please note that these keys do not require access as they are readily available for any user at `https://github.com/[github-username].keys`. Select `Yes` and press `Enter` to continue.

Note: the step number at the bottom hopped from 7 to 10 and I think this is because the background installation moved forward while I was capturing screenshots for this documentation.

![Step 10b](./images/proxmox-ubuntu-boot-10b.png)

This Ubuntu Server 18.04 Live image comes bundled with `Snap` (which we'll remove with Ansible later); see [the wiki](https://wiki.archlinux.org/index.php/Snap) for more information about `Snap` and what it does.

![Step 10c](./images/proxmox-ubuntu-boot-10c.png)

Finally, select `Reboot Now` and press `Enter`.

![Remove Media](./images/proxmox-remove-media.png)

When the VM reboots, power it off and remove the media from the hardware configuration for that VM. After doing so, it's okay to boot the VM.

### Step 6

Repeat step 5 for each of the other 5 VMs for this Kubernetes cluster.

When you're finished, your Proxmox side-panel should look something like this:

![Side Panel After](./images/proxmox-side-panel-after.png)

### Step 7

At this point, you should be able to SSH into the machines with your SSH key using the username and static IP address you previously configured for each VM.

```
~ ssh <username>@<static-ip>
The authenticity of host '<static-ip> (<static-ip>)' can't be established.
ECDSA key fingerprint is SHA256:+XlmQEVDWYiJihkVEKZEbOLdCQzkjBApCz3dv79+kEw.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '<static-ip>' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04.2 LTS (GNU/Linux 4.15.0-46-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Wed Mar 20 21:20:38 UTC 2019

  System load:  0.0               Processes:            110
  Usage of /:   6.0% of 97.93GB   Users logged in:      0
  Memory usage: 1%                IP address for ens18: <static-ip>
  Swap usage:   0%


48 packages can be updated.
22 updates are security updates.


Last login: Wed Mar 20 21:20:15 2019 from 192.168.13.1
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

<username>@k8s-master-01:~$ exit
logout
Connection to <static-ip> closed.
```

Congratulations, you're ready to proceed to the ansible portion of this repository; we're done doing things manually!
