#!/usr/bin/awk -f

#-
#Copyright...


BEGIN {
	if (ARGC != 2)
		usage()

	depth = 0
	symbols[depth,"_file"] = FILENAME

	# Enable debug output
	DEBUG = 1

	# Maximum revision
	REV_MAX = 65535

	# Format Constants
	SFMT["hex"]	= "BHND_NVRAM_SFMT_HEX"
	SFMT["sdec"]	= "BHND_NVRAM_SFMT_SDEC"
	SFMT["ascii"]	= "BHND_NVRAM_SFMT_ASCII"
	SFMT["macaddr"]	= "BHND_NVRAM_SFMT_MACADDR"

	# Data Type Constants
	DTYPE["uint"]	= "BHND_NVRAM_DT_UINT"
	DTYPE["sint"]	= "BHND_NVRAM_DT_SINT"
	DTYPE["mac48"]	= "BHND_NVRAM_DT_MAC48"
	DTYPE["led"]	= "BHND_NVRAM_DT_LEDDC"
	DTYPE["cc"]	= "BHND_NVRAM_DT_CCODE"

	# Common Regexs
	TYPES_REGEX = "(uint|sint|led|cc|mac48)"
	IDENT_REGEX = "[A-Za-z][A-Za-z0-9]*"

	# Internal variable names
	BLOCK_TYPE = "_block_type"
	BLOCK_NAME = "_block_name"
	BLOCK_START = "_block_start"
}

END {
	if (depth > 0) {
		block_start = lookup(BLOCK_START)
		errorx("missing '}' for block opened on line " block_start "")
	}
}

NR == 1 {
	print "/*"
	print " * THIS FILE IS AUTOMATICALLY GENERATED. DO NOT EDIT."
	print " *"
	print " * generated from", FILENAME
	print " */"
}

function usage ()
{
	print "usage: bhnd_nvram_map.awk <input map>"
	exit 1
}

# Print a warning to stderr
function warn (msg)
{
	print "warning:", msg, "at", FILENAME, "line", NR > "/dev/stderr"
}

# Print a compiler error to stderr
function error (msg)
{
	print "error:", msg, "at", FILENAME, "line", NR ":\n\t" $0 \
	   > "/dev/stderr"
	exit 1
}

# Print an error message without including the source line information
function errorx (msg)
{
	print "error:", msg > "/dev/stderr"
	exit 1
}

# Print a debug output message
function debug (msg)
{
	if (!DEBUG)
		return
	for (i = 0; i < depth; i++)
		printf("\t") > "/dev/stderr"
	print msg > "/dev/stderr"
}

# Print to output file with the correct indentation and no implicit newline
function oprinti (str)
{
	for (i = 0; i < depth; i++)
		printf("\t")
	printf("%s", str)
}


# Print to output file with no implicit newline
function oprint (str)
{
	printf("%s", str)
}

