//
//  SMKSourceEnumerator.m
//  
//
//  Created by Mark Cafaro on 3/17/16.
//
//

#import "SMKSourceEnumerator.h"
#import "SMKSource.h"
#import "MACHdf5Reader.h"
#import "MACHdf5ObjectInformation.h"
#import "MACHdf5LinkInformation.h"

@implementation SMKSourceEnumerator

- (id)createNextEntity
{
    return [SMKSource new];
}

- (void)mapEntity:(SMKEntity *)entity withPath:(NSString *)path
{
    [super mapEntity:entity withPath:path];
    
    SMKSource *source = (SMKSource *)entity;
    
    NSArray *members = [_reader allGroupMembersInPath:path];
    
    if ([members containsObject:@"parent"]) {
        NSString *sourcePath = [path stringByAppendingString:@"/parent"];
        SMKSourceEnumerator *sourceEnumerator = [[SMKSourceEnumerator alloc] initWithReader:_reader entityPaths:[NSArray arrayWithObjects:sourcePath, nil]];
        source.parent = sourceEnumerator.nextObject;
    } else {
        source.parent = nil;
    }
    
    source.label = [_reader readStringAttribute:@"label" onPath:path];
    
    // Sources
    NSArray *sourceMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/sources"]];
    NSMutableArray *sourcePaths = [NSMutableArray arrayWithCapacity:[sourceMembers count]];
    for (MACHdf5LinkInformation *sourceMember in sourceMembers) {
        [sourcePaths addObject:sourceMember.path];
    }
    source.sourceEnumerator = [[SMKSourceEnumerator alloc] initWithReader:_reader entityPaths:sourcePaths];
}

@end
