#import <UIKit/UIKit.h>

@interface UIDevice (PrivateBlackJacket)
- (NSString *)_deviceInfoForKey:(NSString *)key;
@end

int main(int argc, char *argv[]) {
    int choice = -1;
    NSString *version = @"0.0.1";
    NSString *sandbox = @"Sandbox";
    NSString *name;
    NSString *patchID;
    NSString *remote;
    BOOL dump = NO;
    BOOL tweak = YES;
    BOOL smart = NO;
    BOOL output = YES;
    BOOL color = YES;
    
    // should be used for testing only
    BOOL getPlist = NO;
    
    int c;
    while ((c = getopt(argc, argv, ":c:f:n:r:v:p:dtsbog")) != -1) {
        switch(c) {
            case 'c':
                patchID = [NSString stringWithUTF8String:optarg];
                unsigned int smallValidPatch = 6106;
                if (patchID.intValue < smallValidPatch) {
                    printf("Sorry, this is an older patch, and not yet supported\n"
                           "Please use a patch number greater than %d\n"
                           "Patch numbers are the last digits in share links\n", smallValidPatch);
                    return 1;
                }
                break;
            case 'f':
                sandbox = [NSString stringWithUTF8String:optarg];
                if ([[sandbox componentsSeparatedByString:@" "] count] > 1) {
                    printf("Invalid folder name, spaces are not allowed, becuase they break make\n");
                    return 1;
                }
                break;
            case 'r':
                remote = [NSString stringWithUTF8String:optarg];
                break;
            case 'n':
                name = [NSString stringWithUTF8String:optarg];
                break;
            case 'v':
                version = [NSString stringWithUTF8String:optarg];
                break;
            case 'p':
                choice = [[NSString stringWithUTF8String:optarg] intValue];
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
                printf("Usage: %s [OPTIONS]\n"
                       " Options:\n"
                       "   -f    Set name of folder created for project (default is %s)\n"
                       "   -n    Override the tweak name\n"
                       "   -v    Set version (default is  %s)\n"
                       "   -p    Directly plug in number\n"
                       "   -c    Get patches directly from the cloud. Downloads use your Flex downloads.\n"
                       "           Free accounts still have limits. Patch IDs are the last digits in share links\n"
                       "   -r    Get remote patch from 3rd party (generally used to fetch from Sinfool repo)\n"
                       "   -d    Only print available local patches, don't do anything (cannot be used with any other options)\n"
                       "   -t    Only print Tweak.xm to console\n"
                       "   -s    Enable smart comments\n"
                       "   -o    Disable output, except errors\n"
                       "   -b    Disable colors in output\n", argv[0], sandbox.UTF8String, version.UTF8String);
                return 1;
                break;
        }
    }
    
    const char *cyanColor = "";
    const char *redColor = "";
    const char *greenColor = "";
    const char *resetColor = "";
    if (color) {
        cyanColor = "\x1B[36m";
        redColor = "\x1B[31m";
        greenColor = "\x1B[32m";
        resetColor = "\x1B[0m";
    }
    
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSDictionary *patch;
    NSString *titleKey;
    NSString *appBundleKey;
    NSString *descriptionKey;
    if (patchID || remote) {
        if (patchID) {
            NSDictionary *flexPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.johncoates.Flex.plist"];
            NSString *udid = [UIDevice.currentDevice _deviceInfoForKey:@"UniqueDeviceID"];
            if (!udid) {
                printf("Failed to get UDID, required to fetch patches from the cloud\n");
                return 1;
            }
            
            NSString *sessionToken = flexPrefs[@"session"];
            if (!sessionToken) {
                printf("Failed to get Flex session token, please open the app and make sure you're signed in\n");
                return 1;
            }
            
            // Flex sends a few more things, but these are the only required three parameters
            NSDictionary *bodyDict = @{
                                       @"patchID":patchID,
                                       @"deviceID":udid,
                                       @"sessionID":sessionToken
                                       };
            
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api2.getflex.co/patch/download"]];
            req.HTTPMethod = @"POST";
            NSError *jsonError;
            req.HTTPBody = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
            if (jsonError) {
                printf("Error creating JSON\n");
                NSLog(@"%@", jsonError);
                return 1;
            }
            
            if (output) {
                printf("%sGetting patch %s from Flex servers%s\n", cyanColor, patchID.UTF8String, resetColor);
            }
            
            // due to the runloop and block, the best way to exit after errors is using exit(), although I prefer returning to main to exit
            CFRunLoopRef runLoop = CFRunLoopGetCurrent();
            __block NSDictionary *getPatch;
            [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (data == nil || error != nil) {
                    printf("Error getting patch\n");
                    if (error) {
                        NSLog(@"%@", error);
                    }
                    exit(1);
                }
                
                getPatch = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                if (!getPatch[@"units"]) {
                    printf("Error getting patch\n");
                    if (getPatch) {
                        NSLog(@"%@", getPatch);
                    } else {
                        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                    }
                    
                    exit(1);
                }
                
                CFRunLoopStop(runLoop);
            }] resume];
            
            CFRunLoopRun();
            patch = getPatch;
        } else if (remote) {
            patch = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:remote]];
            if (!patch) {
                printf("Bad remote patch\n");
                return 1;
            }
        }
        
        titleKey = @"title";
        appBundleKey = @"applicationIdentifier";
        descriptionKey = @"description";
    } else {
        NSDictionary *file;
        NSString *firstPath = @"/var/mobile/Library/Application Support/Flex3/patches.plist";
        NSString *secondPath = @"/var/mobile/Library/UserConfigurationProfiles/PublicInfo/Flex3Patches.plist";
        if (getPlist) {
            file = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:@"http://ipadkid.cf/ftt/patches.plist"]];
        } else if ([fileManager fileExistsAtPath:firstPath]) {
            file = [NSDictionary dictionaryWithContentsOfFile:firstPath];
        } else if ([fileManager fileExistsAtPath:secondPath]) {
            file = [NSDictionary dictionaryWithContentsOfFile:secondPath];
        } else {
            printf("File not found, please ensure Flex 3 is installed\n"
                   "If you're using an older version of Flex, please contact me at http://ipadkid.cf/contact\n");
            return 1;
        }
        
        NSArray *allPatches = file[@"patches"];
        unsigned long allPatchesCount = allPatches.count;
        if (choice < 0) {
            for (unsigned int choose = 0; choose < allPatchesCount; choose++) {
                printf("  %d: %s\n", choose, [allPatches[choose][@"name"] UTF8String]);
            }
            
            if (dump) {
                return 0;
            }
            
            printf("Enter corresponding number: ");
            scanf("%i", &choice);
        }
        
        if (allPatchesCount <= choice) {
            printf("Please input a valid number between 0 and %lu\n", allPatchesCount-1);
            return 1;
        }
        
        patch = allPatches[choice];
        titleKey = @"name";
        appBundleKey = @"appIdentifier";
        descriptionKey = @"cloudDescription";
    }
    
    BOOL uikit = NO;
    
    // Tweak.xm handling
    NSMutableString *xm = NSMutableString.new;
    NSMutableArray<NSString *> *usedSwiftClasses = NSMutableArray.new;
    for (NSDictionary *top in patch[@"units"]) {
        NSDictionary *units = top[@"methodObjc"];
        
        // Class name handling
        NSString *className = units[@"className"];
        if ([className containsString:@"."]) {
            if (![usedSwiftClasses containsObject:className]) {
                [usedSwiftClasses addObject:className];
            }
            
            className = [className stringByReplacingOccurrencesOfString:@"." withString:@""];
        }
        
        [xm appendFormat:@"%%hook %@\n", className];
        
        // Method name handling
        NSArray *displayName = [units[@"displayName"] componentsSeparatedByString:@")"];
        [xm appendFormat:@"%@)%@", [displayName[0] stringByReplacingOccurrencesOfString:@"(" withString:@" ("], [displayName[1] substringFromIndex:1]];
        NSUInteger methodArgCount = displayName.count;
        for (int methodBreak = 2; methodBreak < methodArgCount; methodBreak++) {
            [xm appendFormat:@")arg%d%@", methodBreak-1, displayName[methodBreak]];
        }
        
        [xm appendString:@" {\n"];
        
        if (smart) {
            NSString *smartComment = top[@"name"];
            NSString *defaultComment = [NSString stringWithFormat:@"Unit for %@", top[@"methodObjc"][@"displayName"]];
            if (smartComment.length > 0 && ![smartComment isEqualToString:defaultComment]) {
                [xm appendFormat:@"    // %@\n", smartComment];
            }
        }
        
        // Argument handling
        NSArray *allOverrides = top[@"overrides"];
        for (NSDictionary *override in allOverrides) {
            if (override.count == 0) {
                continue;
            }
            
            NSString *origValue = override[@"value"][@"value"];
            
            if ([origValue isKindOfClass:NSString.class]) {
                NSString *subToEight = origValue.length >= 8 ? [origValue substringToIndex:8] : @"";
                
                if ([subToEight isEqualToString:@"(FLNULL)"]) {
                    origValue = @"NULL";
                } else if ([subToEight isEqualToString:@"FLcolor:"]) {
                    NSArray *color = [[origValue substringFromIndex:8] componentsSeparatedByString:@","];
                    origValue = [NSString stringWithFormat:@"[UIColor colorWithRed:%@.0/255.0 green:%@.0/255.0 blue:%@.0/255.0 alpha:%@.0/255.0]", color[0], color[1], color[2], color[3]];
                    uikit = YES;
                } else {
                    origValue = [NSString stringWithFormat:@"@\"%@\"", origValue];
                }
            }
            
            int argument = [override[@"argument"] intValue];
            if (argument == 0) {
                [xm appendFormat:@"    return %@;\n", origValue];
                break;
            } else {
                [xm appendFormat:@"    arg%i = %@;\n", argument, origValue];
            }
        }
        
        // when processing the last argument, or there are no arguments, call orig
        NSUInteger overrideCount = allOverrides.count;
        if (overrideCount == 0 || [allOverrides[0][@"argument"] intValue] > 0) {
            if ([displayName[0] isEqualToString:@"-(void"]) {
                // I *think* if the return is void, and there are no arguments, Flex basically removes the function
                if (overrideCount > 0) {
                    [xm appendString:@"    %orig;\n"];
                }
            } else {
                [xm appendString:@"    return %orig;\n"];
            }
        }
        
        [xm appendFormat:@"} \n%%end\n\n"];
    }
    
    // swift class name handling
    if (usedSwiftClasses.count) {
        [xm appendString:@"%ctor {\n    %init("];
        for (NSString *swiftClassName in usedSwiftClasses) {
            NSString *comma = [swiftClassName isEqualToString:usedSwiftClasses.lastObject] ? @");\n" : @",\n        ";
            [xm appendFormat:@"%@ = objc_getClass(\"%@\")%@", [swiftClassName stringByReplacingOccurrencesOfString:@"." withString:@""], swiftClassName, comma];
        }
        [xm appendString:@"\n}\n\n"];
    }
    
    if (tweak) {
        NSCharacterSet *charsOnly = NSCharacterSet.alphanumericCharacterSet.invertedSet;
        // Creating sandbox
        if ([fileManager fileExistsAtPath:sandbox]) {
            printf("%s already exists\n", sandbox.UTF8String);
            return 1;
        }
        
        NSError *createSandboxError;
        [fileManager createDirectoryAtPath:sandbox withIntermediateDirectories:NO attributes:NULL error:&createSandboxError];
        if (createSandboxError) {
            NSLog(@"%@", createSandboxError);
            return 1;
        }
        
        // Makefile handling
        if (!name) {
            name = patch[titleKey];
        }
        
        NSString *title = [[name componentsSeparatedByCharactersInSet:charsOnly] componentsJoinedByString:@""];
        NSMutableString *makefile = [NSMutableString stringWithFormat:@""
                                     "include $(THEOS)/makefiles/common.mk\n\n"
                                     "TWEAK_NAME = %@\n"
                                     "%@_FILES = Tweak.xm\n", title, title];
        if (uikit) {
            [makefile appendFormat:@"%@_FRAMEWORKS = UIKit\n", title];
        }
        
        [makefile appendString:@"\ninclude $(THEOS_MAKE_PATH)/tweak.mk\n"];
        [makefile writeToFile:[sandbox stringByAppendingPathComponent:@"Makefile"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        // plist handling
        NSString *executable = patch[appBundleKey];
        if ([executable isEqualToString:@"com.flex.systemwide"]) {
            executable = @"com.apple.UIKit";
        }
        
        NSDictionary *plist = @{
                                @"Filter":@{
                                        @"Bundles":@[executable]
                                        }
                                };
        NSString *plistPath = [[sandbox stringByAppendingPathComponent:title] stringByAppendingPathExtension:@"plist"];
        [plist writeToFile:plistPath atomically:YES];
        
        // Control file handling
        NSString *author = patch[@"author"];
        NSString *authorChar = [[author componentsSeparatedByCharactersInSet:charsOnly] componentsJoinedByString:@""];
        NSString *description = [patch[descriptionKey] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n "];
        NSString *control = [NSString stringWithFormat:@""
                             "Package: com.%@.%@\n"
                             "Name: %@\nAuthor: %@\n"
                             "Description: %@\n"
                             "Depends: mobilesubstrate\n"
                             "Maintainer: ipad_kid <ipadkid358@gmail.com>\n"
                             "Architecture: iphoneos-arm\n"
                             "Section: Tweaks\n"
                             "Version: %@\n", authorChar, title, name, author, description, version];
        [control writeToFile:[sandbox stringByAppendingPathComponent:@"control"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        [xm writeToFile:[sandbox stringByAppendingPathComponent:@"Tweak.xm"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        if (output) {
            printf("%sProject %s created in %s%s\n", greenColor, title.UTF8String, sandbox.UTF8String, resetColor);
        }
    } else {
        printf("\n%s", xm.UTF8String);
        
        // UIPasteboard logs to console, freopen used to hide output
        FILE *hideLog = freopen("/dev/null", "w", stderr);
        UIPasteboard.generalPasteboard.string = xm;
        fclose(hideLog);
        
        if (output) {
            printf("%sOutput has successfully been copied to your clipboard. You can now easily paste this output in your .xm file\n", greenColor);
            
            if (uikit) {
                printf("\n%sPlease add UIKit to your project's FRAMEWORKS because this tweak includes color specifying\n", redColor);
            }
            
            printf("%s\n", resetColor);
        }
    }
    
    return 0;
}
