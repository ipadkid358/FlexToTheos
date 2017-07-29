@import Foundation;

int main (int argc, char **argv) {
    
    int choice = -1;
    NSString *version = @"0.0.1";
    NSString *sandbox = @"Sandbox";
    NSString *name = @"by ipad_kid and open source on GitHub (ipadkid358/FlexToTheos)";
    BOOL dump = NO;
    BOOL tweak = YES;
    BOOL smart = NO;
    BOOL getPlist = NO;
    int c;
    while ((c = getopt(argc, argv, ":f:n:v:p:dtsg")) != -1)
        switch(c) {
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
            case 'g':
                getPlist = YES;
                break;
            case '?':
                printf("\n  Usage: %s [OPTIONS]\n   Options:\n	-f	Set name of folder created for project (default is %s)\n	-n	Override the tweak name\n	-v	Set version (default is  %s)\n	-p	Directly plug in number (usually for consecutive dumps)\n	-d	Only print available patches, don't do anything (cannot be used with any other options)\n	-t	Only print Tweak.xm to console\n	-s	Enable smart comments (beta option)\n\n", argv[0], sandbox.UTF8String, version.UTF8String);
                exit(-1);
                break;
        }
    
    NSDictionary *file;
    if (getPlist) file = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:@"https://ipadkid358.github.io/ftt/patches.plist"]];
    else if ([NSFileManager.defaultManager fileExistsAtPath:@"/var/mobile/Library/Application Support/Flex3/patches.plist"]) file = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Application Support/Flex3/patches.plist"];
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
        } // Close choose for loop
        
        if (dump) exit(0);
        printf("Enter corresponding number: ");
        scanf("%i", &choice);
    } // Close choice if statement
    
    if (allPatchesCount <= choice) {
        printf("Please input a valid number between 0 and %lu\n", allPatchesCount);
        exit(-1);
    }
    NSDictionary *patch = allPatches[choice];
    
    BOOL uikit = NO;
    // Tweak.xm handling
    NSMutableString *xm = [NSMutableString new];
    for (NSDictionary *top in patch[@"units"]) {
        NSDictionary *units = top[@"methodObjc"];
        
        // Class name handling
        [xm appendFormat:@"%%hook %@\n", units[@"className"]];
        
        // Method name handling
        NSArray *displayName = [units[@"displayName"] componentsSeparatedByString:@")"];
        [xm appendFormat:@"%@)%@", displayName[0], displayName[1]];
        for (int methodBreak = 2; methodBreak < [displayName count]; methodBreak++) [xm appendFormat:@")arg%i%@", methodBreak-1, displayName[methodBreak]];
        [xm appendString:@" { \n"];
        
        // Argument handling
        NSArray *allOverrides = top[@"overrides"];
        for (NSDictionary *override in allOverrides) {
            NSString *origValue = override[@"value"][@"value"];
            if ([origValue isKindOfClass:NSString.class]) {
                if (origValue.length >= 8 && [[origValue substringToIndex:8] isEqual:@"(FLNULL)"]) origValue = @"nil";
                else if (origValue.length >= 8 && [[origValue substringToIndex:8] isEqual:@"FLcolor:"]) {
                    NSArray *color = [[origValue substringFromIndex:8] componentsSeparatedByString:@","];
                    origValue = [NSString stringWithFormat:@"[UIColor colorWithRed:%@.0/255.0 green:%@.0/255.0 blue:%@.0/255.0 alpha:%@.0/255.0]", color[0], color[1], color[2], color[3]];
                    uikit = YES;
                } else origValue = [NSString stringWithFormat:@"@\"%@\"", origValue];
            }
            int argument = [override[@"argument"] intValue];
            if (argument == 0) [xm appendFormat:@"	return %@; \n", origValue];
            else [xm appendFormat:@"	arg%i = %@;\n", argument, origValue];
        } // Closing arguments for loop
        
        if (allOverrides.count == 0 || [allOverrides[0][@"argument"] intValue] > 0) {
            if ([displayName[0] isEqual:@"-(void"]) [xm appendFormat:@"	%%orig;\n"];
            else [xm appendFormat:@"	return %%orig;\n"];
        } // Closing not zero if statement
        if (smart) {
            NSString *smartComment = top[@"name"];
            NSString *defaultComment = [NSString stringWithFormat:@"Unit for %@", top[@"methodObjc"][@"displayName"]];
            if (smartComment.length > 0 && !([smartComment isEqual:defaultComment])) [xm appendFormat:@"	// %@\n", smartComment];
        } // Close smart if statement
        [xm appendFormat:@"} \n%%end\n\n"];
    } // Closing top for loop
    
    if (tweak) {
        // Creating sandbox
        [NSFileManager.defaultManager createDirectoryAtPath:sandbox withIntermediateDirectories:NO attributes:NULL error:NULL];
        
        // Makefile handling
        if ([name isEqual:@"by ipad_kid and open source on GitHub (ipadkid358/FlexToTheos)"]) name = patch[@"name"];
        NSString *title = [[name componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet] componentsJoinedByString:@""];
        NSMutableString *makefile = NSMutableString.new;
        [makefile appendFormat:@"include $(THEOS)/makefiles/common.mk\n\nTWEAK_NAME = %@\n%@_FILES = Tweak.xm\n", title, title];
        if (uikit) [makefile appendFormat:@"%@_FRAMEWORKS = UIKit\n", title];
        [makefile appendString:@"\ninclude $(THEOS_MAKE_PATH)/tweak.mk"];
        [makefile writeToFile:[NSString stringWithFormat:@"%@/Makefile", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        
        // plist handling
        NSString *executable = patch[@"appIdentifier"];
        if ([executable isEqual: @"com.flex.systemwide"]) executable = @"com.apple.UIKit";
        NSDictionary *plist = @{@"Filter": @{@"Bundles": @[executable]}};
        NSString *plistPath = [NSString stringWithFormat:@"%@/%@.plist", sandbox, title];
        [plist writeToFile:plistPath atomically:YES];
        
        // Control file handling
        NSString *author = patch[@"author"];
        NSString *authorChar = [[author componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet] componentsJoinedByString:@""];
        NSString *description = [patch[@"cloudDescription"] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n "];
        NSString *control = [NSString stringWithFormat:@"Package: com.%@.%@\nName: %@\nAuthor: %@\nDescription: %@\nDepends: mobilesubstrate\nMaintainer: ipad_kid <ipadkid358@gmail.com>\nArchitecture: iphoneos-arm\nSection: Tweaks\nVersion: %@\n", authorChar, title, name, author, description, version];
        [control writeToFile:[NSString stringWithFormat:@"%@/control", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];

        [xm writeToFile:[NSString stringWithFormat:@"%@/Tweak.xm", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        printf("Project %s created in %s\n", title.UTF8String, sandbox.UTF8String);
    } else { // Close tweak if statement
        printf("\n\n%s", xm.UTF8String);
        freopen("/dev/null", "w", stderr);
#if TARGET_OS_IPHONE // UIKit apparently isn't a thing on MacOS, so this allows us to compile with Xcode
        [UIPasteboard.generalPasteboard setString:xm];
#endif
        fclose(stderr);
        printf("Output has been successfully copied to your clipboard. You can now easily paste this output in your .xm file\n");
        if (uikit) printf("\nPlease add UIKit to your project's FRAMEWORKS because this tweak includes color specifying\n");
        printf("\n");
    } // Close tweak else statement
    return 0;
} // Closing main
