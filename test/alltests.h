#ifndef _ALLTESTS_H_
#define _ALLTESTS_H_

#include <stdbool.h>
#include <stdint.h>

bool runtests_dcb(uint32_t* passedtests);
bool runtests_fetchsh(uint32_t* passedtests);
bool runtests_gcn(uint32_t* passedtests);
bool runtests_gnf(uint32_t* passedtests);
bool runtests_gpuaddr(uint32_t* passedtests);
bool runtests_pssl(uint32_t* passedtests);

#endif	// _ALLTESTS_H_
