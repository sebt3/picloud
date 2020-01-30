# Raspberry PI  personnal "cloud"

## Introduction

- [Hubzilla](https://hubzilla.org/) is a self-hosted, federated social network, with the ability to connect to all the federated networks and provide features unknown of others (like file hosting, wiki, webdav, caldav...)
- [Raspberry PI](https://www.raspberrypi.org/) is a low cost home server solution.

The goal of this guide is to install Cloud like services on a raspberry PI to self-host you own "cloud" for you and your familly.

## Requirements

- a Raspberry PI (v3 or v4)
- an microSD card (minimum recommanded size : 32G)
- ability to configure your box/modem
- a public domain name resolving to your box

Just during the installation phase :
- a TV or an hdmi screen
- an usb keyboard

## Prepare the raspberry PI

1. Download the [raspbian image](https://downloads.raspberrypi.org/raspbian_lite_latest) 
2. Install the image:
  - From [linux](https://www.raspberrypi.org/documentation/installation/installing-images/linux.md)
  - From [windows](https://www.raspberrypi.org/documentation/installation/installing-images/windows.md)
3. plug the keyboard and the screen into the rPI
4. put the microSD card into the rPI
5. put the microUSB cord and the power plug in place
6. once the PI is started connect as pi
7. password: raspberry (warning the keyboard is in US qwerty so mind your typing)
8. `sudo raspi-config`
  - Do Step *4-3* (Localisation Options - Change Keyboard Layout) and setup accordingly
  - You might want to do the others options in the step 4 too
  - Do step *1* (the pi/raspberry combo is known by the bad guys...)
  - If you connect over wifi, then do step *2-2*
  - It's a good idea to enable *5-2* (Interfacing Options - SSH) if you plan on removing the keyboard and the screen from the pi
  - Use `[tab]` to select the `Finish` button
  
## Prepare your box
- Make sure your rPI will keep a static IP
- use the port-fordwing feature of your box to forward ports 80 and 443 to your rPI.
- If you want to use the XMPP feature (chat service) then forward the ports 5222 and 5269 too.
(Steps details depends on your box)

## Install steps

These dont have to be done on the pi, but might be done from your computer. If you're doing this from the rpi directly, then in the `config.ini` file (see bellow) uncomment the `localhost` line and comment the line before.

### Prepare
```bash
apt-get update
apt-get install -y ansible git python3-apt
```
### Clone this repository
```bash
git clone https://github.com/sebt3/picloud.git
cd picloud
```

### Edit the configuration

Edit the file `config.ini` and set `domain` and `email`.
Select the services you want.

```bash
nano config.ini
```

### Start the install
```bash
ansible-playbook -i config.ini install.yaml
```

### Finishing
Wait a little bit for the services to come up : many docker images have to be downloaded, and the services have to setup their data.

If you selected the ldap option, login to fusionDirectory and create a user in this interface. (you'll probably want to add an email in the second tab). And use this user to log into hubzilla. Otherwise, register a user in hubzilla directly.

Beside the public services available on the domain you configure, you'll find these administratives services available on the rPI :
- traefik on :8080
- fusiondirectory on :8081 (login: fd-admin, password: the admin password you set)
- grafana on :3000
- prometheus on :9090
- portainer on :9000
