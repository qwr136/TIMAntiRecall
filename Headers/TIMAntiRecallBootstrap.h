#pragma once
#include <stdbool.h>
#include <stddef.h>

// Sandbox only; no Foundation, dispatch or app identity is needed to reach disk.
bool timantirecall_bootstrapEvent(const char *event);
void timantirecall_bootstrapSafeValue(const char *input, char *output, size_t capacity);
#ifdef TIMANTIRECALL_NATIVE_TEST
bool timantirecall_bootstrapWrite(const char *home, const char *temporary, const char *event);
#endif
