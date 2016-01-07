//
//  nvram_map.c
//  ccmach
//
//  Created by Landon Fuller on 1/1/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <string.h>
#include "../m.h"

#define	nitems(x)	(sizeof((x)) / sizeof((x)[0]))

static const struct bhnd_nvram_var *
bhnd_nvram_find_var (const char *name)
{
	for (size_t i = 0; i < nitems(nvram_vars); i++) {
		if (strcmp(nvram_vars[i].name, name) == 0)
			return &nvram_vars[i];
	}

	return (NULL);
}

static const struct bhnd_sprom_var *
bhnd_nvram_find_sprom_var (const struct bhnd_nvram_var *nv, uint16_t sprom_ver)
{
	for (size_t sp = 0; sp < nv->num_sp_descs; sp++) {
		const struct bhnd_sprom_var *v = &nv->sprom_descs[sp];
		if (sprom_ver >= v->compat.first && sprom_ver <= v->compat.last)
			return (v);
	}

	return (NULL);
}

static size_t
bhnd_nvram_type_width (bhnd_nvram_dt type)
{
	switch (type)
	{
		case BHND_NVRAM_DT_UINT:
			return (sizeof(uint32_t));
		case BHND_NVRAM_DT_SINT:
			return (sizeof(int32_t));
		case BHND_NVRAM_DT_MAC48:
			return (sizeof(uint8_t) * 48); // TODO
		case BHND_NVRAM_DT_LEDDC:
			return (1); // TODO
		case BHND_NVRAM_DT_CCODE:
			return sizeof(char[4]); // TODO
	}
}

#ifdef NVRAM_MAIN
int main (int argc, char * const argv[]) {
	uint16_t sprom_ver = 2048;
	const char *vname = argv[1];

	const struct bhnd_nvram_var *nv;
	const struct bhnd_sprom_var *v;

	nv = bhnd_nvram_find_var(vname);
	if (nv == NULL) {
		printf("'%s' not found\n", vname);
		return 1;
	}

	v = bhnd_nvram_find_sprom_var(nv, sprom_ver);
	if (v == NULL) {
		printf("sprom entry for %s not found\n", vname);
		return 1;
	}

	printf("found %s with type %u (%zu bytes)\n", vname, nv->type, bhnd_nvram_type_width(nv->type));
	if (nv->flags & BHND_NVRAM_VF_ARRAY) {
		printf("array\n");
	}
    return 0;
}
#endif