//
//  SMKDataFileReader.m
//  SymphonyMappingKit
//
//  Created by Mark Cafaro on 1/25/13.
//  Copyright (c) 2013 Rieke Lab. All rights reserved.
//

#import "SMKDataFileReader.h"
#import "SMKExperimentEnumerator.h"
#import "MACHdf5Reader.h"
#import "MACHdf5LinkInformation.h"

#define STRING_MAX 1024

@implementation SMKDataFileReader

+ (id)readerForHdf5FilePath:(NSString *)hdf5FilePath
{
    return [[self alloc] initWithHdf5FilePath:hdf5FilePath];
}

- (id)initWithHdf5FilePath:(NSString *)hdf5FilePath
{
    self = [super init];
    if (self) {
        _reader = [MACHdf5Reader readerWithFilePath:hdf5FilePath];
        
        _experimentPaths = [NSMutableArray array];
        
        NSArray *rootMembers = [_reader groupMemberLinkInfoInPath:@"/"];
        
        for (MACHdf5LinkInformation *member in rootMembers) {
            if (member.isGroup) {
                [_experimentPaths addObject:member.path];
            }
        }
        NSLog(@"HDF5 root contains %lu top-level group(s) → %lu experiment path(s)",
              (unsigned long)[rootMembers count], (unsigned long)[_experimentPaths count]);
    }
    return self;
}

- (SMKExperimentEnumerator *)experimentEnumerator
{
    return [[SMKExperimentEnumerator alloc] initWithReader:_reader entityPaths: _experimentPaths];
}

@end
