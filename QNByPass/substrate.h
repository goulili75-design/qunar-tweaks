/*
 * Minimal substrate.h stub for compilation
 * Only provides the APIs used by QNByPass tweak
 */

#ifndef SUBSTRATE_H_
#define SUBSTRATE_H_

#include <objc/runtime.h>
#include <mach/mach.h>

#ifdef __cplusplus
extern "C" {
#endif

// MSHookFunction
void MSHookFunction(void *symbol, void *replace, void **result);

// MSHookMessageEx - hook ObjC instance method
void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result);

#ifdef __cplusplus
}
#endif

#endif // SUBSTRATE_H_
