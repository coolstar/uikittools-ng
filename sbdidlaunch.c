#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>

void OnDidLaunch(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef info
) {
    exit(0);
}

int main(){
	CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        &OnDidLaunch,
        CFSTR("SBSpringBoardDidLaunchNotification"),
        NULL,
        0
    );

	void *springboardservices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
	void *(*SBSSpringBoardServerPort)(void) = dlsym(springboardservices, "SBSSpringBoardServerPort");

	if (SBSSpringBoardServerPort() == NULL)
		dispatch_main();
	return 0;
}