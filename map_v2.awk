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
	FMT["hex"]	= "BHND_NVRAM_VFMT_HEX"
	FMT["sdec"]	= "BHND_NVRAM_VFMT_SDEC"
	FMT["ccode"]	= "BHND_NVRAM_VFMT_CCODE"
	FMT["macaddr"]	= "BHND_NVRAM_VFMT_MACADDR"
	FMT["led_dc"]	= "BHND_NVRAM_VFMT_LEDDC"

	# Data Type Constants
	DTYPE["u8"]	= "BHND_NVRAM_DT_UINT"
	DTYPE["u16"]	= "BHND_NVRAM_DT_UINT"
	DTYPE["u32"]	= "BHND_NVRAM_DT_UINT"
	DTYPE["i8"]	= "BHND_NVRAM_DT_SINT"
	DTYPE["i16"]	= "BHND_NVRAM_DT_SINT"
	DTYPE["i32"]	= "BHND_NVRAM_DT_SINT"
	DTYPE["char"]	= "BHND_NVRAM_DT_CHAR"

	# Default masking for standard types
	TMASK["u8"]	= "0x000000FF"
	TMASK["u16"]	= "0x0000FFFF"
	TMASK["u32"]	= "0xFFFFFFFF"
	TMASK["i8"]	= TMASK["u8"]
	TMASK["i16"]	= TMASK["u16"]
	TMASK["i32"]	= TMASK["u32"]

	# Byte sizes for standard types
	TSIZE["u8"]	= "1"
	TSIZE["u16"]	= "2"
	TSIZE["u32"]	= "4"
	TSIZE["i8"]	= TSIZE["u8"]
	TSIZE["i16"]	= TSIZE["u8"]
	TSIZE["i32"]	= TSIZE["u8"]
	TSIZE["char"]	= "1"

	# Common Regexs
	INT_REGEX	= "^(0|[1-9][0-9]*),?$"
	HEX_REGEX	= "^0x[A-Fa-f0-9]+,?$"

	ARRAY_REGEX	= "\\[(0|[1-9][0-9]*)\\]"
	TYPES_REGEX	= "^(((u|i)(8|16|32))|char|cstr)("ARRAY_REGEX")?,?$"

	IDENT_REGEX	= "^[A-Za-z_][A-Za-z0-9_]*,?$"
	SROM_OFF_REGEX	= "("TYPES_REGEX"|"HEX_REGEX")"

	OFF_TYPE_REGEX	= "^(cis|srom)$"

	# Block types
	BLOCK_T_STRUCT	= "struct"
	BLOCK_T_VAR	= "var"
	BLOCK_T_NONE	= "NONE"

	# Property names
	PROP_T_SFMT	= "sfmt"
	PROP_T_ALL1	= "all1"
	PROP_T_COMPAT	= "compat"
	PROP_T_CISTUP	= "cis_tuple"

	# Internal variable names
	BLOCK_TYPE	= "_block_type"
	BLOCK_NAME	= "_block_name"
	BLOCK_START	= "_block_start"

	# Common array keys
	DEF_LINE	= "def_line"
	NUM_REVS	= "num_revs"
	REV		= "rev"

	# Revision array keys
	REV_START	= "rev_start"
	REV_END		= "rev_end"
	REV_DESC	= "rev_decl"
	REV_NUM_OFFS	= "num_offs"

	# Offset array keys
	OFF 		= "off"
	OFF_NUM_SEGS	= "off_num_segs"
	OFF_SEG		= "off_seg"

	# Segment array keys
	SEG_ADDR	= "seg_addr"
	SEG_WIDTH	= "seg_width"
	SEG_MASK	= "seg_mask"
	SEG_SHIFT	= "seg_shift"

	# Variable array keys
	VAR_NAME	= "v_name"
	VAR_TYPE	= "v_type"
	VAR_FMT		= "v_fmt"
	VAR_PRIVATE	= "v_private"
	VAR_ARRAY	= "v_array"
	VAR_IGNALL1	= "v_all1"
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

# return the flag definition for variable `v`
function gen_var_flags (v)
{
	_num_flags = 0;
	if (vars[v,VAR_ARRAY])
		_flags[_num_flags++] = "BHND_NVRAM_VF_ARRAY"

	if (vars[v,VAR_PRIVATE])
		_flags[_num_flags++] = "BHND_NVRAM_VF_MFGINT"

	if (vars[v,VAR_IGNALL1])
		_flags[_num_flags++] = "BHND_NVRAM_VF_IGNALL1"

	return (join(_flags, ", ", _num_flags))
}

