#!/bin/bash
# Release v5.2 ; last upsate: 20240612

# Set the execution environment, debug: set -xeo pipefail
set -eo pipefail

# Define the color; E = Color end
R="\e[1;91m"
G="\e[1;92m"
Y="\e[1;93m"
B="\e[1;96m"
E="\e[0m"

# Chenge the script execution folder.
cd /etc/openvpn/easy-rsa/

# Check the system version and package.
os=$(lsb_release -irs | xargs)
if [[ ${os} == 'Ubuntu '* ]];
then
	check_dpkg=$(dpkg --get-selections | grep -E "p7zip|cifs" -c || true)
	if [[ ${check_dpkg} == 2 ]];
	then
		true
	else
		apt-get install 7zip cifs-utils -y
	fi
else
	echo -e "${R}This system is not Ubuntu!${E}"
	echo -e "${R}Please check your system.${E}"
	exit 0
fi

# Used when creating user ovpn files.
ovpn_config_head=$(echo 'client
dev tun
proto udp4
remote vpn2.bridgewell.com 1194
remote vpn.bridgewell.com 1194
nobind
persist-key
persist-tun
verb 3

cipher AES-256-GCM
auth SHA512
')

# Select Add, Revoke or search user.
# If the incorrect option is entered, it will be asked again.
while read -p "
$(echo -e "${Y}0${E} > ${G}Search user${E}")
$(echo -e "${Y}1${E} > ${G}Add user${E}")
$(echo -e "${Y}2${E} > ${R}Revoke user${E}")
$(echo -e "${Y}D/d${E} > ${R}Delete user certificate${E}")

$(echo -e "${B}Please choose one >${E}") " feature_choose

# Enter the user name.
read -p "$(echo -e "${B}Please enter the user name:${E}") " ovpn_user

# get_user_avl: avl = available ; get_user_rm: rm = remove
# "grep -c" = Suppress normal output; instead print a count of matching lines for each input file.
get_user_avl=$(cat /etc/openvpn/easy-rsa/pki/index.txt | grep "=${ovpn_user}" | grep "V" -c || true)
get_user_rm=$(cat /etc/openvpn/easy-rsa/pki/index.txt | grep "=${ovpn_user}" | grep "R" -c || true)

do
	if [[ ${feature_choose} == 0 ]];
	then
		search_user_file=$(ls /etc/openvpn/easy-rsa/pki/private/ | grep -wc ${ovpn_user}.key || true)

		echo -e "User name: ${Y}${ovpn_user}${E}"

		# Check user files.
		if [[ ${search_user_file} == 1 ]];
		then
			echo -e "File exists: ${G}Ｏ${E}"
		else
			echo -e "File exists: ${R}Ｘ${E}"
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
			echo -e "Available: ${R}not exists!${E}"
		fi
		break
	elif [[ ${feature_choose} == 1 ]];
	then
		# Confirm whether the user has been created.
		check_username=$(ls /etc/openvpn/easy-rsa/pki/private/ | grep ${ovpn_user}.key -c || true)
		if [[ ${check_username} == 1 ]];
		then
			echo -e "${B}Find the same user:${E} ${Y}${ovpn_user}${E}${B} !  please check ${E}${R}/etc/openvpn/client/${E}"
			exit 0
		fi

		# Randomly generate a certificate password.
		char_1=$(echo ${ovpn_user} | cut -c1)
		char_cap_1=$(echo ${ovpn_user} | cut -c1 | tr '[:lower:]' '[:upper:]')
		char_2=$(echo ${ovpn_user} | cut -c2)
		py_pass=$(python3 ~/pass-generator.py)
		cert_pass=$(echo ${char_1}${char_2}${py_pass}${char_cap_1}${char_2})
		echo -e "${B}Recommended certificate password:${E} ${Y}${cert_pass}${E}"

		# Start creating new user <new username>.ovpn files.
		sh /etc/openvpn/easy-rsa/easyrsa build-client-full ${ovpn_user}
		
		# Create folders for new user.
		user_folder='/etc/openvpn/client/'
		mkdir ${user_folder}${ovpn_user}
				
		# Copy the new user certificate file to /etc/openvpn/clinet/<new username>
		\cp -rp /etc/openvpn/easy-rsa/pki/{ca.crt,issued/${ovpn_user}.crt,private/${ovpn_user}.key} ${user_folder}${ovpn_user}
				
		# Copy the OpenVPN config to <new username>.ovpn file.
		echo -e "${ovpn_config_head}\n" >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		
		# Copy the new user certificate to <new username>.ovpn file.
		echo '<ca>' >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		cat ${user_folder}${ovpn_user}/ca.crt >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		echo '</ca>' >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		
		echo '<cert>' >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		cat ${user_folder}${ovpn_user}/${ovpn_user}.crt | grep -A22 'BEGIN' >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		echo '</cert>' >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		
		echo '<key>' >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		cat ${user_folder}${ovpn_user}/${ovpn_user}.key >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		echo '</key>' >> ${user_folder}${ovpn_user}/${ovpn_user}.ovpn
		
		# Enter the password of <new username>.ovpn again & create Readme.txt.
		read -p "$(echo -e "${B}Please enter the${E} ${R}certificate password${E} ${B}of${E} ${Y}${ovpn_user}${E}${B} :${E}") " readme_text
		echo ${readme_text} >> ${user_folder}${ovpn_user}/Readme.txt

		# Create archive password & archive file, "-mhe" = Encryption filename extension.
		zip_pw=$(echo pw@$RANDOM$RANDOM)
		text_file="${user_folder}${ovpn_user}/Readme.txt"
		ovpn_file="${user_folder}${ovpn_user}/${ovpn_user}.ovpn"
		#7zz a -mhe -p${zip_pw} ${ovpn_user}.7z ${text_file} ${ovpn_file}
		7zz a -p${zip_pw} ${ovpn_user}.7z ${text_file} ${ovpn_file}

		# Make dir /mnt/i
		mount_dir=$(ls /mnt/ | grep i -c || true)
		if [[ ${mount_dir} == 0 ]];
		then
			mkdir /mnt/data
		fi

		# Mount coco/i
		mount.cifs //smaba/data /mnt/data -o guest,vers=2.0
		
		# Copy the archive file to coco folder.
		\cp ${ovpn_user}.7z /mnt/data/OpenVPN_package/

		# Confirm that the archive file has been successfully copied.
		check_file=$(ls /mnt/data/OpenVPN_package/ | grep ${ovpn_user}.7z -c || true)
		if [[ ${check_file} == 1 ]];
		then
			rm -f ${ovpn_user}.7z
		else
			echo -e "${Y}${ovpn_user}.7z${E} ${B}does not exist in${E} ${R}/mnt/i/USER/Starck/OpenVPN_package/${E}"
			echo -e "${B}Please manually copy the archive file to coco & Remove${E} ${R}/etc/openvpn/client/${ovpn_user}/Readme.txt${E}"
			echo -e "${B}Remember umount${E} ${R}/mnt/i${E}"
			exit 0
		fi

		# Remove Readme.txt
		rm -f ${user_folder}${ovpn_user}/Readme.txt

		# Umount coco.
		umount /mnt/i
		
		# Show the archive file password to the screen and finished.
		win_coco_vpn_dir=$(echo '\\\\samba\data\OpenVPN_package\')
		echo -e "${G}${ovpn_user}.7z${E} ${B}has been copied to${E} ${R}${win_coco_vpn_dir} ${E}"
		echo -e "${G}${ovpn_user}.7z${E} ${B}password is${E} ${Y}${zip_pw}${E} ${B}, add user finished.${E}"
		break
	elif [[ ${feature_choose} == 2 ]];
	then
		# Confirm the existence of users.
		check_username=$(ls /etc/openvpn/client/ | grep ${ovpn_user} -c || true)
		if [[ ${check_username} == 0 ]];
		then
			echo -e "${B}Can't find${E} ${Y}${ovpn_user}${E}${B} !  please check ${E}${R}/etc/openvpn/client/${E}"
			exit 0
		fi

		# Confirm the revoke of users.
		read -p "$(echo -e "${R}Are you sure want to continue to revoke${E} ${Y}${ovpn_user}${E}${R} ?(Y/N)${E}") " confirm_revoke
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

		# Start to revoke the user certificate.
		sh /etc/openvpn/easy-rsa/easyrsa revoke ${ovpn_user}
		sh /etc/openvpn/easy-rsa/easyrsa gen-crl
		break
	elif [[ ${feature_choose} == D || ${feature_choose} == d ]];
	then
		# Show warning messages and confirm to continue.
		echo -e "${R}!!!!!WARNING!!!!!${E}"
		echo -e "${R}This option will delete the user's certificate!${E}"
		echo -e "${R}Please think twice!${E}"
		echo
		read -p "$(echo -e "${B}Are you sure want to continue?(Y/N)${E}") " del_confirm

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

		# Confirm that the user has been revoked. 
		if [[ ${get_user_rm} == 0 ]];
		then
			echo -e "${B}No such user or the user ${E}${Y}${ovpn_user}${E}${B} certificate has not been revoked.${E}"
			exit 0
		fi

		# Finally confirm the enter "y" to start removeing the user certificate, and enter "n" to stop.
		echo -e "${B}You are going to delete the certificate of ${E}${Y}${ovpn_user}${E}${B} now,${E}"
		read -p "$(echo -e "${R}Are you sure?(Y/N)${E}") " last_check
		if [[ ${last_check} == Y || ${last_check} == y ]];
		then
			rm -rf /etc/openvpn/client/${ovpn_user}
			rm -f /etc/openvpn/easy-rsa/{issued/${ovpn_user}.crt,private/${ovpn_user}.key}
			echo -e "${B}The deletion certificate has been finished. ${E}"
		else
			echo -e "${B}Okay...good choice.${E}"
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

