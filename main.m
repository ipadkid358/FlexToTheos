#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <MobileCoreServices/UTCoreTypes.h>

@interface UIDevice (PrivateBlackJacket)
/**
 @brief Get specific device information from MobileGestalt
 
 @param key The key to lookup
 
 @return The value returned by MGCopyAnswer
 */
- (NSString *)_deviceInfoForKey:(NSString *)key;
@end

#elif TARGET_OS_MAC
#import <Foundation/Foundation.h>
#else
#error Unknown target, please make sure you're compiling for iOS or macOS
#endif

/**
 @brief Convert a Flex patch to code
 
 @param patch The Flex patch
 @param comments Add comments
 @param uikit Pointer to a BOOL which will indicate if UIKit needs to be linked against
 @param logos If the output should be logos (otherwise plain Obj-C)
 
 @return a UTF8 encoded string of the code
 */
NSString *codeFromFlexPatch(NSDictionary *patch, BOOL comments, BOOL *uikit, BOOL logos) {
    NSString *ret;
    @autoreleasepool {
        NSMutableString *xm = [NSMutableString string];
        
        if (!logos) {
            [xm appendString:@"#include <substrate.h>\n\n"];
        }
        
        NSString *swiftPatchStr = @"PatchedSwiftClassName";
        
        NSMutableString *constructor = [NSMutableString stringWithString:@"static __attribute__((constructor)) void _logosLocalInit() {\n"];
        NSMutableArray<NSString *> *usedClasses = [NSMutableArray array];
        NSMutableArray<NSString *> *usedSwiftClasses = [NSMutableArray array];
        
        for (NSDictionary *unit in patch[@"units"]) {
            NSDictionary *objcInfo = unit[@"methodObjc"];
            NSString *className = objcInfo[@"className"];
            NSString *selectorName = objcInfo[@"selector"];
            
            NSString *logosConvention = [selectorName stringByReplacingOccurrencesOfString:@":" withString:@"$"];
            NSString *cleanClassName = [className stringByReplacingOccurrencesOfString:@"." withString:swiftPatchStr];
            
            NSString *implMainName = [NSString stringWithFormat:@"_ftt_meth_$%@$%@", cleanClassName, logosConvention];
            NSString *origImplName = [NSString stringWithFormat:@"_orig%@", implMainName];
            NSString *patchImplName = [NSString stringWithFormat:@"_patched%@", implMainName];
            
            NSString *flexDisplayName = objcInfo[@"displayName"];
            NSArray<NSString *> *displayName = [flexDisplayName componentsSeparatedByString:@")"];
            NSString *bashedMethodTypeValue = displayName.firstObject;
            NSString *returnType = [bashedMethodTypeValue substringFromIndex:2];
            
            NSMutableString *implArgList = [NSMutableString stringWithString:@"(id self, SEL _cmd"];
            NSMutableString *justArgCall = [NSMutableString stringWithString:@"(self, _cmd"];
            NSMutableString *justArgType = [NSMutableString stringWithString:@"(id, SEL"];
            
            NSMutableString *realMethodName = [NSMutableString string];
            [realMethodName appendString:[bashedMethodTypeValue stringByReplacingOccurrencesOfString:@"(" withString:@" ("]];
            [realMethodName appendFormat:@")%@", [displayName[1] substringFromIndex:1]];
            
            for (int displayId = 1; displayId < displayName.count-1; displayId++) {
                NSArray<NSString *> *typeBreakup = [displayName[displayId] componentsSeparatedByString:@"("];
                NSString *argType = typeBreakup.lastObject;
                [implArgList appendFormat:@", %@ arg%d", argType, displayId];
                [justArgCall appendFormat:@", arg%d", displayId];
                [justArgType appendFormat:@", %@", argType];
                
                [realMethodName appendFormat:@")arg%d%@", displayId, displayName[displayId+1]];
            }
            
            [implArgList appendString:@")"];
            [justArgCall appendString:@")"];
            [justArgType appendString:@")"];
            
            BOOL callsOrig = NO;
            
            NSMutableString *implBody = [NSMutableString string];
            if (comments) {
                NSString *smartComment = unit[@"name"];
                NSString *defaultComment = [NSString stringWithFormat:@"Unit for %@", flexDisplayName];
                if (smartComment.length > 0 && ![smartComment isEqualToString:defaultComment]) {
                    [implBody appendFormat:@"    // %@\n", smartComment];
                }
            }
            
            NSArray *allOverrides = unit[@"overrides"];
            for (NSDictionary *override in allOverrides) {
                if (override.count == 0) {
                    continue;
                }
                
                NSString *origValue = override[@"value"][@"value"];
                
                if ([origValue isKindOfClass:NSString.class]) {
                    NSString *subToEight = origValue.length >= 8 ? [origValue substringToIndex:8] : NULL;
                    
                    if ([subToEight isEqualToString:@"(FLNULL)"]) {
                        origValue = @"NULL";
                    } else if ([subToEight isEqualToString:@"FLcolor:"]) {
                        NSArray *color = [[origValue substringFromIndex:8] componentsSeparatedByString:@","];
                        NSString *restrict colorBase = @"[UIColor colorWithRed:%@.0/255.0 green:%@.0/255.0 blue:%@.0/255.0 alpha:%@.0/255.0]";
                        origValue = [NSString stringWithFormat:colorBase, color[0], color[1], color[2], color[3]];
                        *uikit = YES;
                    } else {
                        origValue = [NSString stringWithFormat:@"@\"%@\"", origValue];
                    }
                }
                
                int argument = [override[@"argument"] intValue];
                if (argument == 0) {
                    [implBody appendFormat:@"    return %@;\n", origValue];
                    break;
                } else {
                    [implBody appendFormat:@"    arg%i = %@;\n", argument, origValue];
                }
            }
            
            NSUInteger overrideCount = allOverrides.count;
            if (overrideCount == 0 || [allOverrides.firstObject[@"argument"] intValue] > 0) {
                if ([bashedMethodTypeValue isEqualToString:@"-(void"]) {
                    if (overrideCount > 0) {
                        if (logos) {
                            [implBody appendString:@"    %orig;\n"];
                        } else {
                            callsOrig = YES;
                            [implBody appendFormat:@"    %@%@;\n", origImplName, justArgCall];
                        }
                    }
                } else {
                    if (logos) {
                        [implBody appendString:@"    return %orig;\n"];
                    } else {
                        callsOrig = YES;
                        [implBody appendFormat:@"    return %@%@;\n", origImplName, justArgCall];
                    }
                }
            }
            
            if (callsOrig) {
                [xm appendFormat:@"static %@ (*%@)%@;\n", returnType, origImplName, justArgType];
            }
            
            if (logos) {
                [xm appendFormat:@"%%hook %@\n%@ {\n%@}\n%%end\n\n", cleanClassName, realMethodName, implBody];
            } else {
                [xm appendFormat:@"static %@ %@%@ {\n%@}\n\n", returnType, patchImplName, implArgList, implBody];
            }
            
            NSString *internalClassName = [NSString stringWithFormat:@"_ftt_class_%@", cleanClassName];
            
            if (logos) {
                if ([className containsString:@"."]) {
                    if (![usedSwiftClasses containsObject:className]) {
                        [usedSwiftClasses addObject:className];
                    }
                }
            } else {
                if (![usedClasses containsObject:className]) {
                    [constructor appendFormat:@"    Class %@ = objc_getClass(\"%@\");\n", internalClassName, className];
                    [usedClasses addObject:className];
                }
                
                [constructor appendFormat:@"    MSHookMessageEx(%@, @selector(%@), (IMP)%@, ", internalClassName, selectorName, patchImplName];
                if (callsOrig) {
                    [constructor appendFormat:@"(IMP *)%@", origImplName];
                } else {
                    [constructor appendString:@"NULL"];
                }
                [constructor appendString:@");\n"];
            }
        }
        
        if (logos) {
            if (usedSwiftClasses.count) {
                [xm appendString:@"%ctor {\n    %init("];
                NSString *lastClass = usedSwiftClasses.lastObject;
                for (NSString *className in usedSwiftClasses) {
                    NSString *comma = [className isEqualToString:lastClass] ? @");\n" : @",\n        ";
                    NSString *patchedClassName = [className stringByReplacingOccurrencesOfString:@"." withString:swiftPatchStr];
                    [xm appendFormat:@"%@ = objc_getClass(\"%@\")%@", patchedClassName, className, comma];
                }
                [xm appendString:@"\n}\n"];
            }
        } else {
            [constructor appendString:@"}\n"];
            [xm appendString:constructor];
        }
        
        ret = [NSString stringWithString:xm];
    }
    
    return ret;
}

