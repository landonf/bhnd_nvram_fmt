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
	DEBUG = 0

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

	# Default masking for standard widths
	WMASK["u8"]	= "0x000000FF"
	WMASK["u16"]	= "0x0000FFFF"
	WMASK["u32"]	= "0xFFFFFFFF"

	# Byte sizes for standard widths
	WBYTES["u8"]	= "1"
	WBYTES["u16"]	= "2"
	WBYTES["u32"]	= "4"

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
	REV			= "rev"

	# Revision array keys
	REV_START		= "rev_start"
	REV_END			= "rev_end"
	REV_DESC		= "rev_decl"
	REV_NUM_OFFS		= "num_offs"

	# Offset array keys
	OFF 			= "off"
	OFF_NUM_SEGS		= "off_num_segs"
	OFF_SEG			= "off_seg"

	# Segment array keys
	SEG_ADDR		= "seg_addr"
	SEG_WIDTH		= "seg_width"
	SEG_MASK		= "seg_mask"
	SEG_SHIFT		= "seg_shift"

	# Variable array keys
	VAR_NAME		= "v_name"
	VAR_TYPE		= "v_type"
	VAR_FMT			= "v_fmt"
	VAR_STRUCT		= "v_parent_struct"
	VAR_PRIVATE		= "v_private"
	VAR_ARRAY		= "v_array"
	VAR_IGNALL1		= "v_ignall1"
}

NR == 1 {
	print "/*"
	print " * THIS FILE IS AUTOMATICALLY GENERATED. DO NOT EDIT."
	print " *"
	print " * generated from", FILENAME
	print " */"
	print ""
	print "#include \"ccmach/nvram_map.h\""
}

function subkey (parent, child0, child1)
{
	if (child1 != null)
		return parent SUBSEP child0 SUBSEP child1
	else
		return parent SUBSEP child0
}

function gen_var_flags (v)
{
	_flags = "BHND_NVRAM_VF_DFLT"
	if (vars[v,VAR_ARRAY])
		_flags = _flags "|BHND_NVRAM_VF_ARRAY"

	if (vars[v,VAR_PRIVATE])
		_flags = _flags "|BHND_NVRAM_VF_MFGINT"

	if (vars[v,VAR_IGNALL1])
		_flags = _flags "|BHND_NVRAM_VF_IGNALL1"

	# TODO BHND_NVRAM_VF_IGNALL1
	return _flags
}

function gen_var_max_array_len (v)
{
	if (!vars[v,VAR_ARRAY])
		return 0

	_max_elems = 0
	for (_rev = 0; _rev < vars[v,NUM_REVS]; _rev++) {
		_revk = subkey(v, REV, _rev"")
		_num_offs = vars[revk,REV_NUM_OFFS]
		if (_num_offs > _max_elems)
			_max_elems = _num_offs
	}

	return _max_elems
}

function gen_var_decl (v, struct_rev, struct_revk, base_addr)
{
	if (base_addr == null)
		base_addr = ""
	else
		base_addr = base_addr "+"

	printf("\t{\"%s\", %s, %s, %s, %u, (struct bhnd_sprom_var[]) {\n",
	    v struct_rev,
	    DTYPE[vars[v,VAR_TYPE]],
	    SFMT[vars[v,VAR_FMT]],
	    gen_var_flags(v),
	    gen_var_max_array_len(v))

	for (rev = 0; rev < vars[v,NUM_REVS]; rev++) {
		revk = subkey(v, REV, rev"")

		if (struct_revk != null) {
			sr_start = structs[struct_revk,REV_START]
			sr_end = structs[struct_revk,REV_END]
			if (vars[revk,REV_START] < sr_start)
				continue
			if (vars[revk,REV_START] > sr_end)
				continue
			if (vars[revk,REV_END] < sr_start)
				continue
			if (vars[revk,REV_END] > sr_end)
				continue
		}

		printf("\t\t{{%u, %u}, (struct bhnd_sprom_value[]) {\n",
		    vars[revk,REV_START],
		    vars[revk,REV_END])

		num_offs = vars[revk,REV_NUM_OFFS]
		for (offset = 0; offset < num_offs; offset++) {
			offk = subkey(revk, OFF, offset"")
			num_segs = vars[offk,OFF_NUM_SEGS]

			printf("\t\t\t{(struct bhnd_sprom_vseg []) {\n")
			for (seg = 0; seg < num_segs; seg++) {
				segk = subkey(offk, OFF_SEG, seg"")
				printf("\t\t\t\t\t{%s,\t%s,\t%s,\t%s},\n",
				    base_addr vars[segk,SEG_ADDR],
				    vars[segk,SEG_WIDTH],
				    vars[segk,SEG_MASK],
				    vars[segk,SEG_SHIFT])
			}
			printf("\t\t\t}, %u},\n", num_segs)
		}
		printf("\t\t}, %u},\n", num_offs)
	}

	printf("\t}, %u},\n", vars[v,NUM_REVS])
}

