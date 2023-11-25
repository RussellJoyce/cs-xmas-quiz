#!/usr/bin/env python3
import random

print('#include "ledmapping.h"')
print('')
print('const uint8_t ledlookup[] = {')

for i in range(0, 100):
	print('\t{0},  \t//{1}'.format(i, i*2))
	print('\t{0},  \t//{1}'.format(199-i, i*2+1))

print('};')
print('')
print('const uint8_t ledlookup_rand[] = {')

vals = list(range(200))
random.shuffle(vals)
for i in range(0, 200):
	print('\t{0},  \t//{1}'.format(vals[i], i))

print('};')
