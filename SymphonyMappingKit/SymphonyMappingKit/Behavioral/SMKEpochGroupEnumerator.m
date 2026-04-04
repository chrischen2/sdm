//
//  SMKEpochGroupEnumerator.m
//  SymphonyMappingKit
//
//  Created by Mark Cafaro on 1/25/13.
//  Copyright (c) 2013 Rieke Lab. All rights reserved.
//

#import "SMKEpochGroupEnumerator.h"
#import "SMKEpochGroup.h"
#import "SMKEpochBlockEnumerator.h"
#import "SMKEpoch.h"
#import "SMKEpochEnumerator.h"
#import "SMKSourceEnumerator.h"
#import "MACHdf5Reader.h"
#import "MACHdf5ObjectInformation.h"
#import "MACHdf5LinkInformation.h"

#include "hdf5.h"

@implementation SMKEpochGroupEnumerator

- (id)initWithReader:(MACHdf5Reader *)reader entityPaths:(NSArray *)paths parent:(SMKEpochGroup *)parent
{
    self = [super initWithReader:reader entityPaths:paths];
    if (self) {
        _parent = parent;
    }
    return self;
}

- (id)createNextEntity
{
    return [SMKEpochGroup new];
}

- (void)mapEntity:(SMKEntity *)entity withPath:(NSString *)path
{
    [super mapEntity:entity withPath:path];
    
    SMKEpochGroup *group = (SMKEpochGroup *)entity;
    
    group.parent = _parent;
    group.label = [_reader readStringAttribute:@"label" onPath:path];
    
    NSString *sourcePath = [path stringByAppendingString:@"/source"];
    SMKSourceEnumerator *sourceEnumerator = [[SMKSourceEnumerator alloc] initWithReader:_reader entityPaths:[NSArray arrayWithObjects:sourcePath, nil]];
    group.source = sourceEnumerator.nextObject;
    
    // Epoch Groups
    NSArray *groupMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/epochGroups"]];
    NSMutableArray *groupPaths = [NSMutableArray arrayWithCapacity:[groupMembers count]];
    for (MACHdf5LinkInformation *groupMember in groupMembers) {
        [groupPaths addObject:groupMember.path];
    }
    group.epochGroupEnumerator = [[SMKEpochGroupEnumerator alloc] initWithReader:_reader entityPaths:groupPaths parent:group];
    
    // Epoch Blocks
    NSArray *blockMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/epochBlocks"]];
    NSMutableArray *blockPaths = [NSMutableArray arrayWithCapacity:[blockMembers count]];
    for (MACHdf5LinkInformation *blockMember in blockMembers) {
        [blockPaths addObject:blockMember.path];
    }
    group.epochBlockEnumerator = [[SMKEpochBlockEnumerator alloc] initWithReader:_reader entityPaths:blockPaths epochGroup:group];
}

@end
