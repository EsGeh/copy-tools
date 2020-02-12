#!/usr/bin/env fish
#####################################################
# create a backup
# REMARKS:
# - (src and dst given as arguments)
# - call as superuser (necessary to set filemode bits on destination)
# DETAILS:
# - call with "--help" or "-h" for arguments
#####################################################

source (dirname (status -f))/__ct_utils.fish

#####################################################
# variables:
#####################################################

set current_date (date +"%F_%T")
set script_dir (dirname (status -f))

set config_dir '.backup' # default

set options_with_descr \
	'h/help/print help' \
	'p/print-opts/print all options' \
	's/simulate/do not copy files (adds \'--dry-run\' to rsync options)' \
	'x/exclude=+/' \
	'u/user=/non-root user' \
	'c/ssh-conn=/use existing ssh-connection' \
	"d/config-dir=/directory where to save ssh connections. default: '$config_dir' (in users HOME)" \
	"l/log-dir=/where to store log files" \
	"r/rsync-option=+/rsync option to add" \
	"z/break-after=+/for debugging: exit after one of these actions: 'copy'"

set options (options_descr_to_argparse $options_with_descr)

#####################################################
# utility functions:
#####################################################

function print_help
	echo "usage: "(status -f)" [OPTIONS...] SRC DST"
	echo "DESCRIPTION:"
	echo " copies data from SRC to DST. This operation is interruptable, and uses differential backups"
	echo " ! SRC mst be local, DST can be a remote location reachable via ssh"
	echo "DETAILS:"
	echo " - temporary log file: \$log_dir/running_backup.log"
	echo " - temporary destination: \$DST/running_backup"
	echo " after all files have been copied, these files are renamed on the DST:"
	echo "  \$ \$log_dir/running_backup.log -> \$log_dir/\$current_date.log"
	echo "  \$ \$DST/running_backup -> \$DST/\$current_date"
	echo "  \$ ln -v -f -s './\$current_date' '\$DST/last'"
	echo " also, after a successful run the logfiles are copied to DST"
	echo "  scp -o ControlPath=\"\$ssh_socket\" \"\$log_file\" \"\$DST/\""
	echo "OPTIONS:"
	print_options_descr $options_with_descr
end

#####################################################
# actual script:
#####################################################

# parse command line arguments:
argparse $options -- $argv
or begin
	print_help
	exit 1
end
if set -q _flag_h
	print_help
	exit 0
else
	if set -q _flag_exclude
		set excluded_dirs $excluded_dirs $_flag_exclude
	end
	if set -q _flag_simulate
		# set -g _flag_simulate # make flag global!
		set simulate
		set rsync_options $rsync_options "--dry-run"
	end
	# set src and dst:
	if test (count $argv) -ne 2
		print_help
		exit 1
	else
		set src $argv[1]
		set dst $argv[2]
	end
	if set -q _flag_user
		set normal_user $_flag_user
	else
		set normal_user $USER
	end
	if set -q _flag_config_dir
		set config_dir $_flag_config_dir
	else
		# set up config in the non-root users home:
		set config_dir (as_normal_user fish -c "echo ~/$config_dir")
	end
	if set -q _flag_log_dir
		set log_dir $_flag_log_dir
	else
		set log_dir $config_dir"/log"
	end
	if set -q _flag_rsync_option
		set rsync_options $rsync_options $_flag_rsync_option
	end
	set ssh_socket "$config_dir/backup_ssh-socket-$current_date"
	if set -q _flag_ssh_conn
		set ssh_socket $_flag_ssh_conn
		set ssh_use_existing
	end
	set dst_split (parse_ssh_location $dst)
	set dst_path $dst_split[3]
	set --query _flag_break_after; and set break_after $_flag_break_after
end

if location_is_remote "$src"
	if location_is_remote "$dst"
		echo "only one of SRC and DST can be remote!"
		exit 1
	end
	set remote "$src"
else if location_is_remote "$dst"
	set remote $dst
end

# create config and log directorys
# if not set -q simulate
	as_normal_user mkdir -p -v "$config_dir"
# end

if not set -q simulate
	as_normal_user mkdir -p -v "$log_dir"
end
set log_file "$log_dir/running_backup.log"

# echo "log: $log_file"
if test -e $log_file
	output "update not finished last time. continuing..."
else
	if not set -q simulate
		touch "$log_file"
	end
end

function ssh_exit_trap
	ssh_exit "$ssh_socket" "$remote"
end
trap ssh_exit_trap EXIT

ssh_init "$ssh_socket" "$remote"

# check if we can use links to the last backup:
set last_backup (with_ssh "$ssh_socket" "$dst" readlink -s "$dst_path/last")
and begin
	output "older backup found. creating differential backup..."
	## --link-dest is relative to the destination directory!
	set rsync_options $rsync_options "--link-dest=../$last_backup"
end
or output "no previous backup found!"

# create backup on remote:
# set all_args $rsync_options \
	# --exclude={$excluded_dirs} \
	# "$src" \
	# "$dst/running_backup"

# create dest dir if not existing:
if not set -q simulate
	with_ssh "ssh_socket" "$dst" mkdir -vp "$dst_path/running_backup" | to_output
else
	echo "executing 'mkdir -vp \"$dst_path/running_backup\" | to_output'"
end

set copy_options \
	--print-opts \
	--user=$normal_user \
	--ssh-conn=$ssh_socket \
	--config-dir=$config_dir \
	--log-file=$log_file \
	--exclude={$excluded_dirs} \
	--rsync-option={$rsync_options}

if set -q simulate
	set copy_options $copy_options "--simulate"
end

# output "executing: 'rsync $all_args 2>&1 | tee --append $log_file'"
output "running: '$script_dir/copy.fish $copy_options $src $dst/running_backup'"

$script_dir/ct-copy.fish $copy_options "$src" "$dst/running_backup"
if test "$break_after" = 'copy'
	exit
end
if test $status -eq 0
	output "copy SUCCESS"
	if not set -q simulate
		set old_log "$log_file"
		set log_file "$log_dir/$current_date".log
		# set log_file "$log_file"_"$current_date".log
		as_normal_user mv -v "$old_log" "$log_file" | to_output

		# on remote: rename backup, create softlink to the last backup:
		set on_remote "if test -e '$dst_path/running_backup'; then mv -v '$dst_path/running_backup' '$dst_path/$current_date'; fi && rm -f '$dst_path/last' && ln -v -f -s './$current_date' '$dst_path/last'"
		# output "on remote: $on_remote"
		echo "$on_remote" | with_ssh "$ssh_socket" "$dst" bash | to_output
		output (status -f)" done"
	end
else
	output "copy FAILED!"
end

# copy logfile to destination directory:
if not set -q simulate
	scp -o ControlPath="$ssh_socket" "$log_file" "$dst/"
end
