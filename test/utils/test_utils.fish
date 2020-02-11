# test utilities to be included via 'source'

###################################
# test utils:
###################################

function output
	if set --query verbose
		if test (count $argv) -ne 0
			echo $argv | indent 1>&2
		else
			cat - | indent 1>&2
		end
	end
end

function indent
	set old_status $status
	if test "$argv[1]" != ""
		set ind "$argv[1]"
	else
		set ind '  '
	end
	cat - | sed "s/^/$ind/"
	return $old_status
end

function ls_ext
	set login_and_path (location_to_login_and_path "$argv[1]")
	if test "$status" -eq 0
		ssh "$login_and_path[1]" ls -A "$login_and_path[2]"
	else
		ls -A "$argv[1]"
	end
end

function tree_ext
	set login_and_path (location_to_login_and_path "$argv[1]")
	if test "$status" -eq 0
		ssh "$login_and_path[1]" tree "$login_and_path[2]"
	else
		tree "$argv[1]"
	end
end

function mkdir_ext
	set login_and_path (location_to_login_and_path "$argv[1]")
	if test "$status" -eq 0
		ssh "$login_and_path[1]" mkdir "$login_and_path[2]"
	else
		mkdir "$argv[1]"
	end
end

function write_to_file_ext \
	--argument-names content dst
	set login_and_path (location_to_login_and_path "$dst")
	if test "$status" -eq 0
		ssh "$login_and_path[1]" bash -c "echo $content > '$login_and_path[2]'"
	else
		echo $content > $dst
	end
end

function location_to_login_and_path
	set login_and_path (string split --max 1 ':' "$argv[1]")
	if begin
			test $status -eq 0
			and not string match '*/*' "$login_and_path[1]"
		end
		echo $login_and_path[1]
		echo $login_and_path[2]
	else
		return 1
	end
end

# function maybe_with_ssh
# 	argparse --stop-nonopt "l/location=" -- $argv
# 	or begin
# 		echo "In 'maybe_with_ssh': ERROR parsing args"
# 		return 1
# 	end
# 	if set --query _flag_location
# 		set location $_flag_location
# 	end
# 	set login_and_path (location_to_login_and_path "$location")
# 	if test $status -eq 0
# 		set login "$login_and_path[1]"
# 		set path "$login_and_path[2]"
# 		ssh $login $argv
# 	else
# 		$argv
# 		# eval "$cmd $path"
# 	end
# end

function diff_ext --argument-names dir1 dir2
	# if begin
	# 		not string split ':' $dir1
	# 		and not string split ':' $dir2
	# 	end
	# 	diff -q $argv
	# 	return $status
	# else

	# this should list all differences:
	set tmp_file (mktemp)
	rsync --dry-run -ar --delete --itemize-changes "$dir1/" "$dir2/" > $tmp_file
	if test (wc --lines < "$tmp_file") -eq 0
		rm "$tmp_file"
		return 0
	else
		echo "differences:"
		cat "$tmp_file"
		rm "$tmp_file"
		return 1
	end
end

function run_with_output
	set tmp_output (mktemp)
	output "executing '$argv'"
	$argv > $tmp_output
	and begin
		if set --query verbose
			output "output:"
			cat $tmp_output | indent '  > '
		end
		rm $tmp_output
	end
	or begin
		echo "command failed"
		if set --query verbose
			output "output:"
			cat $tmp_output | indent '  > '
		end
		rm $tmp_output
		return 1
	end
end

# argv: tests to be run
function exec_tests
	argparse \
		"s/remote-src=" \
		"d/remote-dst=" \
		-- \
		$argv
	or begin
		echo "In exec_tests: ERROR parsing argumnets"
		return 1
	end
	set remote_src "$_flag_remote_src"
	set remote_dst "$_flag_remote_dst"
	if begin
			test "$remote_src" != ""
			and test "$remote_dst" != ""
		end
		echo "In exec_tests: ERROR: only one of src or dst can be remote!"
		return 1
	end
	set ret_val 0
	for test in $argv
		echo -n "running "
		echo -n "$test"
		echo -n " ("($test --help)")"
		echo '...'
		set tmp_dir (setup_tmp_dir)
		# set src and dst for the copy cmd:
		if begin
				test "$remote_src" = ""
				and test "$remote_dst" = ""
			end
			set src $tmp_dir/src
			set dst $tmp_dir/dst
		else
			if test "$remote_src" != ""
				set remote "$remote_src"
				set remote_tmp_dir (ssh $remote mktemp -d)
				set src "$remote:$remote_tmp_dir"
				set dst $tmp_dir/dst
			else if test "$remote_dst" != ""
				set remote "$remote_dst"
				set remote_tmp_dir (ssh $remote mktemp -d)
				set src $tmp_dir/src
				set dst "$remote:$remote_tmp_dir"
			end
		end
		$test \
			$src \
			$dst \
			$tmp_dir/config \
			$tmp_dir/log
		if test $status -eq 0
			echo "ok"
		else 
			echo "failed"
			set ret_val 1
		end
		if test "$remote" != ""
			ssh $remote rm -r $remote_tmp_dir
		end
		rm -r $tmp_dir
	end
	return "$ret_val"
end

function setup_tmp_dir
	set -l tmp_dir (mktemp -d)
	output "created '$tmp_dir'"
	set -l src $tmp_dir/src
	set -l dst $tmp_dir/dst
	mkdir $src
	mkdir $dst

	echo "hello a" > $src/a
	echo "hello b" > $src/b
	echo "hello c" > $src/c
	echo $tmp_dir
end
