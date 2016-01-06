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


const struct bhnd_nvram_var nvram_vars[] = {
    BHND_NVRAM_VAR(poodle, UINT, SFMT_HEX, VF_DFLT, 0,
                   BHND_SPROM_MAPPING(REV_GTE(1),
                                      BHND_SPROM_VAL_U32(0xFFEE)
                                      )
                   ),
    BHND_NVRAM_VAR(puddles, UINT, SFMT_HEX, VF_ARRAY, 5,
                   BHND_SPROM_MAPPING(REV_EQ(1), BHND_SPROM_SPARSE_VAL(
                                                                       {0xFFEE, sizeof(uint32_t), UINT32_MAX, 0},
                                                                       {0xFFEE, sizeof(uint32_t), UINT32_MAX, 0})
                                      )
                   )
};

int main (int argc, char * const argv[]) {
	uint16_t spromver = 256;

	for (size_t vid = 0; vid < nitems(nvram_vars); vid++) {
		printf("%s\n", nvram_vars[vid].name);
	}
}
