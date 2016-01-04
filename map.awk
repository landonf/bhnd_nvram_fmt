#!/usr/bin/awk -f

#-
#Copyright...


BEGIN {
	if (ARGC != 2)
		usage()

	RS="\n"

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
	INT_REGEX	= "[1-9][0-9]*"
	HEX_REGEX	= "0x[A-Fa-f0-9]+"
	TYPES_REGEX	= "(uint|sint|led|cc|mac48)"
	WIDTHS_REGEX	= "(u8|u16|u32)(\\[[1-9][0-9]*\\])?"
	IDENT_REGEX	= "[A-Za-z][A-Za-z0-9]*"

	# Internal variable names
	BLOCK_TYPE	= "_block_type"
	BLOCK_NAME	= "_block_name"
	BLOCK_START	= "_block_start"

	# Common array keys
	DEF_LINE		= "def_line"
	NUM_REVS		= "num_revs"
	REVDESC			= "rev_decl"

	# Struct array keys
	ST_BASE_ADDRS		= "base_addrs"
	ST_NUM_BASE_ADDRS	= "num_base_addr"

	# Variable array keys
	VAR_NAME		= "v_name"
	VAR_TYPE		= "v_type"
	VAR_FMT			= "v_fmt"
	VAR_STRUCT		= "v_parent_struct"
}

