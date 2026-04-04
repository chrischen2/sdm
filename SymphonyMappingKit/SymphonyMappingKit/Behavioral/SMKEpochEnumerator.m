//
//  SMKEpochEnumerator.m
//  SymphonyMappingKit
//
//  Created by Mark Cafaro on 1/31/13.
//  Copyright (c) 2013 Rieke Lab. All rights reserved.
//

#import "SMKEpochEnumerator.h"
#import "SMKEpoch.h"
#import "SMKBackground.h"
#import "SMKBackgroundEnumerator.h"
#import "SMKStimulus.h"
#import "SMKStimulusEnumerator.h"
#import "SMKResponse.h"
#import "SMKResponseEnumerator.h"
#import "MACHdf5Reader.h"
#import "MACHdf5ObjectInformation.h"
#import "MACHdf5LinkInformation.h"

@implementation SMKEpochEnumerator

- (id)createNextEntity
{
    return [SMKEpoch new];
}

- (void)mapEntity:(SMKEntity *)entity withPath:(NSString *)path
{
    [super mapEntity:entity withPath:path];
    
    SMKEpoch *epoch = (SMKEpoch *)entity;
    
    NSString *parametersPath = [path stringByAppendingString:@"/protocolParameters"];
    epoch.protocolParameters = [_reader readAttributesOnPath:parametersPath];
    
    // Backgrounds
    NSArray *backgroundMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/backgrounds"]];
    NSMutableArray *backgroundPaths = [NSMutableArray arrayWithCapacity:[backgroundMembers count]];
    for (MACHdf5LinkInformation *backgroundMember in backgroundMembers) {
        [backgroundPaths addObject:backgroundMember.path];
    }
    SMKBackgroundEnumerator *backgroundEnumerator = [[SMKBackgroundEnumerator alloc] initWithReader:_reader entityPaths:backgroundPaths];
    NSMutableArray *backgrounds = [NSMutableArray arrayWithCapacity:[backgroundMembers count]];
    SMKBackground *background;
    while (background = [backgroundEnumerator nextObject]) {
        [backgrounds addObject:background];
    }
    epoch.backgrounds = backgrounds;
    
    // Stimuli
    NSArray *stimulusMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/stimuli"]];
    NSMutableArray *stimulusPaths = [NSMutableArray arrayWithCapacity:[stimulusMembers count]];
    for (MACHdf5LinkInformation *stimulusMember in stimulusMembers) {
        [stimulusPaths addObject:stimulusMember.path];
    }
    SMKStimulusEnumerator *stimulusEnumerator = [[SMKStimulusEnumerator alloc] initWithReader:_reader entityPaths:stimulusPaths];
    NSMutableArray *stimuli = [NSMutableArray arrayWithCapacity:[stimulusMembers count]];
    SMKStimulus *stimulus;
    while (stimulus = [stimulusEnumerator nextObject]) {
        [stimuli addObject:stimulus];
    }
    epoch.stimuli = stimuli;
    
    // Responses
    NSArray *responseMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/responses"]];
    NSMutableArray *responsePaths = [NSMutableArray arrayWithCapacity:[responseMembers count]];
    for (MACHdf5LinkInformation *responseMember in responseMembers) {
        [responsePaths addObject:responseMember.path];
    }
    SMKResponseEnumerator *responseEnumerator = [[SMKResponseEnumerator alloc] initWithReader:_reader entityPaths:responsePaths];
    NSMutableArray *responses = [NSMutableArray arrayWithCapacity:[responseMembers count]];
    SMKResponse *response;
    while (response = [responseEnumerator nextObject]) {
        [responses addObject:response];
    }
    epoch.responses = responses;
}

@end