# open a bhnd_nvram_var definition for `v`, with optional name `suffix`.
function gen_var_head (v, suffix)
{
	printi("{\"" v suffix "\", ")
	printf("%s, ", DTYPE[vars[v,VAR_TYPE]])
	printf("%s, ", FMT[vars[v,VAR_FMT]])
	printf("%s, ", gen_var_flags(v))
	printf("(struct bhnd_sprom_var[]) {\n")
	output_depth++
}

# generate a bhnd_sprom_var definition for the given variable revision key
function gen_var_rev_body (v, revk, base_addr)
{
	if (base_addr != null)
		base_addr = base_addr"+"
	else
		base_addr = ""

	printi()
	printf("{{%u, %u}, (struct bhnd_sprom_offset[]) {\n",
	    vars[revk,REV_START],
	    vars[revk,REV_END])
	output_depth++

	num_offs = vars[revk,REV_NUM_OFFS]
	num_offs_written = 0
	elem_count = 0
	for (offset = 0; offset < num_offs; offset++) {
		offk = subkey(revk, OFF, offset"")
		num_segs = vars[offk,OFF_NUM_SEGS]

		for (seg = 0; seg < num_segs; seg++) {
			segk = subkey(offk, OFF_SEG, seg"")

			printi()
			printf("{%s, %s, %s, %s},\n",
			    base_addr vars[segk,SEG_ADDR],
			    vars[segk,SEG_WIDTH],
    			    vars[segk,SEG_SHIFT],
			    vars[segk,SEG_MASK])
			num_offs_written++
		}
	}

	# Check for overflow of the variable's declared type
	if (vars[v,VAR_ARRAY])
		max_elem_count = type_array_len(vars[v,VAR_TYPE])
	else
		max_elem_count = 1

	if (TODO && vars[revk,REV_NUM_ELEMS] > max_elem_count) {
		_err_line = vars[revk,DEF_LINE]
		errorx(vars[v,VAR_NAME] " srom definition of " vars[revk,REV_NUM_ELEMS] \
		    " elements on line " _err_line " overflows type " \
		    vars[v,VAR_TYPE])
	}

	output_depth--
	printi("}, " num_offs_written "},\n")
}

# generate an array of bhnd_sprom_var definitions for `v`
function gen_var_body (v)
{
	for (rev = 0; rev < vars[v,NUM_REVS]; rev++) {
		revk = subkey(v, REV, rev"")
		gen_var_rev_body(v, revk)
	}
}

# close a bhnd_nvram_var definition for `v`
function gen_var_tail (v, num_revs)
{
	output_depth--
	printi("}, " num_revs "},\n")
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
	output_depth = 1
	for (v in var_names) {
		gen_var_head(v)
		gen_var_body(v)
		gen_var_tail(v, vars[v,NUM_REVS])
	}
	output_depth = 0
	printf("};\n")
}


#
# Print usage
#
function usage ()
{
	print "usage: bhnd_nvram_map.awk <input map>"
	exit 1
}

#
# Join all array elements with the given separator
#
function join (array, sep, count)
{
	if (count == 0)
		return ("")

	_result = array[0]
	for (_ji = 1; _ji < count; _ji++)
		_result = _result sep array[_ji]

	return (_result)
}

#
# Print msg, indented for the current `output_depth`
#
function printi (msg)
{
	for (_ind = 0; _ind < output_depth; _ind++)
		printf("\t")

	if (msg != null)
		printf("%s", msg)
}

#
# Print a warning to stderr
#
function warn (msg)
{
	print "warning:", msg, "at", FILENAME, "line", NR > "/dev/stderr"
}

#
# Print a compiler error to stderr
#
function error (msg)
{
	errorx(msg " at " FILENAME " line " NR ":\n\t" $0)
}

#
# Print an error message without including the source line information
#
function errorx (msg)
{
	print "error:", msg > "/dev/stderr"
	_EARLY_EXIT=1
	exit 1
}

#
# Print a debug output message
#
function debug (msg)
{
	if (!DEBUG)
		return
	for (_di = 0; _di < depth; _di++)
		printf("\t") > "/dev/stderr"
	print msg > "/dev/stderr"
}

#
# Return an array key composed of the given (parent, selector, child)
# tuple.
# The child argument is optional and may be omitted.
#
function subkey (parent, selector, child)
{
	if (child != null)
		return (parent SUBSEP selector SUBSEP child)
	else
		return (parent SUBSEP selector)
}

