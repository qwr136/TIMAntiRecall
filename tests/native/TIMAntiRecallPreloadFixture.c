// Harmless test-only dylib to put a non-executable image at dyld index zero.
__attribute__((constructor)) static void timantirecall_preloadFixture(void) { }
