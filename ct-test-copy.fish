#!/usr/bin/env fish

source (dirname (status -f))/__ct_test_utils.fish


set tests \
	test_cmdline \
	test_copy \
	test_separate_logdir \
	test_simulate \
	test_exclude


###################################
# test cases as functions:
###################################

function test_cmdline
	argparse \
		"h/help" \
		-- \
		$argv
	if set --query _flag_h
		echo "general command line behaviour"
	end
	$copy_cmd -h >/dev/null
	and $copy_cmd --help >/dev/null
end

function test_copy
	argparse \
		"h/help" \
		-- \
		$argv
	if set --query _flag_h
		echo "copying directory"
		return
	end
	set src $argv[1]
	set dst $argv[2]
	set config_dir $argv[3]

	set cmd \
		$copy_cmd \
		--config-dir $config_dir \
		$src \
		$dst
	run_with_output $cmd
	if set --query verbose
		tree_ext "$src"
		tree_ext "$dst"
	end
	diff_ext $src $dst | indent
	or begin
		echo "src and dst differ"
		return 1
	end
	test -d $config_dir/log
	or begin
		echo "log dir not existing"
		return 1
	end
	test (count (ls_ext "$config_dir/log")) -ne 0
	or begin
		echo "log dir is empty!"
		return 1
	end
end

function test_separate_logdir
	argparse \
		"h/help" \
		-- \
		$argv
	if set --query _flag_h
		echo "copy using separate log dir"
		return
	end
	set src $argv[1]
	set dst $argv[2]
	set config_dir $argv[3]
	set log_dir $argv[4]

	set cmd \
		$copy_cmd \
		--log-dir $log_dir \
		--config-dir $config_dir \
		$src \
		$dst
	if set --query verbose
		tree_ext "$src"
		tree_ext "$dst"
	end
	run_with_output $cmd
	diff_ext $src $dst | indent
	or begin
		echo "src and dst differ"
		return 1
	end
	test -d $log_dir
	or begin
		echo "log dir not existing"
		return 1
	end
	test (count (ls_ext "$log_dir")) -ne 0
	or begin
		echo "log dir is empty!"
		return 1
	end
end

function test_simulate
	argparse \
		"h/help" \
		-- \
		$argv
	if set --query _flag_h
		echo "simulate copying"
		return
	end
	set src $argv[1]
	set dst $argv[2]
	set config_dir $argv[3]
	set log_dir $argv[4]

	set cmd \
		$copy_cmd \
		--simulate \
		--log-dir $log_dir\
		--config-dir $config_dir \
		$src \
		$dst
	run_with_output $cmd
	if set --query verbose
		tree_ext "$src"
		tree_ext "$dst"
	end
	# log dir should not be created or empty
	test ! -d $log_dir; or test (count (ls -A "$log_dir")) -eq 0;
	or begin
		echo "log dir is not empty!"
		return 1
	end
	test (count (ls_ext "$dst")) -eq 0
	or begin
		echo "dst is not empty"
		return 1
	end
	not test -d $log_dir
	or begin
		echo "log dir is not empty!"
		return 1
	end
end

function test_exclude
	argparse \
		"h/help" \
		-- \
		$argv
	if set --query _flag_h
		echo "copy using excluding some parts in src dir"
		return
	end
	set src $argv[1]
	set dst $argv[2]
	set config_dir $argv[3]
	set log_dir $argv[4]

	set excluded_dir dir
	set excluded_file file
	set list_without (ls_ext "$src")
	mkdir_ext "$src/$excluded_dir"
	write_to_file_ext "excluded" "$src/$excluded_file"

	set cmd \
		$copy_cmd \
		--log-dir $log_dir \
		--config-dir $config_dir \
		--exclude $excluded_dir \
		--exclude $excluded_file \
		$src \
		$dst
	run_with_output $cmd
	if set --query verbose
		tree_ext "$src"
		tree_ext "$dst"
	end
	not diff_ext $src $dst > /dev/null
	or begin
		echo "excluded files have been copied"
		return 1
	end
	set list_without_sorted (echo $list_without | xargs -n1 | sort)
	set on_dest_sorted (ls_ext "$dst" | xargs -n1 | sort)
	# echo "without: $list_without_sorted"
	# echo "on dest: $on_dest_sorted"
	diff (for l in $list_without_sorted; echo $l; end | psub) (for l in $on_dest_sorted; echo $l; end | psub)
	or begin
		echo "output not as expected"
		return 1
	end
end

###################################
# run all tests:
###################################

set options_with_descr \
	"h/help/print this help" \
	"v/verbose/print details while running tests" \
	"s/remote-src=/if set to a ssh location, test copying remote -> local " \
	"d/remote-dst=/if set to a ssh location, test copying local -> remote " \
	"i/install-dir=/if not in PATH, location where to find the tested script"

function print_help
	echo "usage: "(status -f)" [OPTIONS...] [TESTS...]"
	echo "OPTIONS:"
	print_options_descr $options_with_descr
end

set options (options_descr_to_argparse $options_with_descr)

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
	if set --query _flag_verbose
		set verbose 1
	end
	set copy_cmd ct-copy.fish
	if set --query _flag_install_dir
		set copy_cmd $_flag_install_dir/$copy_cmd
	end
	if set --query _flag_remote_src; and set --query _flag_remote_dst
		echo "ERROR: only one of SRC or DST can be remote!"
		exit 1
	end
	if set --query _flag_remote_src
		set remote_src $_flag_remote_src
	else if set --query _flag_remote_dst
		set remote_dst $_flag_remote_dst
	end
end
if test (count $argv) -ne 0
	set tests $argv
end

exec_tests \
	--remote-src "$remote_src" \
	--remote-dst "$remote_dst" \
	$tests

exit $status
