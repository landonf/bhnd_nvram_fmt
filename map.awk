#!/usr/bin/awk -f

#-
#Copyright...

function usage() {
	print "usage: bhnd_nvram_map.awk <input map>"
	exit 1
}

function warn(msg) {
	print "warning:", msg, "at", mfile, "line", NR > "/dev/stderr"
}

function error(msg) {
	print "error:", msg, "at", mfile, "line", NR ":\n\t" $0 > "/dev/stderr"
	exit 1
}

function find_block_open(check_first) {
	if (check_first == "{")
		depth++

	while (getline > 0) {

	}
}

BEGIN {
	if (ARGC != 2)
		usage()
	mfile = ARGV[1]
	depth = 0
}

NR == 1 {
	printf("/*\n")
	printf(" * THIS FILE AUTOMATICALLY GENERATED.  DO NOT EDIT.\n") \
	   
	printf(" * generated from %s\n", mfile)
	printf(" */\n")
}

# Comments
/^[ \t]*#.*/ {
	next
}

$1 == "block[]" {
	next
}

$1 == "private" {
	$1 = $2
	$2 = $3
	private = 1
}

$1 ~ "(uint|sint|leddc|ccode|mac48)" {
	type = $1
	name = $2
	array = 0
	if (name ~ /\[\]$/) {
		sub(/\[\]$/, "", name);
		array = 1
	}
	print type,name,array
#	//printf("%s %s %s\n", type, name, array)

	next
}

$1 {
# XXX should be error
	warn("unknown type '" $1 "'")
}

$0 {
#	error("unrecognized statement")
}