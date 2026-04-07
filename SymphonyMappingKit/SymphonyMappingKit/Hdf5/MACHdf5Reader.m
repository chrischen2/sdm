//
//  MACHdf5Reader.m
//  SymphonyMappingKit
//
//  Created by Mark Cafaro on 1/29/13.
//  Copyright (c) 2013 Rieke Lab. All rights reserved.
//

#import "MACHdf5Reader.h"
#import "MACHdf5LinkInformation.h"
#import "MACHdf5ObjectInformation.h"

#define STRING_MAX 1024

#define stringToCString(s) [s cStringUsingEncoding:[NSString defaultCStringEncoding]]
#define cStringToString(c) [NSString stringWithCString:c encoding:[NSString defaultCStringEncoding]]

@implementation MACHdf5Reader

@synthesize fileId = _fileId;

+ (id)readerWithFilePath:(NSString *)filePath
{
    return [[self alloc] initWithFilePath:filePath];
}

- (id)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self) {       
        _fileId = H5Fopen([filePath cStringUsingEncoding:[NSString defaultCStringEncoding]], H5F_ACC_RDONLY, H5P_DEFAULT);
        if (_fileId < 0) {
            [NSException raise:@"H5Fopen error" format:@"H5Fopen failed to open file: %@", filePath];
        }
    }
    return self;
}

- (NSArray *)allGroupMembersInPath:(NSString *)groupPath
{
    hid_t groupId = H5Gopen(_fileId, stringToCString(groupPath), H5P_DEFAULT);
    
    H5G_info_t groupInfo;
    H5Gget_info(groupId, &groupInfo);
    
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:(uint)groupInfo.nlinks];
    
    char name[STRING_MAX];
    for (int i = 0; i < groupInfo.nlinks; i++) {
        // Get member name
        ssize_t length = H5Lget_name_by_idx(groupId, ".", NULL, H5_ITER_NATIVE, i, NULL, STRING_MAX, H5P_DEFAULT);
        H5Lget_name_by_idx(groupId, ".", NULL, H5_ITER_NATIVE, i, name, length + 1, H5P_DEFAULT);

        [names addObject:cStringToString(name)];
    }
    
    H5Gclose(groupId);
    
    return names;
}

- (NSArray *)groupMemberLinkInfoInPath:(NSString *)groupPath;
{
    hid_t groupId = H5Gopen(_fileId, stringToCString(groupPath), H5P_DEFAULT);
    
    H5G_info_t groupInfo;
    H5Gget_info(groupId, &groupInfo);
    
    NSString *superGroupName = [groupPath isEqualToString:@"/"] ? @"/" : [groupPath stringByAppendingString:@"/"];
    
    NSMutableArray *info = [NSMutableArray arrayWithCapacity:(uint)groupInfo.nlinks];
    
    char name[STRING_MAX];
    for (int i = 0; i < groupInfo.nlinks; i++) {
        // Get member name
        ssize_t length = H5Lget_name_by_idx(groupId, ".", NULL, H5_ITER_NATIVE, i, NULL, STRING_MAX, H5P_DEFAULT);
        H5Lget_name_by_idx(groupId, ".", NULL, H5_ITER_NATIVE, i, name, length + 1, H5P_DEFAULT);
        
        // Get member object info
        H5O_info_t objectInfo;
        H5Oget_info_by_name(groupId, name, &objectInfo, H5O_INFO_BASIC, H5P_DEFAULT);
        
        NSString *path = [superGroupName stringByAppendingString:cStringToString(name)];
        MACHdf5LinkInformation *linkInfo = [[MACHdf5LinkInformation alloc] initWithPath:path objectType:objectInfo.type];
        
        [info addObject:linkInfo];
    }
    
    H5Gclose(groupId);
    
    return info;
}

- (NSArray *)allAttributeNamesOnPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);

    H5O_info_t info;
    H5Oget_info(objectId, &info, H5O_INFO_ALL);
    
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:(uint)info.num_attrs];
    for (int i = 0; i < info.num_attrs; i++) {
        hid_t attributeId = H5Aopen_by_idx(objectId, ".", NULL, H5_ITER_NATIVE, i, H5P_DEFAULT, H5P_DEFAULT);
        
        ssize_t length = H5Aget_name(attributeId, 0, NULL);
        char name[length + 1];
        name[length] = NULL;
        H5Aget_name(attributeId, length + 1, name);
        
        [names addObject:cStringToString(name)];
        
        H5Aclose(attributeId);
    }
    
    H5Oclose(objectId);
    
    return names;
}

