#!/bin/bash

# Setting the execution environment, debug: set -xeo pipefail
set -eo pipefail

# Definition color; E = Color end
R="\e[1;91m"
G="\e[1;92m"
Y="\e[1;93m"
B="\e[1;96m"
E="\e[0m"

# Check script location.
now_dir=$(pwd)
rsa_dir='/etc/openvpn/easy-rsa/2.0'
if [[ ${now_dir} == ${rsa_dir} ]];
then
	true
else
	echo -e "${B}This script is not in${E} ${R}/etc/openvpn/easy-rsa/2.0/${E}"
	echo -e "${B}Please move this script to${E} ${R}/etc/openvpn/easy-rsa/2.0/${E} ${B}and execute.${E}"
	exit 0
fi

# Check system virsion and package.
os=$(lsb_release -irs | xargs)
if [[ ${os} == 'CentOS '* ]];
then
	check_rpm=$(rpm -qa | grep p7zip -c || true)
	if [[ ${check_rpm} == 2 ]];
	then
		true
	else
		yum install p7zip p7zip-plugins -y
	fi
elif [[ ${os} == 'Ubuntu '* ]];
then
	check_dpkg=$(dpkg --get-selections | grep p7zip -c || true)
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

# Select Add, Revoke or search user.
# If the question option is entered incorrectly, it will be asked again.
while read -p "
$(echo -e "${Y}0${E} > ${G}Search user${E}")
$(echo -e "${Y}1${E} > ${G}Add user${E}")
$(echo -e "${Y}2${E} > ${R}Revoke user${E}")
$(echo -e "${Y}D/d${E} > ${R}Delete user certificate${E}")

$(echo -e "${B}Please choose one >${E}") " feature_choose

do
	if [[ ${feature_choose} == 0 ]];
	then
		# Enter user name.
		# get_user_avl: avl = available; get_user_rm: rm = remove
		# "grep -w" = Select only those lines containing matches that form  whole words.
		read -p "$(echo -e "${B}Please enter the user name of the search:${E}") " ovpn_user
		search_user_file=$(ls /etc/openvpn/easy-rsa/2.0/keys/ | grep ${ovpn_user}.key -c || true)
		get_user_avl=$(cat /etc/openvpn/easy-rsa/2.0/keys/index.txt | grep -w "${ovpn_user}" | grep "V" | wc -l || true)
		get_user_rm=$(cat /etc/openvpn/easy-rsa/2.0/keys/index.txt | grep -w "${ovpn_user}" | grep "R" | wc -l || true)

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
		# Enter new user name.
		read -p "$(echo -e "${B}Please enter the name of the new user:${E}") " new_user

		# Confirm that the user has not been created.
		check_username=$(ls /etc/openvpn/easy-rsa/2.0/keys/ | grep ${new_user}.key -c || true)
		if [[ ${check_username} == 0 ]];
		then
			true
		else
			echo -e "${B}Find same user:${E} ${Y}${new_user}${E}${B} !  please check ${E}${R}/etc/openvpn/user/${E}"
			exit 0
		fi

		# Randomly generate certificate password.
		char_1=$(echo ${new_user} | cut -c1)
		char_cap_1=$(echo ${new_user} | cut -c1 | tr '[:lower:]' '[:upper:]')
		char_2=$(echo ${new_user} | cut -c2)
		py_pass=$(python pass-generator.py)
		cert_pass=$(echo ${char_1}${char_2}${py_pass}${char_cap_1}${char_2})
		echo -e "${B}Recommended certificate password:${E} ${Y}${cert_pass}${E}"

		# Start create new user <new username>.ovpn file.
		source /etc/openvpn/easy-rsa/2.0/vars
		sh /etc/openvpn/easy-rsa/2.0/build-key-pass ${new_user}
				
		# Make new user folder for certificate file.
		mkdir /etc/openvpn/user/${new_user}
				
		# Copy new user certificate file to /etc/openvpn/user/<new username>
		\cp /etc/openvpn/easy-rsa/2.0/keys/${new_user}.* /etc/openvpn/user/${new_user}
				
		# Copy OpenVPN config to new user <new username>.ovpn file.
		head -n 14 /etc/openvpn/user/sample/sample.ovpn >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		
		# Copy new user certificate to <new username>.ovpn file.
		echo '<ca>' >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		cat /etc/openvpn/easy-rsa/2.0/keys/ca.crt >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		echo '</ca>' >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		
		echo '<cert>' >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		tail -n 30 /etc/openvpn/user/${new_user}/${new_user}.crt >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		echo '</cert>' >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		
		echo '<key>' >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		cat /etc/openvpn/user/${new_user}/${new_user}.key >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		echo '</key>' >> /etc/openvpn/user/${new_user}/${new_user}.ovpn
		
		# Enter <new username>.ovpn password again & Create Readme.txt.
		read -p "$(echo -e "${B}Please enter the${E} ${R}password${E} ${B}for${E} ${Y}${new_user}${E}${B} certificate:${E}") " readme_text
		echo ${readme_text} >> /etc/openvpn/user/${new_user}/Readme.txt

		# Create archive password & archive file, "-mhe" = Encryption filename extension.
		zip_pw=$(echo Sk@$RANDOM$RANDOM)
		text_file="/etc/openvpn/user/${new_user}/Readme.txt"
		ovpn_file="/etc/openvpn/user/${new_user}/${new_user}.ovpn"
		7z a -mhe -p${zip_pw} ${new_user}.7z ${text_file} ${ovpn_file}

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
		rm -f /etc/openvpn/user/${new_user}/Readme.txt
		
		# Show archive file password to screen and finished.
		echo -e "${G}${new_user}.7z${E} ${B}is here.${E}"
		echo -e "${G}${new_user}.7z${E} ${B}password is${E} ${Y}${zip_pw}${E} ${B}, add user finished.${E}"
		break
	elif [[ ${feature_choose} == 2 ]];
	then
		# Enter name.
		read -p "$(echo -e "${B}Please enter the user want to revoke:${E}") " revoke_user
		
		# Confirm user exist.
		heck_username=$(ls /etc/openvpn/user | grep ${revoke_user} -c || true)
		if [[ ${check_username} == 1 ]];
		then
			true
		else
			echo -e "${B}Can not be found${E} ${Y}${revoke_user}${E}${B} !  please check ${E}${R}/etc/openvpn/user/${E}"
			exit 0
		fi

		# Confirm revoke user.
		read -p "$(echo -e "${R}Are you sure continue revoke${E} ${Y}${revoke_user}${E}${R} ?(Y/N)${E}") " confirm_revoke
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
		sh /etc/openvpn/easy-rsa/2.0/revoke-full ${revoke_user}
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
		else
			exit 0
		fi

		# Enter certificate name.
		read -p "$(echo -e "${B}Please enter the user want to delete certificate:${E}") " del_name

		# Last check, enter "y" is start remove user certificate, enter "n" is stop.
		echo -e "${B}You are about to delete the certificate of ${Y}${del_name}${E}${B},${E}"
		read -p "$(echo -e "${R}Are you sure?(Y/N)${E}") " last_check
		if [[ ${last_check} == Y || ${last_check} == y ]];
		then
			rm -rf /etc/openvpn/user/${del_name}
			rm -f /etc/openvpn/easy-rsa/2.0/keys/${del_name}.*
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

