//
//  SMKExperimentEnumerator.m
//  SymphonyMappingKit
//
//  Created by Mark Cafaro on 3/16/16.
//  Copyright © 2016 Rieke Lab. All rights reserved.
//

#import "SMKExperimentEnumerator.h"
#import "SMKExperiment.h"
#import "SMKDeviceEnumerator.h"
#import "SMKSourceEnumerator.h"
#import "SMKEpochGroupEnumerator.h"
#import "SMKNote.h"
#import "MACHdf5Reader.h"
#import "MACHdf5ObjectInformation.h"
#import "MACHdf5LinkInformation.h"

#include "hdf5.h"

@implementation SMKExperimentEnumerator

- (id)createNextEntity
{
    return [SMKExperiment new];
}

- (void)mapEntity:(SMKEntity *)entity withPath:(NSString *)path
{
    [super mapEntity:entity withPath:path];
    
    SMKExperiment *experiment = (SMKExperiment *)entity;
    
    experiment.purpose = [_reader readStringAttribute:@"purpose" onPath:path];
    
    // Devices
    NSArray *deviceMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/devices"]];
    NSMutableArray *devicePaths = [NSMutableArray arrayWithCapacity:[deviceMembers count]];
    for (MACHdf5LinkInformation *deviceMember in deviceMembers) {
        [devicePaths addObject:deviceMember.path];
    }
    experiment.deviceEnumerator = [[SMKDeviceEnumerator alloc] initWithReader:_reader entityPaths:devicePaths];
    
    // Sources
    NSArray *sourceMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/sources"]];
    NSMutableArray *sourcePaths = [NSMutableArray arrayWithCapacity:[sourceMembers count]];
    for (MACHdf5LinkInformation *sourceMember in sourceMembers) {
        [sourcePaths addObject:sourceMember.path];
    }
    experiment.sourceEnumerator = [[SMKSourceEnumerator alloc] initWithReader:_reader entityPaths:sourcePaths];
    
    // Epoch Groups
    NSArray *groupMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/epochGroups"]];
    NSMutableArray *groupPaths = [NSMutableArray arrayWithCapacity:[groupMembers count]];
    for (MACHdf5LinkInformation *groupMember in groupMembers) {
        [groupPaths addObject:groupMember.path];
    }
    experiment.epochGroupEnumerator = [[SMKEpochGroupEnumerator alloc] initWithReader:_reader entityPaths:groupPaths parent:nil];

    NSLog(@"Experiment at '%@': %lu device(s), %lu source(s), %lu epochGroup(s)",
          path, (unsigned long)[devicePaths count], (unsigned long)[sourcePaths count], (unsigned long)[groupPaths count]);
}

@end