- (MACHdf5ObjectInformation *)objectInformationForPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    
    H5O_info_t info;
    H5Oget_info_by_name(objectId, stringToCString(objectPath), &info, H5O_INFO_BASIC, H5P_DEFAULT);
    
    MACHdf5ObjectInformation *objectInfo = [[MACHdf5ObjectInformation alloc] initWithPath:objectPath objectType:info.type];
    
    H5Oclose(objectId);
    
    return objectInfo;
}

- (BOOL)hasAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);

    htri_t exists = H5Aexists(objectId, stringToCString(attributeName));
    
    H5Oclose(objectId);
    
    return exists > 0;
}

- (NSString *)readStringAttribute:(NSString *)attributeName onPath:(NSString *)objectPath;
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    H5A_info_t attributeInfo;
    H5Aget_info(attributeId, &attributeInfo);
    
    hid_t attributeType = H5Aget_type(attributeId);
    
    size_t size = H5Tget_size(attributeType);   
    char value[size + 1];
    memset(value, 0, size + 1);
    H5Aread(attributeId, attributeType, value);
    
    H5Tclose(attributeType);
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    return cStringToString(value);
}

- (int64_t)readLongAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
        
    int64_t value;
    H5Aread(attributeId, H5T_NATIVE_INT64, &value);
    
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    return value;
}

- (NSArray *)readLongArrayAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    hid_t typeId = H5Aget_type(attributeId);
    H5T_class_t class = H5Tget_class(typeId);
    
    hid_t memTypeId;
    int length;
    if (class == H5T_ARRAY) {
        int rank = H5Tget_array_ndims(typeId);
        hsize_t dims[rank];
        H5Tget_array_dims(typeId, dims);
        
        if (rank != 1) {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        length = (int)dims[0];
        if (length != dims[0]) {
            [NSException raise:@"LengthTooLarge"
                        format:@"%@.%@ length is too large", objectPath, attributeName];
        }
        
        memTypeId = H5Tarray_create(H5T_NATIVE_INT64, 1, dims);
    } else {
        hid_t spaceId = H5Aget_space(attributeId);
        int rank = H5Sget_simple_extent_ndims(spaceId);
        hsize_t dims[rank];
        H5Sget_simple_extent_dims(spaceId, dims, NULL);
        
        if (rank == 0) {
            length = 1;
        } else if (rank == 1) {
            length = (int)dims[0];
            if (length != dims[0]) {
                [NSException raise:@"LengthTooLarge"
                            format:@"%@.%@ length is too large", objectPath, attributeName];
            }
        } else {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        memTypeId = H5T_NATIVE_INT64;
        
        H5Sclose(spaceId);
    }
    
    int32_t buffer[length];
    H5Aread(attributeId, memTypeId, buffer);
    
    H5Tclose(typeId);
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    NSMutableArray *data = [NSMutableArray arrayWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [data addObject:[NSNumber numberWithLongLong:buffer[i]]];
    }
    
    return data;
}

- (int32_t)readIntAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    int32_t value;
    H5Aread(attributeId, H5T_NATIVE_INT32, &value);
    
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    return value;
}

- (NSArray *)readIntArrayAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    hid_t typeId = H5Aget_type(attributeId);
    H5T_class_t class = H5Tget_class(typeId);
    
    hid_t memTypeId;
    int length;
    if (class == H5T_ARRAY) {
        int rank = H5Tget_array_ndims(typeId);
        hsize_t dims[rank];
        H5Tget_array_dims(typeId, dims);
        
        if (rank != 1) {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        length = (int)dims[0];
        if (length != dims[0]) {
            [NSException raise:@"LengthTooLarge"
                        format:@"%@.%@ length is too large", objectPath, attributeName];
        }
        
        memTypeId = H5Tarray_create(H5T_NATIVE_INT32, 1, dims);
    } else {
        hid_t spaceId = H5Aget_space(attributeId);
        int rank = H5Sget_simple_extent_ndims(spaceId);
        hsize_t dims[rank];
        H5Sget_simple_extent_dims(spaceId, dims, NULL);
        
        if (rank == 0) {
            length = 1;
        } else if (rank == 1) {
            length = (int)dims[0];
            if (length != dims[0]) {
                [NSException raise:@"LengthTooLarge"
                            format:@"%@.%@ length is too large", objectPath, attributeName];
            }
        } else {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        memTypeId = H5T_NATIVE_INT32;
        
        H5Sclose(spaceId);
    }
    
    int32_t buffer[length];
    H5Aread(attributeId, memTypeId, buffer);
    
    H5Tclose(typeId);
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    NSMutableArray *data = [NSMutableArray arrayWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [data addObject:[NSNumber numberWithInt:buffer[i]]];
    }
    
    return data;
}

- (int16_t)readShortAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    int16_t value;
    H5Aread(attributeId, H5T_NATIVE_INT16, &value);
    
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    return value;
}

