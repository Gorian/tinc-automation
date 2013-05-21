#!/usr/bin/env bash
#
# script to automate installation and configuration of tinc
# to add client to vpn

network_name=""; # name the virtual network
network_config_dir="/etc/tinc/${network_name}"
gateway_host=""; # hostname of server to connect to
gateway_host_fqdn="${gateway_host}"; # hostname of server to connect to. Fully qualified domain name
## install tinc
printf "installing tinc...\n";
{
apt-get -y update;
apt-get -y upgrade;
apt-get -y install tinc;
} >/dev/null 2>&1
if [[ $? == "0" ]]; then
  printf "tinc install successful\n";
else
	printf "error installing tinc\n";
fi

## Get config parameters
read -p "Hostname [$(hostname)]: " HostName;
if [[ -z ${HostName} ]]; then
	HostName=$(hostname);
fi
read -p "IP Address or dhcp [dhcp]: " lan_ip;
if [[ -z ${lan_ip} ]]; then
	lan_ip="dhcp";
fi

## configure tinc
mkdir -p ${network_config_dir}/hosts; 
# we use -p. That means this command will create both our ${network_config_dir} directory AND the hosts subdirectory
{ cat /etc/tinc/nets.boot | grep "${network_name}"; } &>/dev/null;
if [[ $? != "0" ]]; then
	printf "${network_name}\n" >> /etc/tinc/nets.boot;
fi
cat >> ${network_config_dir}/tinc.conf <<-EOF
# tinc configuration
# ubuntu
name			= 	${HostName}
ConnectTo		= 	${gateway_host}
device			=	/dev/net/tun
AddressFamily		=	ipv4
mode			=	router
PrivateKeyFile		=	/etc/tinc/${network_name}/rsa_key.priv
StrictSubnets		=	no
TunnelServer		=	no
EOF

cat >> ${network_config_dir}/hosts/${gateway_host} <<-EOF
# public host file for teinvpnggateway01
subnet 	=	10.255.248.1/32
address =	${gateway_host_fqdn}
cipher	=	blowfish
digest	=	sha1
port	=	655

-----BEGIN RSA PUBLIC KEY-----
MIICCgKCAgEAu26uNPZFbJCrOfAtjerfkmUUcHl26f5xravrFXh1AAq5H05BKasL
Ovtc8+1DHwFHqtZjGLDdbuzZb6Hp36P22qUJdnTyhPQOgTxzuom9psaaoGzxvLdo
8xRTtP7NZUUwOfPK/qW5F2h0lUnskkoptTrvfz3eh+SkNq4vBwE8WbO8/o3FLSDD
pWVXENyFt8jCDLd3V/0mMk2DopVqd+wan/7L6PFXod4CtkGa1p16gpKXyInTLJzb
yNhR+iNhpyJ2hm+dvEnAQAMFYNSYZkjrKBboeLYgYnw5qPqbozH4s6LE9gD4TT1B
U+UDQ8Qr4rjblY8qKalMMirZ+FjKrHEUWx0sL9BnjjcwPyd0LCITLL74+77QUvco
uQEO5hyWKrALFRdmUp0oyUADDIk27sjXtfCZkOLI1rpInuDAnebrGSWFvG85XGQC
asYcfWeZpWNhrxkCsDdjP9PxqwGgNDYYmlnOV5CWhaQGF3S4DptxYMWFzKFuRBUM
/3PNgJLE72OT21CelmJuMbxZaC88fKdnb/GkU9hVCN3FExUUk+Ft2MO7210YrsaE
Ao4k/JhJd/zoM7LhbkaX0yLFXdxjYGC4pnkjb919vO8ycoz6/ixrNmuwE9DINPfs
4L6rqQJNjW3SvKetyY0tJZAAMFm1Qfonb4cEUsQ4fhSi0BKmHwNJtocCAwEAAQ==
-----END RSA PUBLIC KEY-----
EOF

cat >> ${network_config_dir}/tinc-up <<-EOF
#!/usr/bin/env bash
# tinc-up script
# Thelenesian Enterprises
---INTERFACE CONFIG---
EOF

chmod +x ${network_config_dir}/tinc-up;

if [[ "${lan_ip}" == "dhcp" ]]; then
	sed -i "s/---INTERFACE CONFIG---/ifconfig \$INTERFACE hw ether 06:00:00:00:00:01 /g" ${network_config_dir}/tinc-up;
else
	sed -i "s/---INTERFACE CONFIG---/ifconfig \$INTERFACE ${lan_ip} netmask 255.255.248.0/g" ${network_config_dir}/tinc-up;
fi

cat >> ${network_config_dir}/hosts/${HostName} <<-EOF
# public host file for ${HostName}
---HOST FILE SUBNET LINE---
cipher  =       blowfish
digest  =       sha1
port    =       655
EOF

if [[ "${lan_ip}" == "dhcp" ]]; then
	sed -i "s/---HOST FILE SUBNET LINE---/# IP assigned via DHCP/g" ${network_config_dir}/hosts/${HostName};
else
	sed -i "s/---HOST FILE SUBNET LINE---/subnet  =       ${lan_ip}\/32/g" ${network_config_dir}/hosts/${HostName};
fi

# generate keys
yes | tincd -n ${network_name} -K4096;

# upload host file to gateways
printf "\nUploading host record to VPN Gateway. Please enter the gateway password.\n"
scp ${network_config_dir}/hosts/${HostName} root@${gateway_host_fqdn}:${network_config_dir}/hosts/${HostName}
# start service
{
service tinc stop
tincd -n ${network_name}
service tinc start
} &>/dev/null
exit
