//
//  BWFileSystemResource+UrlFix.m
//  SymphonyMappingKit
//
//  Created by Mark Cafaro on 2/7/13.
//  Copyright (c) 2013 Rieke Lab. All rights reserved.
//

#import "BWFileSystemResource+UrlFix.h"

@implementation BWFileSystemResource (UrlFix)

// HACK: Overrides BWKit's method of the same name. BWKit's implementation
// pops an NSOpenPanel when it can't resolve a relative URL, which is wrong
// for CLI use. This replacement resolves the relative URL against the root
// using modern NSURL APIs and never shows UI.
+ (NSURL*)URLForFileSystemResource:(BWFileSystemResource*)resource
                 relativeToRootURL:(NSURL*)relativeRoot
                         openPanel:(NSOpenPanel*)op
{
    NSURL *relURL = [resource relativeURL];
    if (relURL == nil) {
        return nil;
    }

    // Resolve the relative path against the root URL, treating paths as
    // literal file system paths (no URL percent-encoding games).
    NSString *relPath = [relURL relativePath];
    if (relPath == nil || [relPath length] == 0) {
        return nil;
    }

    NSURL *result;
    if ([relPath isAbsolutePath]) {
        result = [NSURL fileURLWithPath:relPath];
    } else {
        NSString *rootPath = [relativeRoot path];
        NSString *fullPath = [rootPath stringByAppendingPathComponent:relPath];
        result = [NSURL fileURLWithPath:fullPath];
    }

    return result;
}

@end