- (NSArray *)readShortArrayAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    hid_t typeId = H5Aget_type(attributeId);
    H5T_class_t class = H5Tget_class(typeId);
    
    hid_t memTypeId;
    int length;
    if (class == H5T_ARRAY) {
        int rank = H5Tget_array_ndims(typeId);
        hsize_t dims[rank];
        H5Tget_array_dims(typeId, dims);
        
        if (rank != 1) {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        length = (int)dims[0];
        if (length != dims[0]) {
            [NSException raise:@"LengthTooLarge"
                        format:@"%@.%@ length is too large", objectPath, attributeName];
        }
        
        memTypeId = H5Tarray_create(H5T_NATIVE_INT16, 1, dims);
    } else {
        hid_t spaceId = H5Aget_space(attributeId);
        int rank = H5Sget_simple_extent_ndims(spaceId);
        hsize_t dims[rank];
        H5Sget_simple_extent_dims(spaceId, dims, NULL);
        
        if (rank == 0) {
            length = 1;
        } else if (rank == 1) {
            length = (int)dims[0];
            if (length != dims[0]) {
                [NSException raise:@"LengthTooLarge"
                            format:@"%@.%@ length is too large", objectPath, attributeName];
            }
        } else {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        memTypeId = H5T_NATIVE_INT16;
        
        H5Sclose(spaceId);
    }
    
    int32_t buffer[length];
    H5Aread(attributeId, memTypeId, buffer);
    
    H5Tclose(typeId);
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    NSMutableArray *data = [NSMutableArray arrayWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [data addObject:[NSNumber numberWithShort:buffer[i]]];
    }
    
    return data;
}

- (float)readFloatAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    float value;
    H5Aread(attributeId, H5T_NATIVE_FLOAT, &value);
    
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    return value;
}

- (NSArray *)readFloatArrayAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    hid_t typeId = H5Aget_type(attributeId);
    H5T_class_t class = H5Tget_class(typeId);
    
    hid_t memTypeId;
    int length;
    if (class == H5T_ARRAY) {
        int rank = H5Tget_array_ndims(typeId);
        hsize_t dims[rank];
        H5Tget_array_dims(typeId, dims);
        
        if (rank != 1) {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        length = (int)dims[0];
        if (length != dims[0]) {
            [NSException raise:@"LengthTooLarge"
                        format:@"%@.%@ length is too large", objectPath, attributeName];
        }
        
        memTypeId = H5Tarray_create(H5T_NATIVE_FLOAT, 1, dims);
    } else {
        hid_t spaceId = H5Aget_space(attributeId);
        int rank = H5Sget_simple_extent_ndims(spaceId);
        hsize_t dims[rank];
        H5Sget_simple_extent_dims(spaceId, dims, NULL);
        
        if (rank == 0) {
            length = 1;
        } else if (rank == 1) {
            length = (int)dims[0];
            if (length != dims[0]) {
                [NSException raise:@"LengthTooLarge"
                            format:@"%@.%@ length is too large", objectPath, attributeName];
            }
        } else {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        memTypeId = H5T_NATIVE_FLOAT;
        
        H5Sclose(spaceId);
    }
    
    float buffer[length];
    H5Aread(attributeId, memTypeId, buffer);
    
    H5Tclose(typeId);
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    NSMutableArray *data = [NSMutableArray arrayWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [data addObject:[NSNumber numberWithFloat:buffer[i]]];
    }
    
    return data;
}

- (double)readDoubleAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    double value;
    H5Aread(attributeId, H5T_NATIVE_DOUBLE, &value);
    
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    return value;
}

