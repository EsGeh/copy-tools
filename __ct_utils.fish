#!/usr/bin/env fish


# variables:
# normal_user
# log_file
# simulate

#####################################################
# ssh utils:
#####################################################

# create or reuse ssh connection to LOCATION
# args:
# - socket_name
# - location
function ssh_init \
		--argument-names socket location
	if location_is_remote $location
		if set -q ssh_use_existing
			output "using existing ssh-connection"
		else
			# open ssh connection and keep it open:
			set -l login (ssh_location_to_ssh_login $location)
			output "opening ssh connection to '$login' (socket: '$socket')"
			ssh -nNf -o ControlMaster=yes -o ControlPath="$socket" "$login"
		end
	end
end

# possible usage:
# $ echo "echo bla" | with_ssh
# or
# $ with_ssh echo bla
function with_ssh \
		--argument-names socket location
	if location_is_remote $location
		set -l login (ssh_location_to_ssh_login $location)
		ssh -o ControlPath="$socket" "$login" $argv[3..-1]
	else
		if test (count $argv) != 2
			bash -c "$argv[3..-1]"
		else
			cat - | bash
		end
	end
end

# exit ssh connection
function ssh_exit \
		--argument-names socket location
	if location_is_remote $location
		if not set -q ssh_use_existing
			if test -e "$socket"
				set -l login (ssh_location_to_ssh_login $location)
				output "closing ssh connection to '$login' (socket: '$socket')"
				ssh -O exit -o ControlPath="$socket" "$login" 2> /dev/null
			end
		end
	end
end

# usage: output <things> <to> <output>
function output
	echo $argv | to_output
end

# usage: "... | to_output"
function to_output
	if not set -q simulate
		as_normal_user tee --append "$log_file"
	else
		cat -
	end
end

# usage: "as_normal_user <cmd> <args>"
function as_normal_user
	sudo -u "$normal_user" $argv
end

function location_is_remote
	string split ':' "$argv[1]" > /dev/null
	test $status -eq 0
end

# parse [user@]host
# returns a list with 2 entries: user host
function parse_ssh_host
	set user_and_host (string split '@' $argv[1])
	if test "$status" -ne 0
		set ret '' $argv[1]
	else
		set ret $user_and_host
	end
	for x in $ret; echo $x; end
end

# precond
# e.g.: user@host:path -> user@host
function ssh_location_to_ssh_login \
		--argument-names location
	set split_res (string split ':' $location)
	echo $split_res[1]
end

# accepts 2 formats:
# 1. just a path, e.g. /etc/bla
# 2. remote location, e.g. [user@]host:[path]
# returns a list with 3 entries: user host path
# (some might be empty)
function parse_ssh_location
	set host_and_path (string split ':' $argv[1])
	if test "$status" -eq 0
		set path $host_and_path[2]
		set user_and_host_str $host_and_path[1]
		set user_and_host (string split '@' $user_and_host_str)
		if test "$status" -eq 0
			set user $user_and_host[1]
			set host $user_and_host[2]
		else
			set user ''
			set host $user_and_host_str
		end
	else
		set user ''
		set host ''
		set path "$argv[1]"
	end
	echo $user
	echo $host
	echo $path
end

# assemble 'user' 'host' 'path' into 
# a valid argument for ssh or scp
function assemble_ssh_location
	argparse \
		'u/user=' \
		'h/host=' \
		'p/path=' \
		-- \
		$argv
	or begin
		echo "error in argparse"
		return 1
	end
	set -q _flag_user; and set user $_flag_user
	set -q _flag_host; and set host $_flag_host
	set -q _flag_path; and set path $_flag_path

	if begin
			test "$user" = ""
			and test "$host" = ""
			and test "$path" != ""
		end
		echo "$path"
	else if test "$host" != ""
		set ret ""
		if test "$user" != ""
			set ret "$user@"
		end
		set ret "$ret$host"
		if test "$path" != ""
			set ret "$ret:$path"
		end
		echo $ret
	else
		echo "assemble_ssh_location: invalid arguments"
		return 1
	end
end