# Advance to the next non-comment input record
function next_line ()
{
	do {
		_result = getline
	} while (_result > 0 && $0 ~ /^[ \t]*#.*/) # skip comment lines
	return _result
}

# Advance to the next input record and verify that it matches @p regex
function getline_matching (regex)
{
	_result = next_line()
	if (_result <= 0)
		return _result

	if ($0 ~ regex)
		return 1

	return -1
}

# Find opening brace and adjust block depth
function open_block (type, name, check_first)
{
	if (check_first == "{" || getline_matching("^[ \t]*{") > 0) {
		depth++
		push(BLOCK_START, NR)
		push(BLOCK_NAME, name)
		push(BLOCK_TYPE, type)
		#print "open:",lookup(BLOCK_TYPE),lookup(BLOCK_NAME)

		sub("^[^{]+{", "", $0)
		return 1
	}

	error("found '"$1 "' instead of expected '{' for '" name "'")
}

# Find closing brace and adjust block depth
function close_block ()
{
	if ($0 !~ "}")
		error("internal error - no closing brace")

	# drop all symbols defined at this depth
	#print "close:",lookup(BLOCK_TYPE),lookup(BLOCK_NAME)
	for (s in symbols) {
		if (s ~ "^"depth"[^0-9]")
			delete symbols[s]
	}

	# strip everything prior to the block closure
	sub("^[^}]+}", "", $0)
	depth--
}

# Look up a variable with `name` (and optional default value if not found)
# in the current symbol table. If deflt is not specified and the
# variable is not defined, a compiler error will be emitted.
function lookup (name, deflt)
{
	for (i = 0; i < depth; i++) {
		if ((depth-i,name) in symbols)
			return symbols[depth-i,name]
	}

	if (deflt)
		return deflt
	else
		error("'" name "' is undefined")
}

# Define a new variable in the symbol table's current scope,
# with the given value
function push (name, value)
{
	symbols[depth,name] = value
}

# Set an existing variable's value in the symbol table; if not yet defined,
# a new variable will be defined within the current scope.
function set (name, value)
{
	for (i = 0; i < depth; i++) {
		if ((depth-i,name) in symbols) {
			symbols[depth-i,name] = value
			return
		}
	}

	# No existing value
	push(name, value)
}

# Evaluates to true if immediately within a block scope of the given type
function in_block (type)
{
	return (type == lookup(BLOCK_TYPE, "NONE"))
}

# Evaluates to true if within an immediate or non-immediate block scope of the
# given type
function in_nested_block (type)
{
	for (i = 0; i < depth; i++) {
		if ((depth-i,BLOCK_TYPE) in symbols) {
			if (symbols[depth-i,BLOCK_TYPE] == type)
				return 1
		}
	}
	return 0
}

# Evaluates to true if definitions of the given type are permitted within
# the current scope
function allow_def (type)
{
	if (type == "var" || type == "sprom") {
		return (in_block("NONE") || in_block("struct") ||
		    in_block("var"))
	} else if (type == "struct") {
		return (in_block("NONE"))
	} else if (type == "revs") {
		return (in_block("sprom"))
	}

	error("unknown type '" type "'")
}

# struct definition
$1 == "struct" && allow_def("struct") {
	# Remove array[] specifier
	if (sub(/\[\]$/, "", $2) == 0)
		error("expected '" $2 "[]', not '" $2 "'")

	if ($2 !~ "^"IDENT_REGEX"$" || $2 ~ "^"TYPES_REGEX"$")
		error("invalid identifier '" $2 "'")

	debug("struct " $2 " {")
	open_block($1, $2, $3)
}

# sprom block
$1 == "sprom" && allow_def("sprom") {
	debug("sprom {")
	open_block($1, "", $2)
}

# revs block
$1 == "revs" && allow_def("revs") {
	_revstr = ""
	_bstart = $3

	if ($2 ~ "[0-9]*-[0-9*]") {
		_revstr = $2
		sub("-", ",", _revstr)
	} else if ($2 ~ "(>|>=|<|<=)" && $3 ~ "[1-9][0-9]*") {
		if ($2 == ">") {
			_revstr = int($3)+1","REV_MAX
		} else if ($2 == ">=") {
			_revstr = $3","REV_MAX
		} else if ($2 == "<" && int($3) > 0) {
			_revstr = "0,"int($3)-1
		} else if ($2 == "<=") {
			_revstr = "0,"$3
		} else {
			error("invalid revision descriptor")
		}

		_bstart = $4
	} else if ($2 ~ "[1-9][0-9]*") {
		_revstr = $2 "," $2
	} else {
		error("invalid revision descriptor")
	}

	_revstr = "{" _revstr "}"
	debug("revs " _revstr " {")
	open_block($1, "", _bstart)
}

# revs offset definition
$1 ~ "^" IDENT_REGEX "@0x[A-Fa-f0-9]+,?" && in_block("revs") {
	debug("offset="$1)
	next
}

# private variable block
$1 == "private" && $2 ~ "^"TYPES_REGEX"$" && allow_def("var") {
	sub("^private"FS, "", $0)
	_private = 1
}

# variable block
$1 ~ "^"TYPES_REGEX"$" && allow_def("var") {
	if (!$1 in DTYPE)
		error("unknown type '" $1 "'")

	type = $1
	name = $2
	debug(type " " name " {")

	# Check for and remove array[] specifier
	if (sub(/\[\]$/, "", name) > 0)
		array = 1

	open_block("var", name, $3)
	debug("type=" DTYPE[type])
}

# variable parameters
$1 ~ "^"IDENT_REGEX"$" && $2 ~ "^"IDENT_REGEX";?$" && in_block("var") {
	if ($1 == "sfmt") {
		if (!$2 in SFMT) {
			error("invalid sfmt '" $2 "'")
		}
		debug($1 "=" SFMT[$2])
	} else {
		error("unknown parameter " $1)
	}
	next
}

# Skip comment and blank lines
/^#/ || /^$/ {
	next
}

# Close blocks
/}/ && !in_block("NONE") {
	while (!in_block("NONE") && $0 ~ "}") {
		close_block();
		debug("}")
	}
	next
}

# Report unbalanced '}'
/}/ && in_block("NONE") {
	error("unbalanced '}'")
}

# Invalid variable type
$1 && allow_def("var") {
	error("unknown type '" $1 "'")
}


# Generic parse failure
{
	error("unrecognized statement")
}