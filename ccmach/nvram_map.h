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
#include <stdbool.h>

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
	BHND_NVRAM_VFMT_HEX,		/**< hex string format */
	BHND_NVRAM_VFMT_SDEC,		/**< signed decimal format */
	BHND_NVRAM_VFMT_MACADDR,	/**< mac address (canonical form, hex octets,
					     seperated with ':') */
	BHND_NVRAM_VFMT_CCODE		/**< ASCII string */
} bhnd_nvram_fmt;

/** NVRAM variable flags */
enum {
	BHND_NVRAM_VF_DFLT	= 0,
	BHND_NVRAM_VF_ARRAY	= (1<<0),	/**< variable is an array */
	BHND_NVRAM_VF_MFGINT	= (1<<1),	/**< mfg-internal variable; should not be externally visible */
	BHND_NVRAM_VF_IGNALL1	= (1<<2)	/**< hide variable if its value has all bits set. */
};

#define	BHND_SPROMREV_MAX	UINT16_MAX	/**< maximum supported SPROM revision */

/** SPROM revision compatibility declaration */
struct bhnd_sprom_compat {
	uint16_t	first;	/**< first compatible SPROM revision */
	uint16_t	last;	/**< last compatible SPROM revision, or BHND_SPROMREV_MAX */
};

/** SPROM value descriptor */
struct bhnd_sprom_offset {
	uint16_t	offset;	/**< byte offset within SPROM */
	size_t		width;	/**< 1, 2, or 4 bytes */
	size_t		count;	/**< the number of consecutive readable elements */
	uint32_t	mask;	/**< mask to be applied to the value(s) */
	size_t		shift;	/**< shift to be applied to the value */
	bool		cont;	/**< value should be bitwise OR'd with the next offset
				  *  descriptor */
};

/** SPROM-specific variable definition */
struct bhnd_sprom_var {
	struct bhnd_sprom_compat	 compat;	/**< sprom compatibility declaration */
	const struct bhnd_sprom_offset	*offsets;	/**< offset descriptors */
	size_t				 num_offsets;	/**< number of offset descriptors */
};

/** NVRAM variable definition */
struct bhnd_nvram_var {
	const char			*name;		/**< variable name */
	bhnd_nvram_dt			 type;		/**< base data type */
	bhnd_nvram_fmt			 fmt;		/**< string format */
	uint32_t			 flags;		/**< BHND_NVRAM_VF_* flags */

	const struct bhnd_sprom_var	*sprom_descs;	/**< SPROM-specific variable descriptors */
	size_t				 num_sp_descs;	/**< number of sprom descriptors */
};
