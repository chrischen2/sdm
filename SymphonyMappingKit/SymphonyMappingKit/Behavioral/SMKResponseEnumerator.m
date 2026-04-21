//
//  SMKResponseEnumerator.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKResponseEnumerator.h"
#import "SMKResponse.h"
#import "MACHdf5Reader.h"

@implementation SMKResponseEnumerator

- (id)createNextEntity
{
    return [SMKResponse new];
}

- (void)mapEntity:(SMKEntity *)entity withPath:(NSString *)path
{
    [super mapEntity:entity withPath:path];
    
    SMKResponse *response = (SMKResponse *)entity;
    
    response.sampleRate = [NSNumber numberWithDouble:[_reader readDoubleAttribute:@"sampleRate" onPath:path]];
    response.sampleRateUnits = [_reader readStringAttribute:@"sampleRateUnits" onPath:path];
    
    NSDate *dotNetRefDate = [NSDate dateWithString:@"0001-01-01 00:00:00 +0000"];
    
    // Input time
    double inputOffsetHours = [_reader readDoubleAttribute:@"inputTimeDotNetDateTimeOffsetOffsetHours" onPath:path];
    int64_t inputTicks = [_reader readLongAttribute:@"inputTimeDotNetDateTimeOffsetTicks" onPath:path];
    NSTimeInterval inputSecs = inputTicks / 1e7 - (inputOffsetHours * 60 * 60);
    response.inputTime = [NSDate dateWithTimeInterval:inputSecs sinceDate:dotNetRefDate];
    
    // Data
    const char *dsetPath = [[path stringByAppendingString:@"/data"] cStringUsingEncoding:[NSString defaultCStringEncoding]];
    hid_t dsetId = H5Dopen(_reader.fileId, dsetPath, H5P_DEFAULT);
    if (dsetId < 0) {
        NSLog(@"WARNING: H5Dopen failed for response data at '%s' — dataset does not exist", dsetPath);
        response.data = [NSData data];
        response.units = @"";
        return;
    }

    // Get dataspace and allocate memory for read buffer
    hid_t spaceId = H5Dget_space(dsetId);
    int rank = H5Sget_simple_extent_ndims(spaceId);
    hsize_t dims[rank];
    H5Sget_simple_extent_dims(spaceId, dims, NULL);

    int length = (int)dims[0];
    if (length != dims[0]) {
        [NSException raise:@"LengthTooLarge"
                    format:@"%s length is too large", dsetPath];
    }

    // Read data
    hid_t datatypeId = H5Topen(_reader.fileId, "MEASUREMENT", H5P_DEFAULT);
    if (datatypeId < 0) {
        NSLog(@"WARNING: Named datatype 'MEASUREMENT' not found in HDF5 file — cannot read response at '%s'", dsetPath);
        H5Sclose(spaceId);
        H5Dclose(dsetId);
        response.data = [NSData data];
        response.units = @"";
        return;
    }

    measurementData *buffer = malloc(length * sizeof(measurementData));
    H5Dread(dsetId, datatypeId, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
    
    const char *units = buffer[0].units;
    for (int i = 1; i < length; i++) {
        if (strcmp(units, buffer[i].units) != 0) {
            [NSException raise:@"HeterogeneousUnits" format:@"Units are not homogenous in response data"];
        }
    }
    response.units = [NSString stringWithCString:buffer[0].units encoding:[NSString defaultCStringEncoding]];

    NSMutableData *data = [NSMutableData dataWithCapacity:length * sizeof(double)];
    for (int i = 0; i < length; i++) {
        [data appendBytes:&buffer[i].quantity length:sizeof(double)];
    }
    response.data = data;

    free(buffer);
    H5Tclose(datatypeId);
    H5Sclose(spaceId);
    H5Dclose(dsetId);
}

@end