- (NSArray *)readDoubleArrayAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    hid_t typeId = H5Aget_type(attributeId);
    H5T_class_t class = H5Tget_class(typeId);
    
    hid_t memTypeId;
    int length;
    if (class == H5T_ARRAY) {
        int rank = H5Tget_array_ndims(typeId);
        hsize_t dims[rank];
        H5Tget_array_dims(typeId, dims);
        
        if (rank != 1) {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        length = (int)dims[0];
        if (length != dims[0]) {
            [NSException raise:@"LengthTooLarge"
                        format:@"%@.%@ length is too large", objectPath, attributeName];
        }
        
        memTypeId = H5Tarray_create(H5T_NATIVE_DOUBLE, 1, dims);
    } else {
        hid_t spaceId = H5Aget_space(attributeId);
        int rank = H5Sget_simple_extent_ndims(spaceId);
        hsize_t dims[rank];
        H5Sget_simple_extent_dims(spaceId, dims, NULL);
        
        if (rank == 0) {
            length = 1;
        } else if (rank == 1) {
            length = (int)dims[0];
            if (length != dims[0]) {
                [NSException raise:@"LengthTooLarge"
                            format:@"%@.%@ length is too large", objectPath, attributeName];
            }
        } else {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        memTypeId = H5T_NATIVE_DOUBLE;
        
        H5Sclose(spaceId);
    }
    
    double buffer[length];
    H5Aread(attributeId, memTypeId, buffer);
    
    H5Tclose(typeId);
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    NSMutableArray *data = [NSMutableArray arrayWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [data addObject:[NSNumber numberWithDouble:buffer[i]]];
    }
    
    return data;
}

- (BOOL)readBooleanAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    BOOL value;
    H5Aread(attributeId, H5T_NATIVE_INT8, &value);
    
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    return value;
}

