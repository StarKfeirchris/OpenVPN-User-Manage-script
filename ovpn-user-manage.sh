#!/bin/bash
# Release v3 ; last upsate: 20201208

# Setting the execution environment, debug: set -xeo pipefail
set -eo pipefail

# Definition color; E = Color end
R="\e[1;91m"
G="\e[1;92m"
Y="\e[1;93m"
B="\e[1;96m"
E="\e[0m"

# Chenge script location.
cd /etc/openvpn/easy-rsa/2.0/

# Check system virsion and package.
os=$(lsb_release -irs | xargs)
if [[ ${os} == 'CentOS '* ]];
then
	check_rpm=$(rpm -qa | grep "p7zip" -c || true)
	if [[ ${check_rpm} == 2 ]];
	then
		true
	else
		yum install p7zip p7zip-plugins -y
	fi
elif [[ ${os} == 'Ubuntu '* ]];
then
	check_dpkg=$(dpkg --get-selections | grep "p7zip" -c || true)
	if [[ ${check_dpkg} == 1 ]];
	then
		true
	else
		apt-get install p7zip-full -y
	fi
else
	echo -e "${R}This system is not CentOS or Ubuntu!${E}"
	echo -e "${R}Please check your system.${E}"
	exit 0
fi

# Used when creating user ovpn files.
ovpn_config_head=$(echo 'client
dev tun
proto udp
remote vpn2.vpnserveraddress.com 1194
remote vpn.vpnserveraddress.com 1194
nobind
persist-key
persist-tun
comp-lzo
verb 3

cipher AES-256-CBC
auth SHA256
')

# Select Add, Revoke or search user.
# If the question option is entered incorrectly, it will be asked again.
while read -p "
$(echo -e "${Y}0${E} > ${G}Search user${E}")
$(echo -e "${Y}1${E} > ${G}Add user${E}")
$(echo -e "${Y}2${E} > ${R}Revoke user${E}")
$(echo -e "${Y}D/d${E} > ${R}Delete user certificate${E}")

$(echo -e "${B}Please choose one >${E}") " feature_choose

# Enter user name.
read -p "$(echo -e "${B}Please enter user name:${E}") " ovpn_user

# get_user_avl: avl = available ; get_user_rm: rm = remove
# "grep -c" = Suppress normal output; instead print a count of matching lines for each input file.
get_user_avl=$(cat /etc/openvpn/easy-rsa/2.0/keys/index.txt | grep "=${ovpn_user}/" | grep "V" -c || true)
get_user_rm=$(cat /etc/openvpn/easy-rsa/2.0/keys/index.txt | grep "=${ovpn_user}/" | grep "R" -c || true)

do
	if [[ ${feature_choose} == 0 ]];
	then
		search_user_file=$(ls /etc/openvpn/easy-rsa/2.0/keys/ | grep -wc ${ovpn_user}.key || true)

		echo -e "User Name: ${Y}${ovpn_user}${E}"

		# Check user file.
		if [[ ${search_user_file} == 1 ]];
		then
			echo -e "File exist: ${G}Ｏ${E}"
		else
			echo -e "File exist: ${R}Ｘ${E}"
		fi

		# Check user account.
		if [[ ${get_user_avl} == 1 ]];
		then
			echo -e "Available: ${G}Ｏ${E}"
		elif (( ${get_user_avl} > 1 ));
		then
			echo -e "Available: ${G}Ｏ${E}(There are ${R}${get_user_avl}${E} duplicate records!)"
		elif (( ${get_user_rm} >= 1 ));
		then
			echo -e "Available: ${R}Ｘ${E}"
		else
			echo -e "Available: ${R}Not exist!${E}"
		fi
		break
	elif [[ ${feature_choose} == 1 ]];
	then
		# Confirm that the user has not been created.
		check_username=$(ls /etc/openvpn/easy-rsa/2.0/keys/ | grep ${ovpn_user}.key -c || true)
		if [[ ${check_username} == 1 ]];
		then
			echo -e "${B}Find same user:${E} ${Y}${ovpn_user}${E}${B} !  please check ${E}${R}/etc/openvpn/user/${E}"
			exit 0
		fi

		# Randomly generate certificate password.
		char_1=$(echo ${ovpn_user} | cut -c1)
		char_cap_1=$(echo ${ovpn_user} | cut -c1 | tr '[:lower:]' '[:upper:]')
		char_2=$(echo ${ovpn_user} | cut -c2)
		py_pass=$(python pass-generator.py)
		cert_pass=$(echo ${char_1}${char_2}${py_pass}${char_cap_1}${char_2})
		echo -e "${B}Recommended certificate password:${E} ${Y}${cert_pass}${E}"

		# Start create new user <new username>.ovpn file.
		source /etc/openvpn/easy-rsa/2.0/vars
		sh /etc/openvpn/easy-rsa/2.0/build-key-pass ${ovpn_user}
				
		# Make new user folder for certificate file.
		mkdir /etc/openvpn/user/${ovpn_user}
				
		# Copy new user certificate file to /etc/openvpn/user/<new username>
		\cp /etc/openvpn/easy-rsa/2.0/keys/${ovpn_user}.* /etc/openvpn/user/${ovpn_user}
				
		# Copy OpenVPN config to new user <new username>.ovpn file.
		echo -e "${ovpn_config_head}\n" >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		
		# Copy new user certificate to <new username>.ovpn file.
		echo '<ca>' >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		cat /etc/openvpn/easy-rsa/2.0/keys/ca.crt >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		echo '</ca>' >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		
		echo '<cert>' >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		tail -n 30 /etc/openvpn/user/${ovpn_user}/${ovpn_user}.crt >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		echo '</cert>' >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		
		echo '<key>' >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		cat /etc/openvpn/user/${ovpn_user}/${ovpn_user}.key >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		echo '</key>' >> /etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn
		
		# Enter <new username>.ovpn password again & Create Readme.txt.
		read -p "$(echo -e "${B}Please enter the${E} ${R}password${E} ${B}for${E} ${Y}${ovpn_user}${E}${B} certificate:${E}") " readme_text
		echo ${readme_text} >> /etc/openvpn/user/${ovpn_user}/Readme.txt

		# Create archive password & archive file, "-mhe" = Encryption filename extension.
		zip_pw=$(echo Sk@$RANDOM$RANDOM)
		text_file="/etc/openvpn/user/${ovpn_user}/Readme.txt"
		ovpn_file="/etc/openvpn/user/${ovpn_user}/${ovpn_user}.ovpn"
		7z a -mhe -p${zip_pw} ${ovpn_user}.7z ${text_file} ${ovpn_file}

		# Confirm that the archive file copy is successful.
		check_file=$(ls | grep ${new_user}.7z -c || true)
		if [[ ${check_file} == 1 ]];
		then
			true
		else
			echo -e "${Y}${new_user}.7z${E} ${B}does not exist, please check.${E}"
			exit 0
		fi

		# Remove Readme.txt
		rm -f /etc/openvpn/user/${ovpn_user}/Readme.txt
		
		# Show archive file password to screen and finished.
		echo -e "${G}${new_user}.7z${E} ${B}is here.${E}"
		echo -e "${G}${new_user}.7z${E} ${B}password is${E} ${Y}${zip_pw}${E} ${B}, add user finished.${E}"
		break
	elif [[ ${feature_choose} == 2 ]];
	then
		# Confirm user exist.
		check_username=$(ls /etc/openvpn/user | grep ${ovpn_user} -c || true)
		if [[ ${check_username} == 0 ]];
		then
			echo -e "${B}Can not be found${E} ${Y}${ovpn_user}${E}${B} !  please check ${E}${R}/etc/openvpn/user/${E}"
			exit 0
		fi

		# Confirm revoke user.
		read -p "$(echo -e "${R}Are you sure continue revoke${E} ${Y}${ovpn_user}${E}${R} ?(Y/N)${E}") " confirm_revoke
		if [[ ${confirm_revoke} == Y || ${confirm_revoke} == y ]];
		then
			true
		elif [[ ${confirm_revoke} == N || ${confirm_revoke} == n ]];
		then
			echo -e "${B}Bye bye!${E}" 
			exit 0
		else
			echo -e "${B}Please enter Y or N.${E}"
			exit 0
		fi

		# Start revoke user certificate.
		source /etc/openvpn/easy-rsa/2.0/vars
		sh /etc/openvpn/easy-rsa/2.0/revoke-full ${ovpn_user}
		break
	elif [[ ${feature_choose} == D || ${feature_choose} == d ]];
	then
		# Show warning message and confirm continue.
		echo -e "${R}!!!!!WARNING!!!!!${E}"
		echo -e "${R}This option will delete the user certificate!${E}"
		echo -e "${R}Please think twice!${E}"
		echo
		read -p "$(echo -e "${B}Are you sure continue?(Y/N)${E}") " del_confirm

		if [[ ${del_confirm} == Y || ${del_confirm} == y ]];
		then
			true
		elif [[ ${del_confirm} == N || ${del_confirm} == n ]];
		then
			exit 0
		else
			echo -e "${B}Please enter Y or N.${E}"
			exit 0
		fi

		# Confirm user has been revoked. 
		if [[ ${get_user_rm} == 0 ]];
		then
			echo -e "${B}No such user or user ${E}${Y}${ovpn_user}${E}${B} certificate has not revoked.${E}"
			exit 0
		fi

		# Last check, enter "y" is start remove user certificate, enter "n" is stop.
		echo -e "${B}You are now to delete the certificate of ${E}${Y}${ovpn_user}${E}${B},${E}"
		read -p "$(echo -e "${R}Are you sure?(Y/N)${E}") " last_check
		if [[ ${last_check} == Y || ${last_check} == y ]];
		then
			rm -rf /etc/openvpn/user/${ovpn_user}
			rm -f /etc/openvpn/easy-rsa/2.0/keys/${ovpn_user}.*
			echo -e "${B}Delete certificate is done. ${E}"
		else
			echo -e "${B}Okay...you give up.${E}"
			exit 0
		fi
		break
	else
		echo -e "${Y}Please enter options number or D/d,${E}"
		echo -e "${Y}or use Ctrl + C to exit.${E}"
		sleep 2
	fi
	continue
done

