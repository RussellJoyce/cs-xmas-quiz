#!/usr/bin/env python3

print('#include "ledmapping.h"')
print('')
print('const uint8_t ledlookup[] = {')

for i in range(0, 100):
	print('\t{0},  \t//{1}'.format(i, i*2))
	print('\t{0},  \t//{1}'.format(199-i, i*2+1))

print('};')
