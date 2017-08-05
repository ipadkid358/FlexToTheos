#if TARGET_OS_IPHONE
@interface UIDevice (PrivateBlackJacket)
- (NSString *)_deviceInfoForKey:(NSString *)key;
@end
#else
@import Foundation;
#endif

int main (int argc, char **argv) {
    int choice = -1;
    NSString *version = @"0.0.1";
    NSString *sandbox = @"Sandbox";
    NSString *name = @"by ipad_kid and open source on GitHub (ipadkid358/FlexToTheos)";
    NSString *patchID = nil;
    BOOL dump = NO;
    BOOL tweak = YES;
    BOOL smart = NO;
    BOOL output = YES;
    BOOL color = YES;
    BOOL getPlist = NO;
    int c;
    while ((c = getopt(argc, argv, ":c:f:n:v:p:dtsbog")) != -1)
        switch(c) {
            case 'c':
                patchID = [NSString stringWithFormat:@"%s", optarg];
                break;
            case 'f':
                sandbox = [NSString stringWithFormat:@"%s", optarg];
                if ([sandbox componentsSeparatedByString:@" "].count > 1) {
                    printf("Invalid folder name, spaces are not allowed\n");
                    exit(-1);
                }
                break;
            case 'n':
                name = [NSString stringWithFormat:@"%s", optarg];
                break;
            case 'v':
                version = [NSString stringWithFormat:@"%s", optarg];
                break;
            case 'p':
                choice = [NSString stringWithFormat:@"%s", optarg].intValue;
                break;
            case 'd':
                dump = YES;
                break;
            case 't':
                tweak = NO;
                break;
            case 's':
                smart = YES;
                break;
            case 'o':
                output = NO;
                break;
            case 'b':
                color = NO;
                break;
            case 'g':
                getPlist = YES;
                break;
            case '?':
                printf("\n  Usage: %s [OPTIONS]\n   Options:\n", argv[0]);
                printf("      -f    Set name of folder created for project (default is %s)\n", sandbox.UTF8String);
                printf("      -n    Override the tweak name\n");
                printf("      -v    Set version (default is  %s)\n", version.UTF8String);
                printf("      -p    Directly plug in number\n");
                printf("      -c    Get patches directly from the cloud. Downloads use your Flex downloads.\n");
                printf("              Free accounts still have limits. Patch IDs are the last digits in share links\n");
                printf("      -d    Only print available local patches, don't do anything (cannot be used with any other options)\n");
                printf("      -t    Only print Tweak.xm to console\n");
                printf("      -s    Enable smart comments\n");
                printf("      -o    Disable output, except errors\n");
                printf("      -b    Disable colors in output\n");
                printf("\n");
                exit(-1);
                break;
        }
    
    if (!output) color = NO;
    
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSDictionary *patch;
    NSString *titleKey;
    NSString *appBundleKey;
    NSString *descriptionKey;
    if (patchID) {
        NSDictionary *flexPrefs = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.johncoates.Flex.plist"];
        
        NSMutableDictionary *bodyDict = NSMutableDictionary.new;
        bodyDict[@"patchID"] = patchID;
#if TARGET_OS_IPHONE // because UIKit isn't a thing on MacOS, this allows us to compile with Xcode
        bodyDict[@"deviceID"] = [UIDevice.currentDevice _deviceInfoForKey:@"UniqueDeviceID"];
#endif
        bodyDict[@"sessionID"] = flexPrefs[@"session"];
        
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api2.getflex.co/patch/download"]];
        [req setHTTPMethod:@"POST"];
        [req setHTTPBody:[NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:NULL]];
        if (color) printf("\x1B[36m");
        if (output) printf("Getting patch %s from Flex servers\n", patchID.UTF8String);
        if (color) printf("\x1B[0m");
        
        __block NSDictionary *getPatch = nil;
        __block CFRunLoopRef runLoop = CFRunLoopGetCurrent();
        NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (data == nil || error != nil) {
                printf("Error getting patch\n");
                if (error) NSLog(@"%@", error);
                exit(-1);
            }
            
            getPatch = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (!getPatch[@"units"]) {
                printf("Error getting patch\n");
                if (getPatch) NSLog(@"%@", getPatch);
                else NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                exit(-1);
            }
            
            CFRunLoopStop(runLoop);
        }];
        [task resume];
        CFRunLoopRun();
        
        patch = getPatch;
        titleKey = @"title";
        appBundleKey = @"applicationIdentifier";
        descriptionKey = @"description";
    } else {
        NSDictionary *file;
        NSString *firstPath = @"/var/mobile/Library/Application Support/Flex3/patches.plist";
        NSString *secondPath = @"/var/mobile/Library/UserConfigurationProfiles/PublicInfo/Flex3Patches.plist";
        if (getPlist) file = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:@"https://ipadkid358.github.io/ftt/patches.plist"]];
        else if ([fileManager fileExistsAtPath:firstPath]) file = [[NSDictionary alloc] initWithContentsOfFile:firstPath];
        else if ([fileManager fileExistsAtPath:secondPath]) file = [[NSDictionary alloc] initWithContentsOfFile:secondPath];
        else {
            printf("File not found, please ensure Flex 3 is installed (if you're using an older version of Flex, please contact me at https://ipadkid358.github.io/contact.html)");
            exit(-1);
        }
        
        NSArray *allPatches = file[@"patches"];
        unsigned long allPatchesCount = allPatches.count;
        if (choice == -1) {
            for (int choose = 0; choose < allPatchesCount; choose++) {
                printf("  %i: ", choose);
                printf("%s\n", [allPatches[choose][@"name"] UTF8String]);
            }
            
            if (dump) exit(0);
            printf("Enter corresponding number: ");
            scanf("%i", &choice);
        }
        
        if (allPatchesCount <= choice) {
            printf("Please input a valid number between 0 and %lu\n", allPatchesCount-1);
            exit(-1);
        }
        
        patch = allPatches[choice];
        titleKey = @"name";
        appBundleKey = @"appIdentifier";
        descriptionKey = @"cloudDescription";
    }
    
    BOOL uikit = NO;
    
    // Tweak.xm handling
    NSMutableString *xm = NSMutableString.new;
    for (NSDictionary *top in patch[@"units"]) {
        NSDictionary *units = top[@"methodObjc"];
        
        // Class name handling
        [xm appendFormat:@"%%hook %@\n", units[@"className"]];
        
        // Method name handling
        NSArray *displayName = [units[@"displayName"] componentsSeparatedByString:@")"];
        [xm appendFormat:@"%@)%@", displayName[0], displayName[1]];
        for (int methodBreak = 2; methodBreak < displayName.count; methodBreak++) [xm appendFormat:@")arg%i%@", methodBreak-1, displayName[methodBreak]];
        [xm appendString:@" { \n"];
        
        // Argument handling
        NSArray *allOverrides = top[@"overrides"];
        for (NSDictionary *override in allOverrides) {
            if (override.allKeys.count == 0) continue;
            NSString *origValue = override[@"value"][@"value"];
            if ([origValue isKindOfClass:NSString.class]) {
                if (origValue.length >= 8 && [[origValue substringToIndex:8] isEqualToString:@"(FLNULL)"]) origValue = @"nil";
                else if (origValue.length >= 8 && [[origValue substringToIndex:8] isEqualToString:@"FLcolor:"]) {
                    NSArray *color = [[origValue substringFromIndex:8] componentsSeparatedByString:@","];
                    origValue = [NSString stringWithFormat:@"[UIColor colorWithRed:%@.0/255.0 green:%@.0/255.0 blue:%@.0/255.0 alpha:%@.0/255.0]", color[0], color[1], color[2], color[3]];
                    uikit = YES;
                } else origValue = [NSString stringWithFormat:@"@\"%@\"", origValue];
            }
            int argument = [override[@"argument"] intValue];
            if (argument == 0) {
                [xm appendFormat:@"    return %@; \n", origValue];
                break;
            } else [xm appendFormat:@"    arg%i = %@;\n", argument, origValue];
        }
        
        if (allOverrides.count == 0 || [allOverrides[0][@"argument"] intValue] > 0) {
            if ([displayName[0] isEqualToString:@"-(void"]) [xm appendFormat:@"    %%orig;\n"];
            else [xm appendFormat:@"    return %%orig;\n"];
        }
        if (smart) {
            NSString *smartComment = top[@"name"];
            NSString *defaultComment = [NSString stringWithFormat:@"Unit for %@", top[@"methodObjc"][@"displayName"]];
            if (smartComment.length > 0 && ![smartComment isEqualToString:defaultComment]) [xm appendFormat:@"    // %@\n", smartComment];
        }
        [xm appendFormat:@"} \n%%end\n\n"];
    }
    
    if (tweak) {
        NSCharacterSet *charsOnly = NSCharacterSet.alphanumericCharacterSet.invertedSet;
        // Creating sandbox
        if ([fileManager fileExistsAtPath:sandbox]) {
            printf("%s already exists\n", sandbox.UTF8String);
            exit(-1);
        }
        [fileManager createDirectoryAtPath:sandbox withIntermediateDirectories:NO attributes:NULL error:NULL];
        
        // Makefile handling
        if ([name isEqualToString:@"by ipad_kid and open source on GitHub (ipadkid358/FlexToTheos)"]) name = patch[titleKey];
        NSString *title = [[name componentsSeparatedByCharactersInSet:charsOnly] componentsJoinedByString:@""];
        NSMutableString *makefile = [NSMutableString stringWithFormat:@"DEBUG=0\ninclude $(THEOS)/makefiles/common.mk\n\nTWEAK_NAME = %@\n%@_FILES = Tweak.xm\n", title, title];
        if (uikit) [makefile appendFormat:@"%@_FRAMEWORKS = UIKit\n", title];
        [makefile appendString:@"\ninclude $(THEOS_MAKE_PATH)/tweak.mk"];
        [makefile writeToFile:[NSString stringWithFormat:@"%@/Makefile", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        // plist handling
        NSString *executable = patch[appBundleKey];
        if ([executable isEqualToString: @"com.flex.systemwide"]) executable = @"com.apple.UIKit";
        NSDictionary *plist = @{@"Filter": @{@"Bundles": @[executable]}};
        NSString *plistPath = [NSString stringWithFormat:@"%@/%@.plist", sandbox, title];
        [plist writeToFile:plistPath atomically:YES];
        
        // Control file handling
        NSString *author = patch[@"author"];
        NSString *authorChar = [[author componentsSeparatedByCharactersInSet:charsOnly] componentsJoinedByString:@""];
        NSString *description = [patch[descriptionKey] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n "];
        NSString *control = [NSString stringWithFormat:@"Package: com.%@.%@\nName: %@\nAuthor: %@\nDescription: %@\nDepends: mobilesubstrate\nMaintainer: ipad_kid <ipadkid358@gmail.com>\nArchitecture: iphoneos-arm\nSection: Tweaks\nVersion: %@\n", authorChar, title, name, author, description, version];
        [control writeToFile:[NSString stringWithFormat:@"%@/control", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        [xm writeToFile:[NSString stringWithFormat:@"%@/Tweak.xm", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        if (color) printf("\x1B[32m");
        if (output) printf("Project %s created in %s\n", title.UTF8String, sandbox.UTF8String);
        if (color) printf("\x1B[0m");
    } else {
        printf("\n\n%s", xm.UTF8String);
        freopen("/dev/null", "w", stderr);
#if TARGET_OS_IPHONE // this allows us to compile with Xcode
        [UIPasteboard.generalPasteboard setString:xm];
#endif
        fclose(stderr);
        if (color) printf("\x1B[32m");
        if (output) printf("Output has successfully been copied to your clipboard. You can now easily paste this output in your .xm file\n");
        if (uikit) {
            if (color) printf("\x1B[31m");
            if (output) printf("\nPlease add UIKit to your project's FRAMEWORKS because this tweak includes color specifying\n");
        }
        if (color) printf("\x1B[0m");
        if (output) printf("\n");
    }
    return 0;
}
