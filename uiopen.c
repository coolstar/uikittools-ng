#include <stdio.h>
#include <dlfcn.h>
#include <CoreFoundation/CoreFoundation.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s url\n", argv[0]);
        return 1;
    }

    CFURLRef url = CFURLCreateWithBytes(NULL, (uint8_t *)argv[1], strlen(argv[1]), kCFStringEncodingUTF8, NULL);
    if(!url) {
        fprintf(stderr, "invalid URL\n");
        return 1;
    }

    void *sbs = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    void (*SBSOpenSensitiveURLAndUnlock)(CFURLRef, int) = (void (*)(CFURLRef, int)) dlsym(sbs, "SBSOpenSensitiveURLAndUnlock");

    SBSOpenSensitiveURLAndUnlock(url, 1);
    return 0;
}
