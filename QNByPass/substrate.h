#ifndef SUBSTRATE_H_
#define SUBSTRATE_H_

#include <objc/runtime.h>

#ifdef __cplusplus
extern "C" {
#endif

void MSHookFunction(void *symbol, void *replace, void **result);
void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result);

#ifdef __cplusplus
}
#endif

#endif
