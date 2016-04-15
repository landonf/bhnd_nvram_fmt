#!/bin/sh
./build/products/Debug/ccmach -- -Iccmach/bcm ccmach/bcm/bcmsrom.c >nvram_map_v3
