//
//  SMKEntityEnumerator.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKEntityEnumerator.h"
#import "SMKEntity.h"
#import "SMKNote.h"
#import "MACHdf5Reader.h"
#import "MACHdf5ObjectInformation.h"
#import "MACHdf5LinkInformation.h"

@implementation SMKEntityEnumerator

- (id)initWithReader:(MACHdf5Reader *)reader entityPaths:(NSArray *)paths
{
    self = [super init];
    if (self) {
        _reader = reader;
        _paths = paths;
        _index = 0;
    }
    return self;
}

- (id)nextObject
{
    if (_index >= [_paths count]) {
        return nil;
    }
    
    SMKEntity *entity = [self createNextEntity];
    
    [self mapEntity:entity withPath:[_paths objectAtIndex:_index]];
    
    _index++;
    _lastEntity = entity;
    return entity;
}

- (id)createNextEntity
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)mapEntity:(SMKEntity *)entity withPath:(NSString *)path
{
    entity.uuid = [_reader readStringAttribute:@"uuid" onPath:path];
    
    NSArray *members = [_reader allGroupMembersInPath:path];
    
    NSDate *dotNetRefDate = [NSDate dateWithString:@"0001-01-01 00:00:00 +0000"];
    
    // Properties
    if ([members containsObject:@"properties"]) {
        
        NSString *memberPath = [path stringByAppendingString:@"/properties"];
        MACHdf5ObjectInformation *memberInfo = [_reader objectInformationForPath:memberPath];
        if (!memberInfo.isGroup) {
            [NSException raise:@"UnexpectedFormat" format:@"%@ must be a group", memberPath];
        }
        
        entity.properties = [_reader readAttributesOnPath:memberPath];
    }
    
    // Keywords
    if ([_reader hasAttribute:@"keywords" onPath:path]) {
        NSString *keywordsStr = [_reader readStringAttribute:@"keywords" onPath:path];
        entity.keywords = [NSSet setWithArray:[keywordsStr componentsSeparatedByString:@","]];
    }
    
    // Notes
    if ([members containsObject:@"notes"]) {
        
        NSString *memberPath = [path stringByAppendingString:@"/notes"];
        MACHdf5ObjectInformation *memberInfo = [_reader objectInformationForPath:memberPath];
        if (!memberInfo.isDataset) {
            [NSException raise:@"UnexpectedFormat" format:@"%@ must be a dataset", memberPath];
        }
        
        hid_t notesId = H5Dopen(_reader.fileId, [memberPath cStringUsingEncoding:[NSString defaultCStringEncoding]], H5P_DEFAULT);
        
        hid_t spaceId = H5Dget_space(notesId);
        int rank = H5Sget_simple_extent_ndims(spaceId);
        hsize_t dims[rank];
        H5Sget_simple_extent_dims(spaceId, dims, NULL);
        
        int length = (int)dims[0];
        if (length != dims[0]) {
            [NSException raise:@"LengthTooLarge"
                        format:@"%@ length is too large", memberPath];
        }
        
        hid_t datatypeId = H5Topen(_reader.fileId, "NOTE", H5P_DEFAULT);
        
        noteData *data = malloc(length * sizeof(noteData));
        H5Dread(notesId, datatypeId, H5S_ALL, H5S_ALL, H5P_DEFAULT, data);
        
        NSMutableSet *notes = [NSMutableSet setWithCapacity:length];
        for (int i = 0; i < length; i++) {
            SMKNote *note = [SMKNote new];
            
            NSTimeInterval interval = data[i].time.ticks / 1e7 - (data[i].time.offset * 60 * 60);
            note.timestamp = [NSDate dateWithTimeInterval:interval sinceDate:dotNetRefDate];
            
            note.comment = [NSString stringWithUTF8String:data[i].text];
            
            [notes addObject:note];
        }
        entity.notes = notes;
        
        free(data);
        H5Tclose(datatypeId);
        H5Sclose(spaceId);
        H5Dclose(notesId);
    }
}

- (NSArray *)allObjects
{
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    SMKEntityEnumerator *another = [[SMKEntityEnumerator alloc] initWithReader:_reader entityPaths:_paths];
    return another;
}

@end
