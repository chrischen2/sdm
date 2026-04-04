//
//  SMKIOBaseEnumerator.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKIOBaseEnumerator.h"
#import "SMKIOBase.h"
#import "SMKDeviceEnumerator.h"
#import "MACHdf5Reader.h"
#import "MACHdf5LinkInformation.h"

@implementation SMKIOBaseEnumerator

- (void)mapEntity:(SMKEntity *)entity withPath:(NSString *)path
{
    [super mapEntity:entity withPath:path];
    
    SMKIOBase *iobase = (SMKIOBase *)entity;
    
    NSArray *members = [_reader allGroupMembersInPath:path];
    
    NSString *devicePath = [path stringByAppendingString:@"/device"];
    SMKDeviceEnumerator *deviceEnumerator = [[SMKDeviceEnumerator alloc] initWithReader:_reader entityPaths:[NSArray arrayWithObjects:devicePath, nil]];
    iobase.device = deviceEnumerator.nextObject;
    
    // Read device parameters
    NSNumberFormatter *numFormatter = [NSNumberFormatter new];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    if ([members containsObject:@"dataConfigurationSpans"]) {
        NSArray *spanMembers = [_reader groupMemberLinkInfoInPath:[path stringByAppendingString:@"/dataConfigurationSpans"]];
        for (MACHdf5LinkInformation *spanMember in spanMembers) {
            NSArray *nodeMembers = [_reader groupMemberLinkInfoInPath:spanMember.path];
            for (MACHdf5LinkInformation *nodeMember in nodeMembers) {
                NSString *name = [nodeMember.path lastPathComponent];
                
                if ([name isEqualTo:iobase.device.name]) {
                    NSDictionary *dic = [_reader readAttributesOnPath:nodeMember.path];
                    NSEnumerator* e = [dic keyEnumerator];
                    id key = nil;
                    while ((key = [e nextObject]) != nil) {
                        id new = [dic objectForKey:key];
                        id old = [parameters objectForKey:key];
                        if (old != nil && ![old isEqualTo:new]) {
                            NSLog(@"%@ contains more than one device parameter value for %@ (%@ and %@). Using %@.", path, key, old, new, new);
                        }
                        [parameters setObject:new forKey:key];
                    }
                    break;
                }
            }
            
            // Read channel
            NSString *channelTypeStr;
            NSNumber *channelNumber = NULL;
            for (MACHdf5LinkInformation *nodeMember in nodeMembers) {
                NSString *name = [nodeMember.path lastPathComponent];
                
                if ([name hasPrefix:@"ANALOG_IN"] || [name hasPrefix:@"ANALOG_OUT"] || [name hasPrefix:@"DIGITAL_IN"] || [name hasPrefix:@"DIGITAL_OUT"]) {
                    // old stream name format
                    NSArray *comps = [name componentsSeparatedByString:@"."];
                    if ([comps count] != 2) {
                        continue;
                    }
                    
                    channelTypeStr = [comps objectAtIndex:0];
                    
                    NSString *numStr = [comps lastObject];
                    channelNumber = [numFormatter numberFromString:numStr];
                    break;
                    
                } else if ([name hasPrefix:@"ai"] || [name hasPrefix:@"ao"] || [name hasPrefix:@"diport"] || [name hasPrefix:@"doport"]) {
                    // new stream name format
                    NSRange split = [name rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
                    if (split.location == NSNotFound) {
                        continue;
                    }
                    
                    channelTypeStr = [name substringToIndex:split.location];
                    
                    NSString *numStr = [name substringFromIndex:split.location];
                    channelNumber = [numFormatter numberFromString:numStr];
                    break;
                }
            }
            
            if (channelNumber == NULL) {
                [NSException raise:@"CannotFindChannelSpan" format:@"Cannot find channel span"];
            }
            
            StreamType type = [self typeWithString:channelTypeStr];
            
            if (iobase.streamType != UNCONFIGURED && iobase.streamType != type
                && iobase.channelNumber != nil && ![iobase.channelNumber isEqualToNumber:channelNumber]) {
                [NSException raise:@"HeterogeneousChannel" format:@"Channel is not homogenous in %@", path];
            }
            
            iobase.streamType = type;
            iobase.channelNumber = channelNumber;
        }
    }
    iobase.deviceParameters = parameters;
    
    iobase.deviceMode = [self modeWithString:[parameters valueForKey:@"OperatingMode"]];
}

- (StreamType)typeWithString:(NSString *)typeStr
{
    if ([typeStr isEqualToString:@"ANALOG_OUT"] || [typeStr isEqualToString:@"ao"]) {
        return ANALOG_OUT;
    } else if ([typeStr isEqualToString:@"ANALOG_IN"] || [typeStr isEqualToString:@"ai"]) {
        return ANALOG_IN;
    } else if ([typeStr isEqualToString:@"DIGITAL_OUT"] || [typeStr isEqualToString:@"doport"]) {
        return DIGITAL_OUT;
    } else if ([typeStr isEqualToString:@"DIGITAL_IN"] || [typeStr isEqualToString:@"diport"]) {
        return DIGITAL_IN;
    } else {
        [NSException raise:@"UnknownStreamType" format:@"Encountered unknown stream type"];
    }
    return UNCONFIGURED;
}

- (AxoPatchAmpMode)modeWithString:(NSString *)modeStr
{
    if ([modeStr isEqualToString:@"VClamp"]) {
        return VCLAMP_MODE;
    } else if ([modeStr isEqualToString:@"IO"]) {
        return I0_MODE;
    } else if ([modeStr isEqualToString:@"IClamp"]) {
        return ICLAMP_NORMAL_MODE;
    } else {
        return UNKNOWN_MODE;
    }
}

@end
