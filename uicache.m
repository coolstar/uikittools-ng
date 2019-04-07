#import <stdio.h>
#import <getopt.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1 internal:(BOOL)arg2 user:(BOOL)arg3;
- (BOOL)registerApplicationDictionary:(id)arg1;
- (BOOL)registerApplication:(id)arg1;
- (BOOL)registerPlugin:(id)arg1;
- (BOOL)unregisterApplication:(id)arg1;
- (NSArray *)installedPlugins;
@end

typedef NS_OPTIONS(NSUInteger, SBSRelaunchActionOptions) {
	SBSRelaunchActionOptionsNone,
	SBSRelaunchActionOptionsRestartRenderServer = 1 << 0,
	SBSRelaunchActionOptionsSnapshotTransition = 1 << 1,
	SBSRelaunchActionOptionsFadeToBlackTransition = 1 << 2
};

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason options:(SBSRelaunchActionOptions)options targetURL:(NSURL *)targetURL;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)result;
@end

void help(char *name) {
	printf(
		"Usage: %s [OPTION...]\n"
		"Update iOS registered applications and optionally restart SpringBoard\n\n"

		"  --all           Update all system and internal applications\n"
		"                     (replicates the old uicache behavior)\n"
		"  --path <path>   Update application bundle at the specified path\n"
		"  --respring      Restart SpringBoard and backboardd after\n"
		"                     updating applications.\n"
		"  --help          Give this help list.\n\n"

		"Email the Electra team via Sileo for support.\n", name);
}

int main(int argc, char *argv[]){
	@autoreleasepool {
		int all;
		char *path = NULL;
		int respring;
		int showhelp;

		struct option longOptions[] = {
			{ "all" , no_argument, 0, 'a'},
			{ "path", required_argument, 0, 'p'},
			{ "respring", no_argument, 0, 'r' },
			{ "help", no_argument, 0, '?' },
			{ NULL, 0, NULL, 0 }
		};

		int index = 0, code = 0;

		while ((code = getopt_long(argc, argv, "ap:rh?", longOptions, &index)) != -1) {
			switch (code) {
				printf("Code: %c\n", code);
				case 'a':
					all = 1;
					break;
				case 'p':
					path = strdup(optarg);
					break;
				case 'r':
					respring = 1;
					break;
				case 'h':
					showhelp = 1;
					break;
			}
		}

		if (showhelp){
			help(argv[0]);
			return 0;
		}

		if (path){
			NSString *rawPath = [NSString stringWithUTF8String:path];
			rawPath = [rawPath stringByResolvingSymlinksInPath];
			if (![[rawPath stringByDeletingLastPathComponent] isEqualToString:@"/Applications"]){
				fprintf(stderr, "Error: Application must be a system application!\n");
				return -1;
			}

			NSString *infoPlist = [rawPath stringByAppendingPathComponent:@"Info.plist"];
			NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlist];
			[plist setObject:@"System" forKey:@"ApplicationType"];
			[plist setObject:rawPath forKey:@"Path"];

			LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
			if (plist){
				[workspace registerApplicationDictionary:plist];

				/*NSString *pluginsPath = [rawPath stringByAppendingPathComponent:@"PlugIns"];
				NSArray *plugins = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath error:nil];
				for (NSString *pluginName in plugins){
					NSString *fullPath = [pluginsPath stringByAppendingPathComponent:pluginName];
					printf("Attempting to register plugin at: %s\n", [fullPath UTF8String]);

					NSURL *pluginURL = [NSURL fileURLWithPath:fullPath];

					[workspace registerPlugin:pluginURL];
				}*/
			} else {
				NSURL *url = [NSURL fileURLWithPath:rawPath];
				[workspace unregisterApplication:url];
			}
			free(path);
		}
		
		dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW);
		dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);

		
		if (all){
			[[LSApplicationWorkspace defaultWorkspace] _LSPrivateRebuildApplicationDatabasesForSystemApps:YES internal:YES user:NO];
		}

		if (respring){
			SBSRelaunchAction *restartAction = [objc_getClass("SBSRelaunchAction") actionWithReason:@"respring" options:(SBSRelaunchActionOptionsRestartRenderServer | SBSRelaunchActionOptionsFadeToBlackTransition) targetURL:nil];
			[(FBSSystemService *)[objc_getClass("FBSSystemService") sharedService] sendActions:[NSSet setWithObject:restartAction] withResult:nil];
			sleep(2);
		}

		return 0;
	}
}
