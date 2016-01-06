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
#include "../m.h"

int main (int argc, char * const argv[]) {
	uint16_t spromver = 256;

	for (size_t vid = 0; vid < nitems(nvram_vars); vid++) {
		printf("%s\n", nvram_vars[vid].name);
	}
}