function gen_struct_var_decl (v)
{
	st = vars[v,VAR_STRUCT]
	for (srev = 0; srev < structs[st,NUM_REVS]; srev++) {
		srevk = subkey(st, REV, srev"")

		for (off = 0; off < structs[srevk,REV_NUM_OFFS]; off++) {
			offk = subkey(srevk, OFF, off"")
			gen_var_decl(v, off, srevk, structs[offk,SEG_ADDR])
		}
	}
}

END {
	# skip completion handling if exiting from an error
	if (_EARLY_EXIT)
		exit 1

	# check for complete block closure
	if (depth > 0) {
		block_start = g(BLOCK_START)
		errorx("missing '}' for block opened on line " block_start "")
	}

	# generate output
	printf("const struct bhnd_nvram_var nvram_vars[] = {\n")
	for (v in var_names) {
		if (vars[v,VAR_STRUCT] != null) {
#			gen_struct_var_decl(v)
		} else
			gen_var_decl(v)
	}
	printf("};\n")

	for (k in vars) {
		o = k
		gsub(SUBSEP, ",", o)
		#print o,"=",vars[k]
	}
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

# Shift the current fields left by `n`. If all fields are consumed and
# the optional do_getline argument is true, read the next line.
function shiftf (n, do_getline)
{
	if (n > NF) error("shift past end of line")
	for (_si = 1; _si <= NF-n; _si++) {
		$(_si) = $(_si+n)
	}
	NF = NF - n

	if (NF == 0 && do_getline)
		next_line()
}

# Parse a revision descriptor from the current line
function parse_revdesc (result)
{
	_rstart = 0
	_rend = 0

	if ($2 ~ "[0-9]*-[0-9*]") {
		split($2, _revrange, "[ \t]*-[ \t]*")
		_rstart = _revrange[1]
		_rend = _revrange[2]
	} else if ($2 ~ "(>|>=|<|<=)" && $3 ~ "[1-9][0-9]*") {
		if ($2 == ">") {
			_rstart = int($3)+1
			_rend = REV_MAX
		} else if ($2 == ">=") {
			_rstart = int($3)
			_rend = REV_MAX
		} else if ($2 == "<" && int($3) > 0) {
			_rstart = 0
			_rend = int($3)-1
		} else if ($2 == "<=") {
			_rstart = 0
			_rend = int($3)-1
		} else {
			error("invalid revision descriptor")
		}
	} else if ($2 ~ "[1-9][0-9]*") {
		_rstart = int($2)
		_rend = int($2)
	} else {
		error("invalid revision descriptor")
	}

	result[REV_START] = _rstart
	result[REV_END] = _rend
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
	if (type == "var") {
		return (in_block("NONE") || in_block("struct") ||
		    in_block("var"))
	} else if (type == "struct") {
		return (in_block("NONE"))
	} else if (type == "revs") {
		return (in_block("var"))
	} else if (type == "struct_revs") {
		return (in_block("struct"))
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
	sid = g(BLOCK_NAME)

	# parse revision descriptor
	rev_desc[REV_START] = 0
	parse_revdesc(rev_desc)

	# assign revision id
	rev = structs[sid,NUM_REVS] ""
	revk = subkey(sid, REV, rev)
	structs[sid,NUM_REVS]++

	# init basic revision state
	structs[revk,REV_START] = rev_desc[REV_START]
	structs[revk,REV_END] = rev_desc[REV_END]

	if (match($0, "\\[[^]]*\\]") <= 0)
		error("expected base address array")

	addrs_str = substr($0, RSTART+1, RLENGTH-2)
	num_offs = split(addrs_str, addrs, ",[ \t]*")
	structs[revk, REV_NUM_OFFS] = num_offs
	for (i = 1; i <= num_offs; i++) {
		offk = subkey(revk, OFF, (i-1) "")

		if (addrs[i] !~ "^"HEX_REGEX"$")
			error("invalid base address '" addrs[i] "'")

		structs[offk,SEG_ADDR] = addrs[i]
	}

	debug("struct_revs " structs[revk,REV_START] "... [" addrs_str "]")
	next
}

# variable revs block
$1 == "revs" && allow_def("revs") {
	# parse revision descriptor
	parse_revdesc(rev_desc)

	# assign revision id
	vid = g(BLOCK_NAME)
	rev = vars[vid,NUM_REVS] ""
	revk = subkey(vid, REV, rev)
	vars[vid,NUM_REVS]++

	# vend scoped rev/revk variables for use in the
	# revision offset block
	push("rev_id", rev)
	push("rev_key", revk)

	# init basic revision state
	vars[revk,REV_START] = rev_desc[REV_START]
	vars[revk,REV_END] = rev_desc[REV_END]
	vars[revk,REV_NUM_OFFS] = 0

	debug("revs " _revstr " {")
	open_block($1, null)
}

function parse_offset_segment (revk, offk)
{
	vid = g(BLOCK_NAME)

	# assign segment id
	seg = vars[offk,OFF_NUM_SEGS] ""
	segk = subkey(offk, OFF_SEG, seg)
	vars[offk,OFF_NUM_SEGS]++

	type=$1
	offset=$2

	if (type !~ "^"WIDTHS_REGEX"$")
		error("unknown field width '" $1 "'")

	if (offset !~ "^"HEX_REGEX",?$")
		error("invalid offset value '" $2 "'")

	# clean up any trailing comma on the offset field
	sub(",$", "", offset)

	# extract byte count[] and width
	if (match(type, "\\["INT_REGEX"\\]$") > 0) {
		count = substr(type, RSTART+1, RLENGTH-2)
		type = substr(type, 1, RSTART-1)
	} else {
		count = 1
	}
	width = WBYTES[type]

	# seek to attributes or end of the offset expr
	sub("^[^,(|){}]+", "", $0)


	# parse attributes
	mask=WMASK[type]
	shift=0

	if ($1 ~ "^\\(") {
		# extract attribute list
		if (match($0, "\\([^|\(\)]*\\)") <= 0)
			error("expected attribute list")
		attr_str = substr($0, RSTART+1, RLENGTH-2)

		# drop from input line
		$0 = substr($0, RSTART+RLENGTH, length($0) - RSTART+RLENGTH)

		# parse attributes
		num_attr = split(attr_str, attrs, ",[ \t]*")
		for (i = 1; i <= num_attr; i++) {
			attr = attrs[i]
			if (sub("^&[ \t]*", "", attr) > 0) {
				mask = attr
			} else if (sub("^<<[ \t]*", "", attr) > 0) {
				shift = "-"attr
			} else if (sub("^>>[ \t]*", "", attr) > 0) {
				shift = attr
			} else {
				error("unknown attribute '" attr "'")
			}
		}
	}

	vars[segk,SEG_ADDR]	= offset
	vars[segk,SEG_WIDTH]	= width
	vars[segk,SEG_MASK]	= mask
	vars[segk,SEG_SHIFT]	= shift
	debug("{"offset", " width ", " mask ", " shift"}" _comma)
}

# revision offset definition
$1 ~ "^"WIDTHS_REGEX "(\\[" INT_REGEX "\\])?" && in_block("revs") {
	vid = g(BLOCK_NAME)

	# fetch rev id/key defined by our parent block
	rev = g("rev_id")
	revk = g("rev_key")

	# parse all offsets
	do {
		# assign offset id
		off = vars[revk,REV_NUM_OFFS] ""
		offk = subkey(revk, OFF, off)
		vars[revk,REV_NUM_OFFS]++

		# initialize segment count
		vars[offk,OFF_NUM_SEGS] = 0

		debug("[")
		# parse all segments
		do {
			parse_offset_segment(revk, offk)
			_more_seg = ($1 == "|")
			if (_more_seg)
				shiftf(1, 1)
		} while (_more_seg)
		debug("],")
		_more_vals = ($1 == ",")
		if (_more_vals)
			shiftf(1, 1)
	} while (_more_vals)
}

# variable definition
(($1 == "private" && $2 ~ "^"TYPES_REGEX"$") || $1 ~ "^"TYPES_REGEX"$") && \
    allow_def("var") \
{
	# check for 'private' flag
	if ($1 == "private") {
		private = 1
		shiftf(1)
	} else {
		private = 0
	}

	# verify type
	if (!$1 in DTYPE)
		error("unknown type '" $1 "'")

	type = $1
	name = $2
	array = 0
	debug(type " " name " {")

	# Check for and remove array[] specifier
	if (sub(/\[\]$/, "", name) > 0)
		array = 1

	# Add top-level variable entry 
	if (name in var_names) 
		error("variable identifier '" name "' previously defined on " \
		    "line " vars[name,DEF_LINE])

	var_names[name] = 0
	vars[name,DEF_LINE] = NR
	vars[name,VAR_TYPE] = type
	vars[name,NUM_REVS] = 0
	vars[name,VAR_PRIVATE] = private
	vars[name,VAR_ARRAY] = array
	vars[name,VAR_FMT] = "hex" # default if not specified

	open_block("var", name)

	# Mark as a struct-based variable
	if (in_nested_block("struct")) {
		sid = g(BLOCK_NAME, null, 1)
		vars[name,VAR_STRUCT] = sid
	}

	debug("type=" DTYPE[type])
}

# variable parameters
$1 ~ "^"IDENT_REGEX"$" && $2 ~ "^"IDENT_REGEX";?$" && in_block("var") {
	vid = g(BLOCK_NAME)
	if ($1 == "sfmt") {
		if (!$2 in SFMT)
			error("invalid sfmt '" $2 "'")

		vars[vid,VAR_FMT] = $2
		debug($1 "=" SFMT[$2])
	} else if ($1 == "all1" && $2 == "ignore") {
		vars[vid,VAR_IGNALL1] = 1
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