#
# Advance to the next non-comment input record
#
function next_line ()
{
	do {
		_result = getline
	} while (_result > 0 && $0 ~ /^[ \t]*#.*/) # skip comment lines
	return (_result)
}

#
# Advance to the next input record and verify that it matches @p regex
#
function getline_matching (regex)
{
	_result = next_line()
	if (_result <= 0)
		return (_result)

	if ($0 ~ regex)
		return (1)

	return (-1)
}

#
# Shift the current fields left by `n`.
#
# If all fields are consumed and the optional do_getline argument is true,
# read the next line.
#
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

#
# Parse a revision descriptor from the current line.
#
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

#
# Find opening brace and adjust block depth.
#
# The name may be null, in which case the BLOCK_NAME variable will not be
# defined in this scope
#
function open_block (type, name)
{
	if ($0 ~ "{" || getline_matching("^[ \t]*{") > 0) {
		depth++
		push(BLOCK_START, NR)
		if (name != null)
			push(BLOCK_NAME, name)
		push(BLOCK_TYPE, type)

		sub("^[^{]+{", "", $0)
		return
	}

	error("found '"$1 "' instead of expected '{' for '" name "'")
}

#
# Find closing brace and adjust block depth.
#
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

# Internal symbol table lookup function. Returns the symbol depth if
# name is found at or above scope; if scope is null, it defauls to 0
function _find_sym (name, scope)
{
	if (scope == null)
		scope = 0;

	for (i = scope; i < depth; i++) {
		if ((depth-i,name) in symbols)
			return (depth-i)
	}

	return (-1)
}

#
# Look up a variable in the symbol table with `name` and return its value.
#
# If `scope` is not null, the variable search will start at the provided
# scope level -- 0 is the current scope, 1 is the parent's scope, etc.
#
function g (name, scope)
{
	_g_depth = _find_sym(name, scope)
	if (_g_depth < 0)
		error("'" name "' is undefined")

	return (symbols[_g_depth,name])
}

function is_defined (name, scope)
{
	return (_find_sym(name, scope) >= 0)
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
	if (!is_defined(BLOCK_TYPE))
		return (type == BLOCK_T_NONE)

	return (type == g(BLOCK_TYPE))
}

# Evaluates to true if within an immediate or non-immediate block scope of the
# given type
function in_nested_block (type)
{
	for (i = 0; i < depth; i++) {
		if ((depth-i,BLOCK_TYPE) in symbols) {
			if (symbols[depth-i,BLOCK_TYPE] == type)
				return (1)
		}
	}
	return (0)
}

# Evaluates to true if definitions of the given type are permitted within
# the current scope
function allow_def (type)
{
	if (type == BLOCK_T_STRUCT) {
		return (in_block(BLOCK_T_NONE))
	} else if (type == BLOCK_T_VAR) {
		return in_block(BLOCK_T_STRUCT)
	}

	error("unknown type '" type "'")
}

# struct definition
$1 ~ IDENT_REGEX && allow_def(BLOCK_T_STRUCT) {
	name = $1

	if (name !~ IDENT_REGEX || name ~ TYPES_REGEX)
		error("invalid identifier '" name "'")

	# Add top-level struct entry 
	if ((name,DEF_LINE) in structs) 
		error("struct identifier '" name "' previously defined on " \
		    "line " structs[name,DEF_LINE])
	structs[name,DEF_LINE] = NR
	structs[name,NUM_REVS] = 0

	# Open the block 
	debug("struct " name " {")
	open_block(BLOCK_T_STRUCT, name)
}

# variable definition
(($1 == "private" && $2 ~ TYPES_REGEX) || $1 ~ TYPES_REGEX) &&
    allow_def(BLOCK_T_VAR) \
{
	# check for 'private' flag
	if ($1 == "private") {
		private = 1
		shiftf(1)
	} else {
		private = 0
	}

	type = $1
	name = $2
	array = 0
	debug(type " " name " {")

	# Check for and remove any array[] specifier
	base_type = type
	if (sub(ARRAY_REGEX"$", "", base_type) > 0)
		array = 1

	# verify type
	if (!base_type in DTYPE)
		error("unknown type '" $1 "'")

	# Add top-level variable entry 
	if (name in var_names) 
		error("variable identifier '" name "' previously defined on " \
		    "line " vars[name,DEF_LINE])

	var_names[name] = 0
	vars[name,VAR_NAME] = name
	vars[name,DEF_LINE] = NR
	vars[name,VAR_TYPE] = type
	vars[name,NUM_REVS] = 0
	vars[name,VAR_PRIVATE] = private
	vars[name,VAR_ARRAY] = array
	vars[name,VAR_FMT] = "hex" # default if not specified

	open_block(BLOCK_T_VAR, name)

	debug("type=" DTYPE[base_type])
}

# struct parameters
$1 ~ IDENT_REGEX && $1 !~ TYPES_REGEX && in_block(BLOCK_T_STRUCT) {
	sid = g(BLOCK_NAME)
	if ($1 == PROP_T_CISTUP) {
		# TODO
	} else if ($1 == PROP_T_COMPAT) {
		# TODO
	} else {
		error("unknown parameter " $1)
	}

	next
}

# revision offset definition
$1 ~ OFF_TYPE_REGEX && in_block(BLOCK_T_VAR) {
	vid = g(BLOCK_NAME)

	# TODO: Either parse compat statement, or fetch compat
	# from parent block

	# parse all offsets
if (0) {
	do {
		# assign offset id
		off = vars[revk,REV_NUM_OFFS] ""
		offk = subkey(revk, OFF, off)
		vars[revk,REV_NUM_OFFS]++

		# initialize segment count
		vars[offk,DEF_LINE] = NR
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
	next
}


# variable parameters
$1 ~ IDENT_REGEX && $2 ~ IDENT_REGEX && in_block(BLOCK_T_VAR) {
	vid = g(BLOCK_NAME)
	if ($1 == PROP_T_SFMT) {
		if (!$2 in FMT)
			error("invalid fmt '" $2 "'")

		vars[vid,VAR_FMT] = $2
		debug($1 "=" FMT[$2])
	} else if ($1 == PROP_T_ALL1 && $2 == "ignore") {
		vars[vid,VAR_IGNALL1] = 1
	} else {
		error("unknown parameter " $1)
	}
	next
}

# variable srom descriptor
0 && $1 == BLOCK_T_SROM && allow_def(BLOCK_T_SROM) {
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
	vars[revk,DEF_LINE] = NR
	vars[revk,REV_START] = rev_desc[REV_START]
	vars[revk,REV_END] = rev_desc[REV_END]
	vars[revk,REV_NUM_OFFS] = 0

	debug("srom " rev_desc[REV_START] "-" rev_desc[REV_END] " {")
	open_block($1, null)
}

#
# Extract and return the array length from the given type string.
# Returns -1 if the type is not an array.
#
function type_array_len (type)
{
	# extract byte count[] and width
	if (match(type, ARRAY_REGEX"$") > 0) {
		return (substr(type, RSTART+1, RLENGTH-2))
	} else {
		return (-1)
	}
}

#
# Parse an offset declaration from the current line.
#
function parse_offset_segment (revk, offk)
{
	vid = g(BLOCK_NAME)

	# handle missing explicit type
	type = $1
	offset = $2
	shiftf(2)

	if (type !~ TYPES_REGEX)
		error("unknown field type '" type "'")

	if (offset !~ HEX_REGEX)
		error("invalid offset value '" offset "'")

	# extract byte count[] and width
	if (match(type, ARRAY_REGEX"$") > 0) {
		count = int(substr(type, RSTART+1, RLENGTH-2))
		type = substr(type, 1, RSTART-1)
	} else {
		count = 1
	}
	width = TSIZE[type]

	# seek to attributes or end of the offset expr
	sub("^[^,(|){}]+", "", $0)

	# parse attributes
	mask=TMASK[type]
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

	for (_oi = 0; _oi < count; _oi++) {
		# assign segment id
		seg = vars[offk,OFF_NUM_SEGS] ""
		segk = subkey(offk, OFF_SEG, seg)
		vars[offk,OFF_NUM_SEGS]++

		vars[segk,SEG_ADDR]	= offset + (width * _oi)
		vars[segk,SEG_WIDTH]	= width
		vars[segk,SEG_MASK]	= mask
		vars[segk,SEG_SHIFT]	= shift

		debug("{"vars[segk,SEG_ADDR]", "width", "mask", "shift"}" \
		   _comma)
	}

}


# Skip comments and blank lines
/^[ \t]*#/ || /^$/ {
	next
}

# Close blocks
/}/ && !in_block(BLOCK_T_NONE) {
	while (!in_block(BLOCK_T_NONE) && $0 ~ "}") {
		close_block();
		debug("}")
	}
	next
}

# Report unbalanced '}'
/}/ && in_block(BLOCK_T_NONE) {
	error("extra '}'")
}

# Invalid variable type
$1 && allow_def(BLOCK_T_VAR) {
	error("unknown type '" $1 "'")
}

# Generic parse failure
{
	print ($1 ~ SROM_OFF_REGEX)
	print $1
	error("unrecognized statement")
}
