#include <stdio.h>
#include <dlfcn.h>
#include <Foundation/Foundation.h>

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(NSDictionary *)options;
@end

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s url\n", argv[0]);
        return 1;
    }

    NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:argv[1]]];

    void *fbs = dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW);
    NSString **FBSOpenApplicationOptionKeyUnlockDevice = dlsym(fbs, "FBSOpenApplicationOptionKeyUnlockDevice");
    [[LSApplicationWorkspace defaultWorkspace] openSensitiveURL:url withOptions:@{*FBSOpenApplicationOptionKeyUnlockDevice:@YES}];
    return 0;
}
