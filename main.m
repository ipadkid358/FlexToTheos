#import <Foundation/Foundation.h>

int main (int argc, char **argv) {
    int choice = -1;
    NSString *version = @"0.0.1";
    NSString *sandbox = @"Sandbox";
    NSString *name = @"by ipad_kid and open source on GitHub (ipadkid358/FlexToTheos)";
    int dump = 0;
    int c;
    
    while ((c = getopt (argc, argv, "f:n:v:p:d")) != -1)
        switch(c) {
            case 'f':
                sandbox = [[[NSString stringWithFormat:@"%s", optarg] componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
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
                dump = 1;
                break;
            case '?':
                printf("\n  Usage: %s [OPTIONS]\n	-f	Set name of folder created for project (default is \"%s\")\n	-n	Override the tweak name\n	-v  Set version (default is  %s)\n	-p	Directly plug in number (usually for consecutive dumps)\n	-d	Only print available patches, don't do anything (cannot be used with any other options)\n\n", argv[0], sandbox.UTF8String, version.UTF8String);
                exit(-1);
                break;
        }
    NSDictionary *file = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Application Support/Flex3/patches.plist"]; // /Users/ipad_kid/Downloads/patches.plist
    if (choice == -1) {
        for (int choose = 0; choose < [file[@"patches"] count]; choose++) {
            printf("  %i: ", choose);
            printf("%s\n", [file[@"patches"][choose][@"name"] UTF8String]);
        } // Close choose for loop
        if (dump) exit(0);
        printf("Enter corresponding number: ");
        scanf("%i", &choice);
    }
    NSDictionary *patch = file[@"patches"][choice];
    // Dictionary is called "patch"
    
    // Creating sandbox
    [NSFileManager.defaultManager createDirectoryAtPath:sandbox withIntermediateDirectories:NO attributes:NULL error:NULL];
    
    // Makefile handling
    if ([name isEqual:@"by ipad_kid and open source on GitHub (ipadkid358/FlexToTheos)"]) name = patch[@"name"];
    NSString *title = [[name componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    NSMutableString *makefile = [NSMutableString new];
    [makefile appendString:[NSString stringWithFormat:@"include $(THEOS)/makefiles/common.mk\nTWEAK_NAME = %@\n%@_FILES = Tweak.xm\n", title, title]];
    
    // plist handling
    NSString *executable;
    if ([patch[@"applicationIdentifier"] isEqual: @"com.flex.systemwide"]) {
        executable = @"com.apple.UIKit";
    } else {
        executable = patch[@"appIdentifier"];
    }
    NSDictionary *plist = @{@"Filter": @{@"Bundles": executable}};
    NSString *plistPath = [NSString stringWithFormat:@"%@/%@.plist", sandbox, title];
    [plist writeToFile:plistPath atomically:YES];
    
    // Control file handling
    NSString *author = [[patch[@"author"] componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    NSString *description = [patch[@"cloudDescription"] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n "];
    NSString *control = [NSString stringWithFormat:@"Package: com.%@.%@\nName: %@\nAuthor: %@\nDescription: %@\nDepends: mobilesubstrate\nMaintainer: ipad_kid <ipadkid358@gmail.com>\nArchitecture: iphoneos-arm\nSection: Tweaks\nVersion: %@\n", author, title, name, author, description, version];
    if ([version isEqual:@"0.0.1"]) printf("By default, the Debian Version field has been set to %s\n", version.UTF8String);
    [control writeToFile:[NSString stringWithFormat:@"%@/control", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    
    
    // Tweak.xm handling
    NSMutableString *xm = [NSMutableString new];
    for (NSDictionary *top in patch[@"units"]) {
        NSDictionary *units = top[@"methodObjc"];
        
        // Class name handling
        [xm appendString:[NSString stringWithFormat:@"%%hook %@\n", units[@"className"]]];
        
        // Method name handling
        NSArray *displayName = [units[@"displayName"] componentsSeparatedByString:@")"];
        [xm appendString:[NSString stringWithFormat:@"%@)%@", displayName[0], displayName[1]]];
        for (int methodBreak = 2; methodBreak < [displayName count]; methodBreak++) {
            [xm appendString:[NSString stringWithFormat:@")arg%i%@", methodBreak-1, displayName[methodBreak]]];
        } // Closing method name handling for loop
        
        [xm appendString:@" { \n"];
        
        // Argument handling
        NSArray *allOverrides = top[@"overrides"];
        for (NSDictionary *override in allOverrides) {
            NSString *origValue = override[@"value"][@"value"];
            NSString *objValue;
            if ([origValue isKindOfClass:[NSString class]] && [[origValue substringToIndex:8] isEqual:@"(FLNULL)"]) {
                objValue = @"nil";
            } else if ([origValue isKindOfClass:[NSString class]] && [[origValue substringToIndex:8] isEqual:@"FLcolor:"]) {
                NSArray *color = [[origValue substringFromIndex:8] componentsSeparatedByString:@","];
                objValue = [NSString stringWithFormat:@"[UIColor colorWithRed:%@.0/255.0 green:%@.0/255.0 blue:%@.0/255.0 alpha:%@.0/255.0]", color[0], color[1], color[2], color[3]];
                [makefile appendString:[NSString stringWithFormat:@"%@_FRAMEWORKS = UIKit\n", title]];
            } else {
                objValue = origValue;
            }
            int argument = [override[@"argument"] intValue];
            if (argument == 0) {
                [xm appendString:[NSString stringWithFormat:@"return %@; \n", objValue]];
            } else {
                [xm appendString:[NSString stringWithFormat:@"arg%i = %@;\n", argument, objValue]];
            }
        } // Closing arguments for loop
        if ([allOverrides count] == 0 || [allOverrides[0][@"argument"] intValue] > 0) {
            if ([displayName[0] isEqual:@"-(void"]) {
                [xm appendString:[NSString stringWithFormat:@"%%orig;\n"]];
            } else {
                [xm appendString:[NSString stringWithFormat:@"return %%orig;\n"]];
            } // Closing type check if statement
        } // Closing not zero if statement
        [xm appendString:[NSString stringWithFormat:@"} \n%%end\n"]];
        
    } // Closing top for loop
    [xm writeToFile:[NSString stringWithFormat:@"%@/Tweak.xm", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [makefile appendString:@"include $(THEOS_MAKE_PATH)/tweak.mk"];
    [makefile writeToFile:[NSString stringWithFormat:@"%@/Makefile", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    printf("Project %s created in %s\n", title.UTF8String, sandbox.UTF8String);
    return 0;
} // Closing main
