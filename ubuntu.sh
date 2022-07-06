#!/bin/bash
#
# write by Aguy

######################## CONF
S_TRACE=debug

S_GLOBAL_FUNCTIONS=${S_GLOBAL_FUNCTIONS:-/usr/local/bs/inc-functions.sh}
! [ -f ${S_GLOBAL_FUNCTIONS} ] && echo "${FUNCNAME}:${LINENO}[error] - unable to find file '${S_GLOBAL_FUNCTIONS}' from ${BASH_SOURCE[0]}" && exit 1
. ${S_GLOBAL_FUNCTIONS}

S_FILE_INSTALL_INI="${S_PATH_CONF}/install.ini" && _confset S_FILE_INSTALL_INI "${S_FILE_INSTALL_INI}"

# load initial configuration to automate settings
. ${S_FILE_INSTALL_INI}

########################  MANDATORY

# common + ssh
parts="init ssh"
for _PART in $parts; do
	! _parthave "${_PART}" "${_FILE_DONE}" && _source "${_PATH_BASE}/sub/${S_RELEASE}-${_PART}.install"
done

########################  MENU

while [ "${_PART}" != "quit" ]; do

	_SDATE=$(date +%s) # renew _SDATE
	partsall="$(sed -n "s|^\t*\(\w\+\)) # .*${S_SERVER_TYPE}.*$|\1|p" "$0" | xargs)"
	partsrelease=" $(ls -1 "${_PATH_BASE}/sub"/*${S_RELEASE}* | sed -n "s|.*${S_RELEASE}-\(.*\)\.install|\1|p" | xargs) "
	partsmade=" $(cat ${_FILE_DONE} | xargs) "
	parts2do=
	for part in $partsall; do
		[ "${partsmade/ $part /}" = "$partsmade" ] && [ "${partsrelease/ $part /}" != "$partsrelease" ] && parts2do+="$part "
	done

	_echod "partsall='$partsall'"
	_echod "partsmade='$partsmade'"
	_echod "parts2do='$parts2do'"

	_echo "Part already made: ${cyanb}$partsmade${cclear}"
	PS3="Give your choice: "
	select _PART in quit $parts2do; do
		case "${_PART}" in
			quit)
				break
				;;
			iptables) # ovh
				_source "${_PATH_BASE}/sub/${S_RELEASE}-${_PART}.install"
				;;
			mail) # ovh
				_source "${_PATH_BASE}/sub/${S_RELEASE}-${_PART}.install"
				;;
			fail2ban) # ovh home
				_source "${_PATH_BASE}/sub/${S_RELEASE}-${_PART}.install"
				;;
			lxd) # ovh home
				_source "${_PATH_BASE}/sub/${S_RELEASE}-${_PART}.install"
				;;
			*)
				_echoE "Wrong option: '${_PART}'"
				;;
		esac
		break
	done

done

_exit

<<KEEP
########################  ZFS
# rescue

zpool import # list pool
zpool import -R /mnt rpool # mount pool
KEEP

<<KEEP
########################  LVM
# rescue

path_save_vm=/dev/mapper/vg-save
path_save="/mnt/save"
path_backup="${path_save}/backup/rescue"
#vols="/dev/sda1 /dev/mapper/vg-lvvar /dev/mapper/vg-lvvz /dev/mapper/vg-lvvzdump /dev/mapper/vg-lvlibvirt"
vols=$(blkid | grep "^/dev/.*TYPE=\"ext4\".*" | sed "s|^\([^:]*\):.*$|\1|" | sed "/save/d")

host="$HOSTNAME"
ddate=$(date +"%Y%m%d")

file="/etc/os-release"
eval "$(grep '^VERSION_ID=' "$file")" # define VERSION_ID
eval "$(grep '^ID=' "$file")" # define VERSION_ID
release="${ID}${VERSION_ID}"

# show
blkid
echo ${vols}

# mount
! [ -d "${path_save}" ] && mkdir -p "${path_save}"
mount ${path_save_vm} "${path_save}"
! [ -d $path_backup ] && mkdir -p $path_backup
cd "${path_backup}"

sudo dd --progress bs=446 count=1 if=/dev/sda of="${host}-${release}-${ddate}-mbr446.iso"
sudo dd --progress bs=512 count=1 if=/dev/sda of="${host}-${release}-${ddate}-mbr.iso"

for vol in ${vols}
do
	echo -e "************************  ${vol}"
	vol_name=${vol#/dev/}; vol_name=${vol_name//\//_}
	e2fsck -f $vol
	dd --progress bs=4096 if=${vol} | gzip > ${host}-$release-${ddate}-${vol_name}.iso.gz
done

# umount
cd
umount /mnt/save

reboot
KEEP

<<KEEP
# restore rescue

path="/mnt/save"
path_backup="${path}/backup/rescue"
# mount
! [ -d "${path}" ] && mkdir -p "${path}"
mount /dev/mapper/vg-lvsave /mnt/save
! [ -d "${path_backup}" ] && mkdir -p "${path_backup}"
cd "${path_backup}"

dd bs=512 count=1 if=ns398616-debian7-20160306-mbrpt.iso of=/dev/sda
gzip -c ns398616-debian7-20160306-sda1.iso.gz | bs=4M status=progress of=/dev/sda1
gzip -c ns398616-debian7-20160306-mapper_vg-lvvar.iso.gz | bs=4M status=progress of=/dev/mapper/vg-lvvar
KEEP
