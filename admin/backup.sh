#!/bin/bash

BackupDir=${BackupDir:-"$(pwd)"}
hoSt=${hoSt:-"pi@pi"}
Stack=${Stack:-"hubzilla"}
isFull=${isFull:-"no"}
help() {
	cat <<ENDH
$0 [ -s *hubzilla*|ldap|prosody|all ] [ -f ] [ -h hostname ] [ -b backupDir ]
-h	: Choose which host to connect to	(default: ${hoSt} ; that user need sudo permision)
-b	: Local backup directory		(default: ${BackupDir})
-s	: Select the stack to backup		(default: $Stack)
-f	: Force a full Backup			(default: $isFull)
ENDH
}

DockeR() {		ssh "$hoSt" sudo docker "$@"; }
getCont() {		DockeR stack ps ${Stack} -f name=${Stack}_${1}.1 --no-trunc|awk -v N=${Stack}_${1}.1 '$2==N{print $1}'; }
getVolumePath() {	DockeR volume inspect $1 --format '{{.Mountpoint}}'; }
TaR() {			ssh "$hoSt" sudo tar -C "$1" -cz .; }
stamp() { 		date '+%Y%m%d_%H%M%S'; }
task() {		local p=$(awk -v c=$((38-$(echo "$@"|wc -c)/2)) 'BEGIN{for(i=0;i<c;i++) printf "=" }'); echo "$p $@ $(awk -v c=$((79-$(echo $p|wc -c)-$(echo "$@"|wc -c))) 'BEGIN{for(i=0;i<c;i++) printf "=" }')"; }
error() {		echo "ERROR: $@">&2 ; }

backup_hubzilla() {
	Stack=hubzilla
	local Svc=postgres
	local SvcApp=$Stack
	local User=hubzilla
	local DbName=hub
	local VolDb=${Stack}_voldb
	local VolWeb=${Stack}_volweb
	if [ "$isFull" != "no" ];then
		task "Stop the hubzilla containers"
		DockeR service scale ${Stack}_${Svc}=0 ${Stack}_${SvcApp}=0 ${Stack}_nginx=0
		task "Get the postgres volume path"
		local voL=$(getVolumePath $VolDb)
		task "Backing up the database volume"
		TaR "$voL" >$BackupDir/${Stack}_backup_full_db_${Stamp}.tar.gz
		task "Start the database"
		DockeR service scale ${Stack}_${Svc}=1
	else
		task "Get database container ID"
		local Cont=$(getCont $Svc)
		task "Backing up the database (sql)"
		DockeR exec -i ${Stack}_${Svc}.1.$Cont su - postgres -c "'pg_dump -U $User -d $DbName'" >$BackupDir/${Stack}_backup_${Stamp}.sql
	fi

	task "Get the ${Stack} volume path"
	local voLw=$(getVolumePath $VolWeb)
	task "Backing up the ${Stack} volume"
	TaR "$voLw" >$BackupDir/${Stack}_backup_full_web_${Stamp}.tar.gz
	if [ "$isFull" != "no" ];then
		task "Start $Stack"
		DockeR service scale ${Stack}_${SvcApp}=1 ${Stack}_nginx=1
	fi
}

backup_ldap() {
	Stack=ldap
	local Svc=$Stack
	local SvcApp=fusiondirectory
	local VolData=${Stack}_data
	local VolConf=${Stack}_conf
	local VolWeb=${Stack}_web
	if [ "$isFull" != "no" ];then
		task "Stop the LDAP containers"
		DockeR service scale ${Stack}_${Svc}=0 ${Stack}_${SvcApp}=0 ${Stack}_nginx=0
		task "Get the openLDAP data volume path"
		local voL=$(getVolumePath $VolData)
		task "Backing up the openLDAP data volume"
		TaR "$voL" >$BackupDir/${Stack}_backup_full_data_${Stamp}.tar.gz
		task "Get the openLDAP config volume path"
		local voL=$(getVolumePath $VolConf)
		task "Backing up the openLDAP config volume"
		TaR "$voL" >$BackupDir/${Stack}_backup_full_conf_${Stamp}.tar.gz
		task "Start the directory"
		DockeR service scale ${Stack}_${Svc}=1
		task "Start $SvcApp"
		DockeR service scale ${Stack}_${SvcApp}=1 ${Stack}_nginx=1
	else
		task "Get openLDAP container ID"
		local Cont=$(getCont $Svc)
		task "Backing up the directory configuration (ldif)"
		DockeR exec -i ${Stack}_${Svc}.1.$Cont slapcat -F /etc/ldap/slapd.d/ -n 0 >$BackupDir/${Stack}_backup_conf_${Stamp}.ldif
		task "Backing up the directory data (ldif)"
		DockeR exec -i ${Stack}_${Svc}.1.$Cont slapcat >$BackupDir/${Stack}_backup_data_${Stamp}.ldif
	fi
}

backup_prosody() {
	Stack=prosody
	local Vol=${Stack}_data
	task "Get the ${Stack} volume path"
	local voL=$(getVolumePath $Vol)
	task "Backing up the ${Stack} volume"
	TaR "$voL" >$BackupDir/${Stack}_backup_data_$(stamp).tar.gz
}

Stamp=$(stamp)
while [ $# -ne 0 ];do
case $1 in
-s)
	shift;
	case "$1" in
	hubzilla|ldap|prosody|all)	Stack=${1:-"$Stack"};
	esac;;
-f)	isFull=yes;;
-b)	shift;
	BackupDir=${1:-"$BackupDir"};;
-h)	shift;
	if [ $# -eq 0 ];then
		error "-h need an argument"
		help
		exit 1
	fi
	hoSt=${1:-"$hoSt"};;
*)	error "$1 is not a valid argument"
	help
	exit 1;;
esac
shift;
done

if ! mkdir -p "$BackupDir";then
	echo Cannot create $BackupDir
	exit 2
fi

case "$Stack" in
hubzilla)	backup_hubzilla;;
ldap)		backup_ldap;;
prosody)	backup_prosody;;
all)		backup_hubzilla
		backup_ldap
		backup_prosody;;
*)		error "$Stack not known"
		help
		exit 3;;
esac