END {
	if (!_EARLY_EXIT && depth > 0) {
		block_start = g(BLOCK_START)
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
	errorx(msg " at " FILENAME " line " NR ":\n\t" $0)
}

# Print an error message without including the source line information
function errorx (msg)
{
	print "error:", msg > "/dev/stderr"
	_EARLY_EXIT=1
	exit 1
}

# Print a debug output message
function debug (msg)
{
	if (!DEBUG)
		return
	for (_di = 0; _di < depth; _di++)
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

# Parse a revision descriptor from the current line
function parse_revdesc ()
{
	_revstr = ""

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
	} else if ($2 ~ "[1-9][0-9]*") {
		_revstr = $2 "," $2
	} else {
		error("invalid revision descriptor")
	}

	_revstr = "{" _revstr "}"
	return _revstr
}

# Find opening brace and adjust block depth. The name may be null, in which
# case the BLOCK_NAME variable will not be defined in this scope
function open_block (type, name)
{
	if ($0 ~ "{" || getline_matching("^[ \t]*{") > 0) {
		depth++
		push(BLOCK_START, NR)
		if (name != null)
			push(BLOCK_NAME, name)
		push(BLOCK_TYPE, type)
		#print "open:",g(BLOCK_TYPE),g(BLOCK_NAME)

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

	if (in_block("var")) {
		debug("complete-var")
	}

	# drop all symbols defined at this depth
	#print "close:",g(BLOCK_TYPE),g(BLOCK_NAME)
	for (s in symbols) {
		if (s ~ "^"depth"[^0-9]")
			delete symbols[s]
	}

	# strip everything prior to the block closure
	sub("^[^}]*}", "", $0)
	depth--
}

# Look up a variable in the symbol table with `name`, optional default value if
# not found, and an optional scope level to start searching.
#
# If deflt is null and the variable is not defined, a compiler error will be
# emitted.
# The scope level is defined relative to the current scope -- 0 is the current
# scope, 1 is the parent scope, etc.
function g (name, deflt, scope)
{
	if (scope == null)
		scope = 0;

	for (i = scope; i < depth; i++) {
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
# will trigger an error
function set (name, value, scope)
{
	for (i = 0; i < depth; i++) {
		if ((depth-i,name) in symbols) {
			symbols[depth-i,name] = value
			return
		}
	}
	# No existing value, cannot define
	error("'" name "' is undefined")
}

# Evaluates to true if immediately within a block scope of the given type
function in_block (type)
{
	return (type == g(BLOCK_TYPE, "NONE"))
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
		return (in_block("sprom") && in_nested_block("var"))
	} else if (type == "struct_revs") {
		return (in_block("sprom") && in_nested_block("struct") &&
		    !in_nested_block("var"))
	}

	error("unknown type '" type "'")
}

# struct definition
$1 == "struct" && allow_def("struct") {
	name = $2

	# Remove array[] specifier
	if (sub(/\[\]$/, "", name) == 0)
		error("expected '" name "[]', not '" name "'")

	if (name !~ "^"IDENT_REGEX"$" || name ~ "^"TYPES_REGEX"$")
		error("invalid identifier '" name "'")

	# Add top-level struct entry 
	if ((name,DEF_LINE) in structs) 
		error("struct identifier '" name "' previously defined on " \
		    "line " structs[name,DEF_LINE])
	structs[name,DEF_LINE] = NR
	structs[name,NUM_REVS] = 0

	# Open the block 
	debug("struct " name " {")
	open_block($1, name)
}

# struct rev descriptor
$1 == "revs" && allow_def("struct_revs") {
	id = g(BLOCK_NAME)
	rev_idx = structs[id,NUM_REVS]

	structs[id,NUM_REVS]++
	structs[id,REVDESC,rev_idx] = parse_revdesc()

	base_idx = match($0, "\\[[^]]*\\]")
	if (base_idx == 0)
		error("expected base address array")

	addrs_str = substr($0, base_idx+1, RLENGTH-2)
	num_addrs = split(addrs_str, addrs, ",[ \t]*")
	structs[id,ST_NUM_BASE_ADDRS] = num_addrs
	for (i = 1; i <= num_addrs; i++) {
		if (addrs[i] !~ "^"HEX_REGEX"$")
			error("invalid base address '" addrs[i] "'")
		structs[id,ST_BASE_ADDRS,i-1] = addrs[i]
	}

	debug("struct_revs " structs[id,REVDESC,rev_idx] " [" addrs_str "]")
	next
}

# sprom block
$1 == "sprom" && allow_def("sprom") {
	debug("sprom {")
	open_block($1, null)
}

# variable revs block
$1 == "revs" && allow_def("revs") {
	_revstr = parse_revdesc()

	debug("revs " _revstr " {")
	open_block($1, null)
}

# offset definition
$1 ~ "^"WIDTHS_REGEX "(\\[" INT_REGEX "\\])?" && in_block("revs") {
	#if (!in_nested_block("struct")) {
		debug($1 " " $2 " " $3)
	#} else {
	#	debug("o=" $1)
	#}

#	parse_offset()

	while ($(NF) == "," || $(NF) == "|") {
		next_line()
#		parse_offset()
	}

	#debug("REWR="$0)
	sub("[^{}]+", "", $0)
	#debug("SUB="$0)
}

# private variable flag
$1 == "private" && $2 ~ "^"TYPES_REGEX"$" && allow_def("var") {
	sub("^private"FS, "", $0)
	_private = 1
}

# variable definition
$1 ~ "^"TYPES_REGEX"$" && allow_def("var") {
	if (!$1 in DTYPE)
		error("unknown type '" $1 "'")

	type = $1
	name = $2
	debug(type " " name " {")

	# Check for and remove array[] specifier
	if (sub(/\[\]$/, "", name) > 0)
		array = 1

	# Add top-level variable entry 
	if ((name,DEF_LINE) in vars) 
		error("variable identifier '" name "' previously defined on " \
		    "line " vars[name,DEF_LINE])

	vars[name,DEF_LINE] = NR
	vars[name,VAR_TYPE] = type

	open_block("var", name)

	# Mark as a struct-based variable
	if (in_nested_block("struct")) {
		sid = g(BLOCK_NAME, null, 1)
		vars[name,VAR_PARENT_STRUCT] = sid
		debug("struct-var " sid " (revs=" structs[sid,NUM_REVS] ")")
	}

	debug("type=" DTYPE[type])
}

# variable parameters
$1 ~ "^"IDENT_REGEX"$" && $2 ~ "^"IDENT_REGEX";?$" && in_block("var") {
	vid = g(BLOCK_NAME)
	if ($1 == "sfmt") {
		if (!$2 in SFMT) {
			error("invalid sfmt '" $2 "'")
		}
		vars[vid,VAR_FMT] = $2
		debug($1 "=" SFMT[$2])
	} else {
		error("unknown parameter " $1)
	}
	next
}

# Skip comments and blank lines
/^[ \t]*#/ || /^$/ {
	next
}

# Close blocks
/}/ && !in_block("NONE") {
	while (!in_block("NONE") && $0 ~ "}") {
#		if (/{/ && index($0, "}") > index($0, "{"))
#			error("internal error; unmatched entries at close")

		close_block();
		debug("}")
	}
	next
}

# Report unbalanced '}'
/}/ && in_block("NONE") {
	error("extra '}'")
}

# Invalid variable type
$1 && allow_def("var") {
	error("unknown type '" $1 "'")
}


# Generic parse failure
{
	error("unrecognized statement")
}