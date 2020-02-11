

function eval_only_cmd
	set cmd $argv[1]
	set arguments $argv[2..-1]
	set escaped_arguments
	for arg in $arguments
		set escaped_arguments $escaped_arguments (string escape $arg)
	end
	eval $cmd $escaped_arguments
end
