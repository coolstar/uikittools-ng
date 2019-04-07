#import <Foundation/Foundation.h>

NSString *MGCopyAnswer(NSString *key);

int main(){
	printf("%s\n", [MGCopyAnswer(@"UniqueDeviceID") UTF8String]);
	return 0;
}