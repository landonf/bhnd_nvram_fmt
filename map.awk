#!/usr/bin/awk -f

#-
#Copyright...

function usage() {
	print "usage: nvram_map.awk <input map> <output header>";
	exit 1;
}

BEGIN {
	if (ARGC != 3)
		usage();
	mfile = ARGV[1]
	hfile = ARGV[2]
}

NR == 1 {
	VERSION = $0
	gsub("\\$", "", VERSION)

	printf("/* \$FreeBSD\$ */\n\n") > hfile
	printf("/*\n") > hfile
	printf(" * THIS FILE AUTOMATICALLY GENERATED.  DO NOT EDIT.\n") \
	    > hfile
	printf(" *\n") > hfile
	printf(" * generated from:\n") > hfile
	printf(" *\t%s\n", VERSION) > hfile
	printf(" */\n") > hfile

	next
}