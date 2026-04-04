//
//  SMKEntity.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKEntity.h"

@implementation SMKEntity

@synthesize uuid = _uuid;
@synthesize properties = _properties;
@synthesize keywords = _keywords;
@synthesize notes = _notes;

- (BOOL)isEqual:(SMKEntity *)object
{
    return [_uuid isEqual:object.uuid];
}

@end
