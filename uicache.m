#import <stdio.h>
#import <getopt.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (BOOL)_LSPrivateRebuildApplicationDatabasesForSystemApps:(BOOL)arg1 internal:(BOOL)arg2 user:(BOOL)arg3;
- (BOOL)registerApplicationDictionary:(NSDictionary *)applicationDictionary;
- (BOOL)registerBundleWithInfo:(NSDictionary *)bundleInfo options:(NSDictionary *)options type:(unsigned long long)arg3 progress:(id)arg4 ;
- (BOOL)registerApplication:(NSURL *)url;
- (BOOL)registerPlugin:(NSURL *)url;
- (BOOL)unregisterApplication:(NSURL *)url;
- (NSArray *)installedPlugins;
-(void)_LSPrivateSyncWithMobileInstallation;
@end

typedef NS_OPTIONS(NSUInteger, SBSRelaunchActionOptions) {
	SBSRelaunchActionOptionsNone,
	SBSRelaunchActionOptionsRestartRenderServer = 1 << 0,
	SBSRelaunchActionOptionsSnapshotTransition = 1 << 1,
	SBSRelaunchActionOptionsFadeToBlackTransition = 1 << 2
};

@interface MCMContainer : NSObject
+ (instancetype)containerWithIdentifier:(NSString *)identifier error:(NSError **)error;
- (NSURL *)url;
@end

@interface MCMAppDataContainer : MCMContainer
@end

@interface MCMPluginKitPluginDataContainer : MCMContainer
@end

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
			dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_NOW);

			NSString *rawPath = [NSString stringWithUTF8String:path];
			rawPath = [rawPath stringByResolvingSymlinksInPath];
			if (![[rawPath stringByDeletingLastPathComponent] isEqualToString:@"/Applications"]){
				fprintf(stderr, "Error: Application must be a system application!\n");
				return -1;
			}

			NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:[rawPath stringByAppendingPathComponent:@"Info.plist"]];
			NSString *bundleID = [infoPlist objectForKey:@"CFBundleIdentifier"];

			MCMContainer *appContainer = [objc_getClass("MCMAppDataContainer") containerWithIdentifier:bundleID error:nil];
			NSString *containerPath = [appContainer url].path;

			NSMutableDictionary *plist = [NSMutableDictionary dictionary];
			[plist setObject:@"System" forKey:@"ApplicationType"];
			[plist setObject:@1 forKey:@"BundleNameIsLocalized"];
			[plist setObject:bundleID forKey:@"CFBundleIdentifier"];
			[plist setObject:@0 forKey:@"CompatibilityState"];
			if (containerPath)
				[plist setObject:containerPath forKey:@"Container"];
			[plist setObject:@0 forKey:@"IsDeletable"];
			[plist setObject:rawPath forKey:@"Path"];

			NSURL *url = [NSURL fileURLWithPath:rawPath];

			LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
			if (bundleID){
				NSString *pluginsPath = [rawPath stringByAppendingPathComponent:@"PlugIns"];
				NSArray *plugins = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath error:nil];

				NSMutableDictionary *bundlePlugins = [NSMutableDictionary dictionary];
				for (NSString *pluginName in plugins){
					NSString *fullPath = [pluginsPath stringByAppendingPathComponent:pluginName];

					NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:[fullPath stringByAppendingPathComponent:@"Info.plist"]];
					NSString *pluginBundleID = [infoPlist objectForKey:@"CFBundleIdentifier"];
					if (!pluginBundleID)
						continue;
					MCMContainer *pluginContainer = [objc_getClass("MCMPluginKitPluginDataContainer") containerWithIdentifier:pluginBundleID error:nil];
					NSString *pluginContainerPath = [pluginContainer url].path;

					NSMutableDictionary *pluginPlist = [NSMutableDictionary dictionary];
					[pluginPlist setObject:@"PluginKitPlugin" forKey:@"ApplicationType"];
					[pluginPlist setObject:@1 forKey:@"BundleNameIsLocalized"];
					[pluginPlist setObject:pluginBundleID forKey:@"CFBundleIdentifier"];
					[pluginPlist setObject:@0 forKey:@"CompatibilityState"];
					[pluginPlist setObject:pluginContainerPath forKey:@"Container"];
					[pluginPlist setObject:fullPath forKey:@"Path"];
					[pluginPlist setObject:bundleID forKey:@"PluginOwnerBundleID"];
					[bundlePlugins setObject:pluginPlist forKey:pluginBundleID];
				}
				[plist setObject:bundlePlugins forKey:@"_LSBundlePlugins"];
				if (![workspace registerApplicationDictionary:plist]){
					fprintf(stderr, "Error: Unable to register app!\n");
				}
			} else {
				if (![workspace unregisterApplication:url]){
					fprintf(stderr, "Error: Unable to unregister app!\n");
				}
			}
			free(path);
		}
		
		if (all){
			[[LSApplicationWorkspace defaultWorkspace] _LSPrivateRebuildApplicationDatabasesForSystemApps:YES internal:YES user:NO];
		}

		if (respring){
			dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW);
			dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);

			SBSRelaunchAction *restartAction = [objc_getClass("SBSRelaunchAction") actionWithReason:@"respring" options:(SBSRelaunchActionOptionsRestartRenderServer | SBSRelaunchActionOptionsFadeToBlackTransition) targetURL:nil];
			[(FBSSystemService *)[objc_getClass("FBSSystemService") sharedService] sendActions:[NSSet setWithObject:restartAction] withResult:nil];
			sleep(2);
		}

		return 0;
	}
}
