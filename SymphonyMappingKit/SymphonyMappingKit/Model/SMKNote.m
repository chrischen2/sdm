//
//  SMKNote.m
//  SymphonyMappingKit
//
//  Created by Mark Cafaro on 1/4/13.
//  Copyright (c) 2013 Rieke Lab. All rights reserved.
//

#import "SMKNote.h"

@implementation SMKNote

@synthesize comment = _comment;
@synthesize timestamp = _timestamp;

- (BOOL)isEqual:(SMKNote *)object
{
    return [_comment isEqual:object.comment] && [_timestamp isEqualToDate:object.timestamp];
}

- (NSString *)description
{
    return [[_timestamp description] stringByAppendingString:_comment];
}

@end
