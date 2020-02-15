#!/usr/bin/env fish
#####################################################
# copy using rsync
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

# default values

set rsync_options "-a" "-A" "-X" "-H" "--itemize-changes" "--update" "--delete"

set config_dir '.mirror' # remark: this is interpreted relative to "normal_user"

set options_with_descr \
	'h/help/print help' \
	'p/print-opts/print all options' \
	"s/simulate/emulate copying but do not write any files (except '\$CONFIG_DIR')" \
	'x/exclude=+/exclude these directories/files from copying' \
	'n/non-root=/if specified, logs are owned and written by this user instead of the current one' \
	'c/ssh-conn=/use existing ssh-connection' \
	"d/config-dir=/directory where to save ssh connections. Default: '\$HOME/$config_dir'" \
	"l/log-dir=/where to store log files. Default: '\$CONFIG_DIR/log'" \
	"z/log-file=/log to this file. Default: '\$LOG_DIR/<date>_<time>'" \
	"r/rsync-option=+/set rsync options. Default: $rsync_options"

set options (options_descr_to_argparse $options_with_descr)

#####################################################
# utility functions:
#####################################################

function print_help
	echo "usage: "(status -f)" [OPTIONS...] SRC DST"
	echo "DESCRIPTION:"
	echo "  copy SRC to DST using rsync. Logs and"
	echo "  temporary files are created on local host"
	echo "ARGUMENTS:"
	echo "  SRC, DST: valid paths. One of the locations"
	echo "    may be a remote location given in rsync"
	echo "    syntax (e.g. 'user@host:/some/path')"
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
	if set -q _flag_rsync_option
		set rsync_options $_flag_rsync_option
	end
	if set -q _flag_simulate
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
	# normal_user:
	if set -q _flag_non_root
		set normal_user "$_flag_non_root"
	else
		set normal_user "$USER"
	end
	# config_dir:
	if set -q _flag_config_dir
		set config_dir $_flag_config_dir
	else
		# set up config in the non-root users home:
		set config_dir (as_normal_user eval echo '$HOME'"$config_dir")
	end
	# log_dir, log_file:
	if set -q _flag_log_file
		set log_file $_flag_log_file
		set log_dir (dirname $_flag_log_file)
	else
		if set -q _flag_log_dir
			set log_dir $_flag_log_dir
		else
			set log_dir $config_dir"/log"
		end
		set log_file "$log_dir/$current_date"
	end
	set ssh_socket "$config_dir/copy_ssh-socket-$current_date"
	if set -q _flag_ssh_conn
		set ssh_socket $_flag_ssh_conn
		set ssh_use_existing
	end
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

# create config and log directorys:

# $config_dir is needed even in
# simulate mode to store the
# ssh connection!
as_normal_user mkdir -p -v "$config_dir"

if not set -q simulate
	as_normal_user mkdir -p -v "$log_dir"
end

# the log file should always be excluded
set excluded_dirs $excluded_dirs $log_dir $config_dir 

# echo "log: $log_file"
if not test -e $log_file
	if not set -q simulate
		as_normal_user touch "$log_file"
		output "$current_date: running"(status -f)
		# echo "$current_date: running"(status -f) | to_output
	end
end

# print cmd line arguments:
if set -q _flag_print_opts
	output "source: '$src'"
	output "destination: '$dst'"
	output "config_dir: '$config_dir'"
	output "log dir: '$log_dir'"
	output "rsync_options: '$rsync_options'"
	output "excluded dirs:"
	if set -q excluded_dirs
		for d in $excluded_dirs
			output -e "\t'$d'"
		end
	else
		output "<NONE>"
	end
end

function ssh_exit_trap
	ssh_exit "$ssh_socket" "$remote"
end
trap ssh_exit_trap EXIT

ssh_init "$ssh_socket" "$remote"

# set rsync arguments:
set rsync_args $rsync_options \
	--exclude={$excluded_dirs}
if not set -q simulate
	set rsync_args $rsync_args "--log-file=$log_file"
end
set rsync_args $rsync_args \
	"$src/" \
	"$dst/"

# make shure both machines are synchronous:
if set --query remote
	set -l both_times (with_ssh "$ssh_socket" "$remote" date '+%F_%T'; and date '+%F_%T')
	if test "$both_times[1]" != "$both_times[2]"
		output "ERROR: machines are out of sync! (local time: '$both_times[2]', remote time: '$both_times[1]')"
		exit 1
	end
end

output "executing: 'rsync $rsync_args 2>&1'"
rsync -e "ssh -o ControlPath='$ssh_socket'" $rsync_args 2>&1
and begin
	output "rsync done. all files copied successfully!"
	output (status -f)" done"
	# ssh_exit
	exit 0
end
or begin
	set rsync_ret $status
	output "rsync failed!"
	# ssh_exit
	exit $rsync_ret
end
