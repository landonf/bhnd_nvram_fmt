//
//  nvram_map.h
//  ccmach
//
//  Created by Landon Fuller on 1/1/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include <stdio.h>
#include <unistd.h>
#include <stdint.h>

/** NVRAM primitive data types */
typedef enum {
	BHND_NVRAM_DT_UINT,	/**< unsigned integer */
	BHND_NVRAM_DT_SINT,	/**< signed integer */
	BHND_NVRAM_DT_MAC48,	/**< MAC-48 address */
	BHND_NVRAM_DT_LEDDC,	/**< LED PWM duty-cycle */
	BHND_NVRAM_DT_CCODE,	/**< country code format (2-3 ASCII chars) */
} bhnd_nvram_dt;

/** NVRAM data type string representations */
typedef enum {
	BHND_NVRAM_SFMT_HEX,		/**< hex string format */
	BHND_NVRAM_SFMT_SDEC,		/**< signed decimal format */
	BHND_NVRAM_SFMT_MACADDR,	/**< mac address (canonical form, hex octets,
					     seperated with ':') */
	BHND_NVRAM_SFMT_ASCII		/**< ASCII string */
} bhnd_nvram_sfmt;

/** NVRAM variable flags */
enum {
	BHND_NVRAM_VF_DFLT	= 0,
	BHND_NVRAM_VF_ARRAY	= (1<<0),	/**< variable is an array */
	BHND_NVRAM_VF_MFGINT	= (1<<1),	/**< mfg-internal variable; should not be externally visible */
	BHND_NVRAM_VF_IGNALL1	= (1<<2)	/**< hide variable if its value has all bits set. */
};

#define	BHND_SPROMREV_MAX	UINT16_MAX	/**< maximum supported SPROM revision */

/** SPROM revision compatibility declaration */
typedef struct bhnd_sprom_compat {
	uint16_t	first;	/**< first compatible SPROM revision */
	uint16_t	last;	/**< last compatible SPROM revision, or BHND_SPROMREV_MAX */
} bhnd_sprom_compat_t;

/** SPROM value segment descriptor */
typedef struct bhnd_sprom_vseg {
	uint16_t	offset;	/**< byte offset within SPROM */
	size_t		width;	/**< 1, 2, or 4 bytes */
	uint32_t	mask;	/**< mask to be applied to the value */
	size_t		shift;	/**< shift to be applied to the value */
} bhnd_sprom_vseg_t;

/** SPROM value descriptor */
typedef struct bhnd_sprom_value {
	const bhnd_sprom_vseg_t	*segs;		/**< segment(s) containing this value */
	size_t			 num_segs;	/**< number of segments */
} bhnd_sprom_value_t;

/** SPROM-specific variable definition */
typedef struct bhnd_sprom_var {
	const bhnd_sprom_compat_t	 compat;	/**< sprom compatibility declaration */
	const bhnd_sprom_value_t	*values;	/**< value descriptor(s) */
	size_t				 num_values;	/**< number of values (e.g. if this is an array) */
} bhnd_sprom_var_t;

/** NVRAM variable definition */
typedef struct bhnd_nvram_var {
	const char		*name;		/**< variable name */
	bhnd_nvram_dt		 type;		/**< base data type */
	bhnd_nvram_sfmt		 sfmt;		/**< string format */
	uint32_t		 flags;		/**< BHND_NVRAM_VF_* flags */
	size_t			 array_len;	/**< array element count (if BHND_NVRAM_VF_ARRAY) */

	const bhnd_sprom_var_t	*sprom_descs;	/**< SPROM-specific variable descriptors */
	size_t			 num_sp_descs;	/**< number of sprom descriptors */
} bhnd_nvram_var_t;

#define	_BHND_NV_VAR_DECL(_name, _type, _fmt, _flags, _array_len, ...) \
{									\
    	.name		= __STRING(_name),				\
	.type		= BHND_NVRAM_DT_ ## _type,			\
	.sfmt		= BHND_NVRAM_ ## _fmt,			\
	.flags		= _flags,					\
	.array_len	= _array_len,					\
	.sprom_descs	= _BHND_NV_VA_ARRAY(sprom_var, __VA_ARGS__),	\
	.num_sp_descs	=						\
	    nitems(_BHND_NV_VA_ARRAY(sprom_var, __VA_ARGS__))	\
}



#define	_BHND_NV_VA_ARRAY(_type, ...)	\
	(const struct bhnd_ ## _type[]) { __VA_ARGS__ }

/**
 *
 */
#define BHND_NVRAM_VAR(_name, _type, _fmt, _flag, _array_len, ...) \
	_BHND_NV_VAR_DECL(_name, _type, _fmt,	\
	    BHND_NVRAM_ ## _flag, _array_len, __VA_ARGS__)


#define	_BHND_SPROM_VAR_DECL(_compat, ...) {				\
	.compat		= BHND_SPROM_COMPAT_ ## _compat,		\
	.values		= _BHND_NV_VA_ARRAY(sprom_value, __VA_ARGS__),	\
	.num_values	=						\
	    nitems(_BHND_NV_VA_ARRAY(sprom_value, __VA_ARGS__))		\
}

#define	BHND_SPROM_COMPAT_REV_RANGE(_start, _end)	{_rev, _rev}
#define	BHND_SPROM_COMPAT_REV_EQ(_rev)			{_rev, _rev}
#define	BHND_SPROM_COMPAT_REV_GTE(_rev)	\
	{_rev, BHND_SPROMREV_MAX}

#define _BHND_SPROM_VAL_DECL(...)					\
{									\
	.segs		= _BHND_NV_VA_ARRAY(sprom_vseg, __VA_ARGS__),	\
	.num_segs	=						\
	    nitems(_BHND_NV_VA_ARRAY(sprom_vseg, __VA_ARGS__))		\
}

#define	BHND_SPROM_MAPPING(_compat, ...)		\
	_BHND_SPROM_VAR_DECL(_compat, __VA_ARGS__)

#define	BHND_SPROM_VAL(_offset, _type, _mask, _shift)	\
	_BHND_SPROM_VAL_DECL({				\
	    _offset, sizeof(_type), _mask, _shift	\
	})

#define	BHND_SPROM_VAL_U8(_offset)	\
	BHND_SPROM_VAL(_offset, uint8_t, UINT8_MAX, 0)

#define	BHND_SPROM_VAL_U16(_offset)	\
	BHND_SPROM_VAL(_offset, uint16_t, UINT16_MAX, 0)

#define	BHND_SPROM_VAL_U32(_offset)	\
	BHND_SPROM_VAL(_offset, uint32_t, UINT32_MAX, 0)

#define	BHND_SPROM_SPARSE_VAL(...)	_BHND_SPROM_VAL_DECL(__VA_ARGS__)

#define	nitems(x)	(sizeof((x)) / sizeof((x)[0]))
