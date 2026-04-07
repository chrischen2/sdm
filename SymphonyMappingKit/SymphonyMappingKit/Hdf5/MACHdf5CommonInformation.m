//
//  MACHdf5CommonInformation.m
//  SymphonyMappingKit
//
//  Created by Mark Cafaro on 1/31/13.
//  Copyright (c) 2013 Rieke Lab. All rights reserved.
//

#import "MACHdf5CommonInformation.h"

@implementation MACHdf5CommonInformation

@synthesize path = _path;
@synthesize type = _type;

- (id)initWithPath:(NSString *)path objectType:(H5O_type_t)type
{
    self = [super init];
    if (self) {
        _path = [path copy];
        _type = type;
    }
    return self;
}

- (BOOL)isGroup
{
    return _type == H5O_TYPE_GROUP;
}

- (BOOL)isDataset
{
    return _type == H5O_TYPE_DATASET;
}

- (BOOL)isEqual:(MACHdf5CommonInformation *)object
{
    return [_path isEqualToString:object.path] && _type == object.type;
}

@end
