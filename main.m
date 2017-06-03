#import <Foundation/Foundation.h>

int main (int argc, const char * argv[]) {
    
    NSDictionary *file = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Application Support/Flex3/patches.plist"];
    for (int choose = 0; choose < [file[@"patches"] count]; choose++) {
    printf("  %i: ", choose);
    printf("%s\n", [file[@"patches"][choose][@"name"] UTF8String]);
}
	int choice;
    scanf("%i", &choice);
    
   NSDictionary *patch = file[@"patches"][choice];
    
    // Dictionary is called "patch"
    
    // Creating sandbox
    NSString *sandbox = @"Sandbox";
    [NSFileManager.defaultManager createDirectoryAtPath:sandbox withIntermediateDirectories:NO attributes:NULL error:NULL];

    // Makefile handling
    NSString *name = patch[@"name"];
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
    NSString *control = [NSString stringWithFormat:@"Package: com.%@.%@\nName: %@\nAuthor: %@\nDescription: %@\nDepends: mobilesubstrate\nMaintainer: ipad_kid <ipadkid358@gmail.com>\nArchitecture: iphoneos-arm\nSection: Tweaks\nVersion: 0.0.1\n", author, title, name, author, description];
    printf("By default, the Debian Version field has been set to 0.0.1\n");
    [control writeToFile:[NSString stringWithFormat:@"%@/control", sandbox] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    
    
    // Tweak.xm handling
    NSMutableString *xm = [NSMutableString new];
    for (int top = 0; top < [patch[@"units"] count]; top++) {
        NSDictionary *units = patch[@"units"][top][@"methodObjc"];
        
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
        NSArray *allOverrides = patch[@"units"][top][@"overrides"];
        for (int arg = 0; arg < [allOverrides count]; arg++) {
            NSDictionary *override = allOverrides[arg];
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
   
    return 0;
} // Closing main
