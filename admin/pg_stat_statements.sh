#!/bin/bash

hoSt=${hoSt:-"pi@pi"}
Stack=${Stack:-"hubzilla"}

DB_option=pg_stat_statements

help() {
	cat <<ENDH
$0 {enable|disable|*report*}
enable : Enable $DB_option
disable: Disable $DB_option
report : Output a basic 
ENDH
}

Sudo() {		ssh "$hoSt" sudo "$@" ; }
DockeR() {		ssh "$hoSt" sudo docker "$@"; }
getCont() {		DockeR stack ps ${Stack} -f name=${Stack}_${1}.1 --no-trunc|awk -v N=${Stack}_${1}.1 '$2==N{print $1}'; }
getVolumePath() {	DockeR volume inspect $1 --format '{{.Mountpoint}}'; }
stamp() { 		date '+%Y%m%d_%H%M%S'; }
task() {		local p=$(awk -v c=$((38-$(echo "$@"|wc -c)/2)) 'BEGIN{for(i=0;i<c;i++) printf "=" }'); echo "$p $@ $(awk -v c=$((79-$(echo $p|wc -c)-$(echo "$@"|wc -c))) 'BEGIN{for(i=0;i<c;i++) printf "=" }')"; }
sql() {
	local cont=$1;shift;
	local opts=$1;shift;
	DockeR exec -i $cont su - postgres -c "'psql $opts'"
}

error() {		echo "ERROR: $@">&2 ; }


delStatConf() {
	Sudo sed -i '/pg_stat_statements/d' "$1/postgresql.conf"
}
addStatConf() {
	delStatConf $1
	Sudo tee -a "$1/postgresql.conf" <<END
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.max = 10000
pg_stat_statements.track = all
END
}
enable_statement() {
	task "Get $Stack database volume path" 
	local v=$(getVolumePath hubzilla_voldb)
	task "Activate $DB_option in postgresql.conf"
	addStatConf $v
	task "Get postgres container ID"
	local id=$(getCont postgres)
	task "Reload postgres configuration"
	DockeR exec -i "${Stack}_postgres.1.$id" su - postgres -c "'pg_ctl reload -D /var/lib/postgresql/data'"
	task "Create $DB_option extention in the database"
	echo "CREATE EXTENSION pg_stat_statements"|sql "${Stack}_postgres.1.$id" "-U hubzilla -d hub -t"
}
disable_statement() {
	task "Get postgres container ID"
	local id=$(getCont postgres)
	task "Drop $DB_option extention in the database"
	echo "DROP EXTENSION pg_stat_statements"|sql "${Stack}_postgres.1.$id" "-U hubzilla -d hub -t"
	task "Get $Stack database volume path" 
	local v=$(getVolumePath hubzilla_voldb)
	task "Disable $DB_option in postgresql.conf"
	delStatConf $v
	task "Reload postgres configuration"
	DockeR exec -i "${Stack}_postgres.1.$id" su - postgres -c "'pg_ctl reload -D /var/lib/postgresql/data'"
}
report_statement() {
	task "Get postgres container ID"
	local id=$(getCont postgres)
	task "Generate the report"
	sql "${Stack}_postgres.1.$id" "-U hubzilla -d hub -t" <<ENDSQL
\x
SELECT query, calls, total_time, rows, 100.0 * shared_blks_hit /
               nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
          FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;
ENDSQL
}


case "$1" in
report|"")	report_statement;;
enable)		enable_statement;;
disable)	disable_statement;;
*)		error "$1 switch not supported"
		help
		exit 3;;
esac