- (NSArray *)readBooleanArrayAttribute:(NSString *)attributeName onPath:(NSString *)objectPath
{
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    hid_t attributeId = H5Aopen(objectId, stringToCString(attributeName), H5P_DEFAULT);
    
    hid_t typeId = H5Aget_type(attributeId);
    H5T_class_t class = H5Tget_class(typeId);
    
    hid_t memTypeId;
    int length;
    if (class == H5T_ARRAY) {
        int rank = H5Tget_array_ndims(typeId);
        hsize_t dims[rank];
        H5Tget_array_dims(typeId, dims);
        
        if (rank != 1) {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        length = (int)dims[0];
        if (length != dims[0]) {
            [NSException raise:@"LengthTooLarge"
                        format:@"%@.%@ length is too large", objectPath, attributeName];
        }
        
        memTypeId = H5Tarray_create(H5T_NATIVE_INT8, 1, dims);
    } else {
        hid_t spaceId = H5Aget_space(attributeId);
        int rank = H5Sget_simple_extent_ndims(spaceId);
        hsize_t dims[rank];
        H5Sget_simple_extent_dims(spaceId, dims, NULL);
        
        if (rank == 0) {
            length = 1;
        } else if (rank == 1) {
            length = (int)dims[0];
            if (length != dims[0]) {
                [NSException raise:@"LengthTooLarge"
                            format:@"%@.%@ length is too large", objectPath, attributeName];
            }
        } else {
            [NSException raise:@"UnexpectedRank"
                        format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, attributeName, rank];
        }
        
        memTypeId = H5T_NATIVE_INT8;
        
        H5Sclose(spaceId);
    }
    
    BOOL buffer[length];
    H5Aread(attributeId, memTypeId, buffer);
    
    H5Tclose(typeId);
    H5Aclose(attributeId);
    H5Oclose(objectId);
    
    NSMutableArray *data = [NSMutableArray arrayWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [data addObject:[NSNumber numberWithBool:buffer[i]]];
    }
    
    return data;
}

- (NSDictionary *)readAttributesOnPath:(NSString *)objectPath
{    
    hid_t objectId = H5Oopen(_fileId, stringToCString(objectPath), H5P_DEFAULT);
    
    NSArray *attributeNames = [self allAttributeNamesOnPath:objectPath];
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:[attributeNames count]];
    for (NSString *name in attributeNames) {
        hid_t attributeId = H5Aopen(objectId, stringToCString(name), H5P_DEFAULT);
        hid_t typeId = H5Aget_type(attributeId);
        H5T_class_t class = H5Tget_class(typeId);
        
        int nElements;
        H5T_class_t dataClass;
        if (class == H5T_ARRAY) {
            for (H5T_class_t c = H5T_INTEGER; c <= H5T_BITFIELD; c++) {
                BOOL detected = H5Tdetect_class(typeId, c);
                if (detected) {
                    dataClass = c;
                    break;
                }
            }
            int rank = H5Tget_array_ndims(typeId);
            hsize_t dims[rank];
            H5Tget_array_dims(typeId, dims);
            nElements = (int)dims[0];
            if (nElements != dims[0]) {
                [NSException raise:@"LengthTooLarge"
                            format:@"%@.%@ length is too large", objectPath, name];
            }
            for (int i = 1; i < rank; i++) {
                nElements *= dims[i];
            }
        } else {
            dataClass = class;
            hid_t spaceId = H5Aget_space(attributeId);
            int rank = H5Sget_simple_extent_ndims(spaceId);
            hsize_t dims[rank];
            H5Sget_simple_extent_dims(spaceId, dims, NULL);
            
            if (rank == 0) {
                nElements = 1;
            } else if (rank == 1) {
                nElements = (int)dims[0];
                if (nElements != dims[0]) {
                    [NSException raise:@"LengthTooLarge"
                                format:@"%@.%@ length is too large", objectPath, name];
                }
            } else {
                [NSException raise:@"UnexpectedRank"
                            format:@"%@.%@ needs to be of rank 1, but is of rank %i", objectPath, name, rank];
            }
            
            H5Sclose(spaceId);
        }
        
        switch (dataClass) {
            case H5T_STRING: {
                NSString *value = [self readStringAttribute:name onPath:objectPath];
                [attributes setValue:value forKey:name];
                break;
            }
            case H5T_INTEGER: {
                size_t size = H5Tget_size(typeId);
                if (size == 4) {
                    if (nElements > 1) {
                        NSArray *value = [self readIntArrayAttribute:name onPath:objectPath];
                        [attributes setValue:value forKey:name];
                    } else {
                        int32_t value = [self readIntAttribute:name onPath:objectPath];
                        [attributes setValue:[NSNumber numberWithInt:value] forKey:name];
                    }
                } else if (size == 8) {
                    if (nElements > 1) {
                        NSArray *value = [self readLongArrayAttribute:name onPath:objectPath];
                        [attributes setValue:value forKey:name];
                    } else {
                        int64_t value = [self readLongAttribute:name onPath:objectPath];
                        [attributes setValue:[NSNumber numberWithLongLong:value] forKey:name];
                    }
                } else if (size == 2) {
                    if (nElements > 1) {
                        NSArray *value = [self readShortArrayAttribute:name onPath:objectPath];
                        [attributes setValue:value forKey:name];
                    } else {
                        int16_t value = [self readShortAttribute:name onPath:objectPath];
                        [attributes setValue:[NSNumber numberWithShort:value] forKey:name];
                    }
                } else if (size == 1) {
                    if (nElements > 1) {
                        NSArray *value = [self readBooleanArrayAttribute:name onPath:objectPath];
                        [attributes setValue:value forKey:name];
                    } else {
                        int16_t value = [self readBooleanAttribute:name onPath:objectPath];
                        [attributes setValue:[NSNumber numberWithShort:value] forKey:name];
                    }
                } else {
                    [NSException raise:@"UnsupportedAttributeType"
                                format:@"%@.%@ is not a supported attribute type", objectPath, name];
                }
                break;
            }
            case H5T_FLOAT: {
                size_t size = H5Tget_size(typeId);
                if (size == 4) {
                    if (nElements > 1) {                       
                        NSArray *value = [self readFloatArrayAttribute:name onPath:objectPath];
                        [attributes setValue:value forKey:name];
                    } else {
                        float value = [self readFloatAttribute:name onPath:objectPath];
                        [attributes setValue:[NSNumber numberWithFloat:value] forKey:name];
                    }
                } else if (size == 8) {
                    if (nElements > 1) {                       
                        NSArray *value = [self readDoubleArrayAttribute:name onPath:objectPath];
                        [attributes setValue:value forKey:name];
                    } else {
                        double value = [self readDoubleAttribute:name onPath:objectPath];
                        [attributes setValue:[NSNumber numberWithDouble:value] forKey:name];
                    }
                } else {
                    [NSException raise:@"UnsupportedAttributeType"
                                format:@"%@.%@ is not a supported attribute type", objectPath, name];
                }
                break;
            }
            case H5T_BITFIELD: {
                BOOL value = [self readBooleanAttribute:name onPath:objectPath];
                [attributes setValue:[NSNumber numberWithBool:value] forKey:name];
                break;
            }
            default:
                [NSException raise:@"UnsupportedAttributeType"
                            format:@"%@.%@ is not a supported attribute type", objectPath, name];
                break;
        }
        
        H5Tclose(typeId);
        H5Aclose(attributeId);
    }
    
    H5Oclose(objectId);
    
    return attributes;
}

- (void)dealloc
{
    H5Fclose(_fileId);
}

@end