int main(int argc, char *argv[]) {
#if TARGET_OS_IPHONE
    int choice = -1;
    BOOL dump = NO;
    
    // should be used for testing only, not documented
    BOOL getPlist = NO;
#endif
    NSString *version = @"0.0.1";
    NSString *sandbox = @"Sandbox";
    NSString *name;
    NSString *patchID;
    NSString *remote;
    BOOL tweak = YES;
    BOOL logos = YES;
    BOOL smart = NO;
    BOOL output = YES;
    BOOL color = YES;
    
    const char *switchOpts;
#if TARGET_OS_IPHONE
    switchOpts = ":c:f:n:r:v:p:dtlsbog";
#else
    switchOpts = ":f:n:r:v:tlsbo";
#endif
    int c;
    while ((c = getopt(argc, argv, switchOpts)) != -1) {
        switch (c) {
                case 'f': {
                    sandbox = [NSString stringWithUTF8String:optarg];
                    if ([[sandbox componentsSeparatedByString:@" "] count] > 1) {
                        puts("Invalid folder name, spaces are not allowed, becuase they break make(1)");
                        return 1;
                    }
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
#if TARGET_OS_IPHONE
                case 'c': {
                    patchID = [NSString stringWithUTF8String:optarg];
                    unsigned int smallValidPatch = 6106;
                    if (patchID.intValue < smallValidPatch) {
                        printf("Sorry, this is an older patch, and not yet supported\n"
                               "Please use a patch number greater than %d\n"
                               "Patch numbers are the last digits in share links\n", smallValidPatch);
                        return 1;
                    }
                }
                break;
                case 'p':
                choice = [[NSString stringWithUTF8String:optarg] intValue];
                break;
                case 'd':
                dump = YES;
                break;
                case 'g':
                getPlist = YES;
                break;
#endif
                case 't':
                tweak = NO;
                break;
                case 'l':
                logos = NO;
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
                case '?': {
                    printf("Usage: %s [OPTIONS]\n"
                           " Naming:\n"
                           "   -f    Set name of folder created for project (default is %s)\n"
                           "   -n    Override the tweak name\n"
                           "   -v    Set version (default is  %s)\n"
                           " Output:\n"
#if TARGET_OS_IPHONE
                           "   -d    Only print available local patches, don't do anything (cannot be used with any other options)\n"
#endif
                           "   -t    Only print code to console\n"
                           "   -l    Generate plain Obj-C instead of logos\n"
                           "   -s    Enable smart comments\n"
                           "   -o    Disable output, except errors\n"
                           "   -b    Disable colors in output\n"
                           " Source:\n"
#if TARGET_OS_IPHONE
                           "   -p    Directly plug in number\n"
                           "   -c    Get patches directly from the cloud. Downloads use your Flex downloads.\n"
                           "           Free accounts still have limits. Patch IDs are the last digits in share links\n"
#endif
                           "   -r    Get remote patch from 3rd party (generally used to fetch from Sinfool repo)\n"
                           , argv[0], sandbox.UTF8String, version.UTF8String);
                    return 1;
                }
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
        if (patchID && remote) {
            puts("Cannot select multiple sources");
            return 1;
        }
        
#if TARGET_OS_IPHONE
        if (patchID) {
            NSDictionary *flexPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.johncoates.Flex.plist"];
            NSString *udid = [UIDevice.currentDevice _deviceInfoForKey:@"UniqueDeviceID"];
            if (!udid) {
                puts("Failed to get UDID, required to fetch patches from the cloud");
                return 1;
            }
            
            NSString *sessionToken = flexPrefs[@"session"];
            if (!sessionToken) {
                puts("Failed to get Flex session token, please open the app and make sure you're signed in");
                return 1;
            }
            
            // Flex sends a few more things, but these are the only required parameters
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
                NSLog(@"Error creating JSON: %@", jsonError);
                return 1;
            }
            
            if (output) {
                printf("%sGetting patch %s from Flex servers%s\n", cyanColor, patchID.UTF8String, resetColor);
            }
            
            CFRunLoopRef runLoop = CFRunLoopGetCurrent();
            __block NSDictionary *getPatch;
            __block BOOL blockError = NO;
            [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (data == nil || error != nil) {
                    printf("Error getting patch\n");
                    if (error) {
                        NSLog(@"%@", error);
                    }
                    blockError = YES;
                } else {
                    
                    getPatch = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                    if (!getPatch[@"units"]) {
                        printf("Error getting patch\n");
                        if (getPatch) {
                            NSLog(@"%@", getPatch);
                        } else {
                            NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                        }
                        blockError = YES;
                    }
                }
                CFRunLoopStop(runLoop);
            }] resume];
            
            CFRunLoopRun();
            if (blockError) {
                return 1;
            }
            
            patch = getPatch;
        }
#endif
        if (remote) {
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
#if TARGET_OS_IPHONE
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
            puts("File not found, please ensure Flex 3 is installed\n"
                 "If you're using an older version of Flex, please contact me at https://ipadkid.cf/contact");
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
            scanf("%d", &choice);
        }
        
        if (allPatchesCount <= choice) {
            printf("Please input a valid number between 0 and %lu\n", allPatchesCount-1);
            return 1;
        }
        
        patch = allPatches[choice];
        titleKey = @"name";
        appBundleKey = @"appIdentifier";
        descriptionKey = @"cloudDescription";
#else
        puts("An external source is required");
        return 1;
#endif
    }
    
    BOOL uikit = NO;
    
    NSString *genedCode = codeFromFlexPatch(patch, smart, &uikit, logos);
    NSString *tweakFileExt = logos ? @"xm" : @"mm";
    
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
                                     "%@_FILES = Tweak.%@\n", title, title, tweakFileExt];
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
                                        @"Bundles":@[
                                                executable
                                                ]
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
                             "Name: %@\n"
                             "Author: %@\n"
                             "Description: %@\n"
                             "Depends: mobilesubstrate\n"
                             "Maintainer: ipad_kid <ipadkid358@gmail.com>\n"
                             "Architecture: iphoneos-arm\n"
                             "Section: Tweaks\n"
                             "Version: %@\n", authorChar, title, name, author, description, version];
        [control writeToFile:[sandbox stringByAppendingPathComponent:@"control"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        NSString *tweakFileName = [@"Tweak" stringByAppendingPathExtension:tweakFileExt];
        [genedCode writeToFile:[sandbox stringByAppendingPathComponent:tweakFileName] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        if (output) {
            printf("%sProject %s created in %s%s\n", greenColor, title.UTF8String, sandbox.UTF8String, resetColor);
        }
    } else {
        puts(genedCode.UTF8String);
#if TARGET_OS_IPHONE
        [UIPasteboard.generalPasteboard setValue:genedCode forPasteboardType:(id)kUTTypeUTF8PlainText];
#endif
        if (output) {
#if TARGET_OS_IPHONE
            printf("%sOutput has successfully been copied to your clipboard. "
                   "You can now easily paste this output in your .%s file\n", greenColor, tweakFileExt.UTF8String);
#endif
            if (uikit) {
                printf("\n%sPlease add UIKit to your project's FRAMEWORKS because this tweak includes color specifying\n", redColor);
            }
            
            printf("%s", resetColor);
        }
    }
    
    return 0;
}
