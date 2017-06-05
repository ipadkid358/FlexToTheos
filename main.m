#import <Foundation/Foundation.h>

int main (int argc, char **argv) {
    
    int choice = -1;
    NSString *version = @"0.0.1";
    NSString *sandbox = @"Sandbox";
    NSString *name = @"by ipad_kid and open source on GitHub (ipadkid358/FlexToTheos)";
    BOOL dump = NO;
    BOOL tweak = YES;
    int c;
    while ((c = getopt (argc, argv, "f:n:v:p:dt")) != -1)
        switch(c) {
            case 'f':
                sandbox = [NSString stringWithFormat:@"%s", optarg];
                if ([sandbox componentsSeparatedByString:@" "].count > 0) {
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
            case '?':
                printf("\n  Usage: %s [OPTIONS]\n   Options:\n	-f	Set name of folder created for project (default is %s)\n	-n	Override the tweak name\n	-v	Set version (default is  %s)\n	-p	Directly plug in number (usually for consecutive dumps)\n	-d	Only print available patches, don't do anything (cannot be used with any other options)\n	-t	Only print Tweak.xm to console (beta option)\n\n", argv[0], sandbox.UTF8String, version.UTF8String);
                exit(-1);
                break;
        }
    
    // Handles the annoying issue of switching plists when testing on iOS vs developing with Xcode
    NSDictionary *file;
    if ([NSFileManager.defaultManager fileExistsAtPath:@"/var/mobile/Library/Application Support/Flex3/patches.plist"]) file = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Application Support/Flex3/patches.plist"];
    else if ([NSFileManager.defaultManager fileExistsAtPath:@"/Users/ipad_kid/Downloads/patches.plist"]) file = [[NSDictionary alloc] initWithContentsOfFile:@"/Users/ipad_kid/Downloads/patches.plist"];
    else {
    	printf("File not found, please ensure Flex 3 is installed (if you're using an older version of Flex, please contact me at https://ipadkid358.github.io/contact.html)");
    	exit(-1);
    }
    
    if (choice == -1) {
        for (int choose = 0; choose < [file[@"patches"] count]; choose++) {
            printf("  %i: ", choose);
            printf("%s\n", [file[@"patches"][choose][@"name"] UTF8String]);
        } // Close choose for loop
        
        if (dump) exit(0);
        printf("Enter corresponding number: ");
        scanf("%i", &choice);
    } // Close choice if statement
    
    NSDictionary *patch = file[@"patches"][choice];
    
    BOOL uikit = NO;
    // Tweak.xm handling
    NSMutableString *xm = [NSMutableString new];
    for (NSDictionary *top in patch[@"units"]) {
        NSDictionary *units = top[@"methodObjc"];
        
        // Class name handling
        [xm appendString:[NSString stringWithFormat:@"%%hook %@\n", units[@"className"]]];
        
        // Method name handling
        NSArray *displayName = [units[@"displayName"] componentsSeparatedByString:@")"];
        [xm appendString:[NSString stringWithFormat:@"%@)%@", displayName[0], displayName[1]]];
        for (int methodBreak = 2; methodBreak < [displayName count]; methodBreak++) [xm appendString:[NSString stringWithFormat:@")arg%i%@", methodBreak-1, displayName[methodBreak]]];
        [xm appendString:@" { \n"];
        
        // Argument handling
        NSArray *allOverrides = top[@"overrides"];
        for (NSDictionary *override in allOverrides) {
            NSString *origValue = override[@"value"][@"value"];
            NSString *objValue;
            if ([origValue isKindOfClass:[NSString class]] && [[origValue substringToIndex:8] isEqual:@"(FLNULL)"]) objValue = @"nil";
            else if ([origValue isKindOfClass:[NSString class]] && [[origValue substringToIndex:8] isEqual:@"FLcolor:"]) {
                NSArray *color = [[origValue substringFromIndex:8] componentsSeparatedByString:@","];
                objValue = [NSString stringWithFormat:@"[UIColor colorWithRed:%@.0/255.0 green:%@.0/255.0 blue:%@.0/255.0 alpha:%@.0/255.0]", color[0], color[1], color[2], color[3]];
                uikit = YES;
            } else objValue = origValue;
            
            int argument = [override[@"argument"] intValue];
            if (argument == 0) [xm appendString:[NSString stringWithFormat:@"	return %@; \n", objValue]];
            else [xm appendString:[NSString stringWithFormat:@"	arg%i = %@;\n", argument, objValue]];
        } // Closing arguments for loop
        
        if ([allOverrides count] == 0 || [allOverrides[0][@"argument"] intValue] > 0) {
            if ([displayName[0] isEqual:@"-(void"]) [xm appendString:[NSString stringWithFormat:@"	%%orig;\n"]];
            else [xm appendString:[NSString stringWithFormat:@"	return %%orig;\n"]];
        } // Closing not zero if statement
        [xm appendString:[NSString stringWithFormat:@"} \n%%end\n\n"]];
    } // Closing top for loop
	
    if (tweak) {
    // Creating sandbox
    [NSFileManager.defaultManager createDirectoryAtPath:sandbox withIntermediateDirectories:NO attributes:NULL error:NULL];
    
    // Makefile handling
    if ([name isEqual:@"by ipad_kid and open source on GitHub (ipadkid358/FlexToTheos)"]) name = patch[@"name"];
    NSString *title = [[name componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    NSMutableString *makefile = [NSMutableString new];
    [makefile appendString:[NSString stringWithFormat:@"include $(THEOS)/makefiles/common.mk\nTWEAK_NAME = %@\n%@_FILES = Tweak.xm\n", title, title]];
    if (uikit) [makefile appendString:[NSString stringWithFormat:@"%@_FRAMEWORKS = UIKit\n", title]];
    [makefile appendString:@"include $(THEOS_MAKE_PATH)/tweak.mk"];
    [makefile writeToFile:[NSString stringWithFormat:@"%@/Makefile", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    
    // plist handling
    NSString *executable;
    if ([patch[@"applicationIdentifier"] isEqual: @"com.flex.systemwide"]) executable = @"com.apple.UIKit";
    else executable = patch[@"appIdentifier"];
    NSDictionary *plist = @{@"Filter": @{@"Bundles": executable}};
    NSString *plistPath = [NSString stringWithFormat:@"%@/%@.plist", sandbox, title];
    [plist writeToFile:plistPath atomically:YES];
    
    // Control file handling
    NSString *author = [[patch[@"author"] componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    NSString *description = [patch[@"cloudDescription"] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n "];
    NSString *control = [NSString stringWithFormat:@"Package: com.%@.%@\nName: %@\nAuthor: %@\nDescription: %@\nDepends: mobilesubstrate\nMaintainer: ipad_kid <ipadkid358@gmail.com>\nArchitecture: iphoneos-arm\nSection: Tweaks\nVersion: %@\n", author, title, name, author, description, version];
    [control writeToFile:[NSString stringWithFormat:@"%@/control", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [xm writeToFile:[NSString stringWithFormat:@"%@/Tweak.xm", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    printf("Project %s created in %s\n", title.UTF8String, sandbox.UTF8String);
    } else { // Close tweak if statement 
    printf("\n\n%s", xm.UTF8String); 
    [UIPasteboard.generalPasteboard setString:xm];
    printf(" ^^ that means the output was successfully copied to clipboard. You can now easily paste this output in your .xm file\n\n");
    if (uikit) printf("\nPlease add UIKit to your project's FRAMEWORKS because this tweak includes colors\n\n");
} // Close tweak else statement 
    return 0;
} // Closing main
