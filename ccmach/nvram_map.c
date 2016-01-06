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
#include "nvram_map.h"
#include <stdbool.h>

static const struct bhnd_sprom_struct bhnd_sprom_structs[] = {
	{ { 0, BHND_SPROMREV_MAX }, 0xBABE },
};

const struct bhnd_nvram_var nvram_vars[] = {
	{"noisecaloffset5g", BHND_NVRAM_DT_UINT, BHND_NVRAM_SFMT_HEX, BHND_NVRAM_VF_DFLT, 0, (struct bhnd_sprom_var[]) {
		{{256, 1023}, NULL, 0, (struct bhnd_sprom_value[]) {
			{(struct bhnd_sprom_seg []) {
					{0x01B4,	1,	0xFF00,	8},
			}, 1},
		}, 1},
	}, 1},
};

static uint16_t
bhnd_sprom_compat (const struct bhnd_sprom_compat *compat, uint16_t spromver)
{
	return (spromver >= compat->first && spromver <= compat->last);
}

static bool
bhnd_sprom_find_base (const struct bhnd_sprom_var *var, uint16_t spromver,
    uint16_t *base)
{
	/* non-struct variables always match with a 0x0 base */
	if (var->num_structs == 0) {
		*base = 0x0;
		return (true);
	}

	/* find the matching struct base address */
	for (size_t i = 0; i < var->num_structs; i++) {
		if (!bhnd_sprom_compat(&var->structs[i].compat, spromver))
			continue;

		*base = var->structs[i].base_addr;
		return (true);
	}

	return (false);
}

static const struct bhnd_sprom_var *
bhnd_nvram_find_sprom (const struct bhnd_nvram_var *var, uint16_t spromver)
{
	for (size_t i = 0; i < var->num_sp_descs; i++) {
		if (!bhnd_sprom_compat(&var->sprom_descs[i].compat, spromver))
			continue;
		return (&var->sprom_descs[i]);
	}

	return (NULL);
}

int main (int argc, char * const argv[]) {
	uint16_t spromver = 256;

	for (size_t vid = 0; vid < nitems(nvram_vars); vid++) {
		const struct bhnd_sprom_var *sv;
		uint16_t base;

		sv = bhnd_nvram_find_sprom(&nvram_vars[vid], spromver);
		if (sv == NULL) {
			printf("%s not defined on %hu\n", nvram_vars[vid].name, spromver);
			continue;
		}

		if (!bhnd_sprom_find_base(sv, spromver, &base)) {
			printf("%s base address not defined on %hu\n", nvram_vars[vid].name, spromver);
			continue;
		}

		printf("%s at base=0x%hx\n", nvram_vars[vid].name, base);
	}
}