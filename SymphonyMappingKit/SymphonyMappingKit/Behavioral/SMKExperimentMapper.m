//
//  SMKExperimentMapper.m
//  SymphonyDataMapper
//
//  Created by Mark Cafaro on 12/28/12.
//  Copyright (c) 2012 Rieke Lab. All rights reserved.
//

#import "SMKExperimentMapper.h"
#import "SMKExperiment.h"
#import "SMKNote.h"
#import "SMKDataFileReader.h"
#import "SMKExperimentEnumerator.h"
#import "SMKSourceEnumerator.h"
#import "SMKDeviceEnumerator.h"
#import "SMKEpochGroupEnumerator.h"
#import "SMKEpochBlockEnumerator.h"
#import "SMKEpochBlock.h"
#import "SMKEpochEnumerator.h"
#import "SMKEpochGroup.h"
#import "SMKEpoch.h"
#import "SMKBackground.h"
#import "SMKStimulus.h"
#import "SMKResponse.h"
#import "SMKSource.h"

#import <AUIModel/AUIModel.h>
#import <AUIModel/IOBaseDAQAdditions.h>
#import <DAQFramework/AUIDAQStream.h>
#import <DAQFramework/AUIExternalDevice.h>
#import <DAQFramework/AUINullExternalDevice.h>

#import <BWKit/BWKit.h>
#import <hdf5.h>

@interface SMKExperimentMapper ()

- (void)addStreamForIO:(SMKIOBase *)io;
- (void)assertValid:(NSManagedObject *)objectForInsert;

@end

@implementation SMKExperimentMapper

+ (id)mapperForDataFilePath:(NSString *)dataFilePath
                    context:(NSManagedObjectContext *)context
                  auisqlUrl:(NSURL *)auisqlUrl
{
    return [[self alloc] initWithDataFilePath:dataFilePath
                                      context:context
                                    auisqlUrl:auisqlUrl];
}

- (id)initWithDataFilePath:(NSString *)dataFilePath
                   context:(NSManagedObjectContext *)context
                 auisqlUrl:(NSURL *)auisqlUrl
{
    self = [super init];
    if (self) {
        _dataFilePath = dataFilePath;
        _context = context;
        _auisqlUrl = auisqlUrl;
        _streams = [NSMutableSet set];
        _outH5FileId = -1;
        _epochCount = 0;
        _responseCount = 0;
    }
    return self;
}

- (void)map
{
    SMKDataFileReader *reader = [SMKDataFileReader readerForHdf5FilePath:_dataFilePath];
    SMKExperimentEnumerator *experimentEnumerator = [reader experimentEnumerator];
    SMKExperiment *experiment;
    int experimentCount = 0;
    while (experiment = [experimentEnumerator nextObject]) {
        experimentCount++;
        [self mapExperiment:experiment];
    }
    NSLog(@"Mapped %d experiment(s), %d epoch(s), %d response(s) written to HDF5",
          experimentCount, _epochCount, _responseCount);
}

- (void)mapExperiment:(SMKExperiment *)experiment
{
    Experiment *auiExperiment = [NSEntityDescription insertNewObjectForEntityForName:@"Experiment"
                                                              inManagedObjectContext:_context];
    
    auiExperiment.startDate = experiment.startTime;
    auiExperiment.daqID = @"edu.washington.bwark.acqui.ITCController_ITC00_0";
    auiExperiment.rigSettingsData = [NSData data];
    auiExperiment.purpose = experiment.purpose;
    auiExperiment.otherNotes = @"";
    //auiExperiment.keywords = experiment.keywords;
    
    [self assertValid:auiExperiment];
    
    // Setup HDF5 output file for response.
    //
    // We write the response data ourselves (AUIModel's internal
    // saveResponseDataToHDF5 hook no longer fires on modern Core Data), so
    // create the HDF5 file *before* wiring up FileSystemResource/alias.
    // Otherwise BWFileSystemResource's bookmark resolution sees a missing
    // file and pops an NSOpenPanel during CLI runs.
    NSURL *dataFileUrl = [_auisqlUrl URLByAppendingPathExtension:@"h5"];
    [[NSFileManager defaultManager] removeItemAtURL:dataFileUrl error:nil];
    _hdf5FileUrl = dataFileUrl;
    // Create the HDF5 file. To produce a file readable by BWKit/Ovation
    // (linked against HDF5 1.6.9 which only understands superblock v0/v1)
    // SymphonyMappingKit MUST be linked against HDF5 1.10.x — later versions
    // default to v2 superblocks. We set libver bounds to (EARLIEST, V18) so
    // HDF5 1.10 writes files using only features present in 1.8, which in
    // practice produces a v0 superblock that HDF5 1.6.9 can read.
    // HDF5 1.10 rejects (EARLIEST, EARLIEST); high bound must be >= V18.
    hid_t fapl = H5Pcreate(H5P_FILE_ACCESS);
    H5Pset_libver_bounds(fapl, H5F_LIBVER_EARLIEST, H5F_LIBVER_V18);
    _outH5FileId = H5Fcreate([[dataFileUrl path] UTF8String],
                             H5F_ACC_TRUNC, H5P_DEFAULT, fapl);
    H5Pclose(fapl);
    if (_outH5FileId < 0) {
        [NSException raise:@"CannotCreateH5" format:@"Unable to create %@", [dataFileUrl path]];
    }

    // Now that the HDF5 file exists on disk, wire up the FileSystemResource
    // so Ovation can locate the .auisql.h5 by relative path.
    //
    // We must NOT read back `responseDataFile.url` here: on modern macOS the
    // BWKit getter resolves through BWAlias → BDAlias.fullPathRelativeToPath:,
    // which relies on the legacy Carbon Alias Manager (AliasHandle/FSRef).
    // Those APIs are stubs on current macOS and return nil, so the getter
    // ends up calling [NSURL fileURLWithPath:nil] and throws
    // "*** -[NSURL initFileURLWithPath:]: nil string parameter".
    //
    // Instead, pass the NSURL we already have to the `alias` setter directly.
    // `alias` is an `id` transformable attribute; storing an NSURL there was
    // already how the previous "alias is a required value" fix worked on
    // macOS 10.13.3, and it keeps the Core Data validation happy without
    // ever touching BWAlias/Carbon.
    [auiExperiment useResponseDataFileAtURL:dataFileUrl];
    [BWFileSystemResource setURL:dataFileUrl relativeToRootURL:_auisqlUrl forFileSystemResource:auiExperiment.responseDataFile];
    auiExperiment.responseDataFile.alias = dataFileUrl;

    // Create a placeholder for the DAQ config so we can validate entities as they're created.
    // We'll create the real DAQ config after mapping all the entities.
    _daqConfigContainer = [NSEntityDescription insertNewObjectForEntityForName:@"DAQConfigContainer"
                                                        inManagedObjectContext:_context];
    _daqConfigContainer.daqConfigData = [NSData data];
    [self assertValid:_daqConfigContainer];
    
    // Load external devices plugin
    NSString *bundlePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"ExternalDevicesPlugin.plugin"];
    if (![[NSBundle bundleWithPath:bundlePath] principalClass]) {
        [NSException raise:@"CannotLoadBundle" format:@"Unable to load external devices plugin"];
    }
    
    // Import notes
    [self addNotesFromEntity:experiment toExperiment:auiExperiment];
    
    // Add experiment properties and keywords to common set
    NSMutableDictionary *protocolSettings = [NSMutableDictionary dictionary];
    for (NSString *key in [experiment.properties allKeys]) {
        id value = [experiment.properties valueForKey:key];
        NSString *newKey = [@"experiment:" stringByAppendingString:key];
        [protocolSettings setValue:value forKey:newKey];
    }
    
    NSMutableSet *keywords = [NSMutableSet set];
    [keywords addObjectsFromArray:[NSArray arrayWithSet:experiment.keywords]];
    
    // Import sources
    SMKSourceEnumerator *sourceEnumerator = experiment.sourceEnumerator;
    SMKSource *source;
    while (source = [sourceEnumerator nextObject]) {
        [self mapSource:source toExperiment:auiExperiment];
    }
    
    // All epoch groups with the same source are considered part of a "cell".
    NSMutableDictionary *cells = [NSMutableDictionary dictionary];
    SMKEpochGroupEnumerator *groupEnumerator = experiment.epochGroupEnumerator;
    SMKEpochGroup *group;
    while (group = [groupEnumerator nextObject]) {
        NSMutableSet *set = [cells objectForKey:group.source.uuid defaultValue:[NSMutableSet set]];
        [set addObject:group];
        [cells setObject:set forKey:group.source.uuid];
    }
    
    // Import cells
    for (NSSet *cell in [cells allValues]) {
        RecordedCell *auiCell = [NSEntityDescription insertNewObjectForEntityForName:@"Cell"
                                                              inManagedObjectContext:_context];
        
        SMKSource *source = ((SMKEpochGroup *)[cell anyObject]).source;
        
        auiCell.label = source.label;
        auiCell.experiment = auiExperiment;
        auiCell.comment = @"";
        auiCell.startDate = nil;
        
        NSEnumerator *cellEnumerator = [cell objectEnumerator];
        while (group = [cellEnumerator nextObject]) {
            
            if (auiCell.startDate == nil || auiCell.startDate > group.startTime) {
                auiCell.startDate = group.startTime;
            }
            
            [self mapEpochGroup:group protocolSettings:protocolSettings keywords:keywords toCell:auiCell];
            
            [self assertValid:auiCell];
            
            // cut down on memory usage by flushing per cell
            NSError *error;
            if ([_context save:&error] == NO) {
                [NSException raise:@"Failed to save context" format:@"Failed to save context: %@", [error localizedDescription]];
            }
        }
    }
    
    // Create DAQ config from streams created while mapping
    NSSet *streamProperties = [_streams valueForKey:@"streamProperties"];
    
    // HACK: this is inside the AUIIOController but we don't want to create an entire controller just for the daq config
    NSString *AUIIOControllerStreamPropertiesKey = @"AUIIOControllerStreamPropertiesKey";
    NSDictionary *configDict = [NSDictionary dictionaryWithObject:streamProperties
                                                           forKey:AUIIOControllerStreamPropertiesKey];
    NSData *configData = [NSKeyedArchiver archivedDataWithRootObject:configDict];
    
    _daqConfigContainer.daqConfigData = configData;
    [self assertValid:_daqConfigContainer];
    
    NSError *error;
    if ([_context save:&error] == NO) {
        [NSException raise:@"Failed to save context" format:@"Failed to save context: %@", [error localizedDescription]];
    }

    if (_outH5FileId >= 0) {
        H5Fclose(_outH5FileId);
        _outH5FileId = -1;
    }
}

- (void)writeResponseData:(NSData *)data withUUID:(NSString *)uuid
{
    NSUInteger sampleCount = [data length] / sizeof(double);
    if (sampleCount == 0) {
        NSLog(@"WARNING: Response %@ has 0 samples — empty data will not be visible in Ovation", uuid);
    }
    hsize_t dims[1] = { (hsize_t)sampleCount };
    hid_t space = H5Screate_simple(1, dims, NULL);
    hid_t dset = H5Dcreate2(_outH5FileId, [uuid UTF8String],
                            H5T_IEEE_F64LE, space,
                            H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
    H5Dwrite(dset, H5T_NATIVE_DOUBLE, H5S_ALL, H5S_ALL, H5P_DEFAULT, [data bytes]);

    // dtypeString = "<f8" (numpy little-endian float64), stored as 4-byte
    // null-terminated ASCII matching the legacy sdm2 file layout.
    hid_t atype = H5Tcopy(H5T_C_S1);
    H5Tset_size(atype, 4);
    H5Tset_strpad(atype, H5T_STR_NULLTERM);
    H5Tset_cset(atype, H5T_CSET_ASCII);
    hid_t ascalar = H5Screate(H5S_SCALAR);
    hid_t attr = H5Acreate2(dset, "dtypeString", atype, ascalar,
                            H5P_DEFAULT, H5P_DEFAULT);
    H5Awrite(attr, atype, "<f8");
    H5Aclose(attr);
    H5Sclose(ascalar);
    H5Tclose(atype);

    H5Dclose(dset);
    H5Sclose(space);
}

- (void)mapSource:(SMKSource *)source toExperiment:(Experiment *)auiExperiment
{
    [self addNotesFromEntity:source toExperiment:auiExperiment];
    
    SMKSourceEnumerator *sourceEnumerator = source.sourceEnumerator;
    SMKSource *subSource;
    while (subSource = [sourceEnumerator nextObject]) {
        [self mapSource:subSource toExperiment:auiExperiment];
    }
}

- (void)mapEpochGroup:(SMKEpochGroup *)group protocolSettings:(NSMutableDictionary *)commonProtocolSettings keywords:(NSMutableSet *)commonKeywords toCell:(RecordedCell *)auiCell
{
    NSMutableDictionary *protocolSettings = [NSMutableDictionary dictionaryWithDictionary:commonProtocolSettings];
    NSMutableSet *keywords = [NSMutableSet setWithSet:commonKeywords];
    
    int sourceLevel = 0;
    SMKSource *currentSource = group.source;
    while (currentSource != nil) {
        NSString *prefix = @"source:";
        for (int i = 0; i < sourceLevel; i++) {
            prefix = [prefix stringByAppendingString:@"parent:"];
        }
        
        [protocolSettings setValue:currentSource.label forKey:[prefix stringByAppendingString:@"label"]];
        
        for (NSString *key in [currentSource.properties allKeys]) {
            id value = [currentSource.properties valueForKey:key];
            NSString *newKey = [prefix stringByAppendingString:key];
            if ([protocolSettings hasKey:newKey]) {
                NSLog(@"%@ wants to have two values: %@ and %@. Using the first.", newKey, [protocolSettings valueForKey:newKey], value);
            } else {
                [protocolSettings setValue:value forKey:newKey];
            }
        }
        
        [keywords addObjectsFromArray:[NSArray arrayWithSet:currentSource.keywords]];
        
        currentSource = currentSource.parent;
        sourceLevel++;
    }
    
    int groupLevel = 0;
    SMKEpochGroup *currentGroup = group;
    while (currentGroup != nil) {
        NSString *prefix = @"epochGroup:";
        for (int i = 0; i < groupLevel; i++) {
            prefix = [prefix stringByAppendingString:@"parent:"];
        }
        
        [protocolSettings setValue:currentGroup.label forKey:[prefix stringByAppendingString:@"label"]];
        
        for (NSString *key in [currentGroup.properties allKeys]) {
            id value = [currentGroup.properties valueForKey:key];
            NSString *newKey = [prefix stringByAppendingString:key];
            if ([protocolSettings hasKey:newKey]) {
                NSLog(@"%@ wants to have two values: %@ and %@. Using the first.", newKey, [protocolSettings valueForKey:newKey], value);
            } else {
                [protocolSettings setValue:value forKey:newKey];
            }
        }
        
        [keywords addObjectsFromArray:[NSArray arrayWithSet:currentGroup.keywords]];
        
        currentGroup = currentGroup.parent;
        groupLevel++;
    }
    
    [self addNotesFromEntity:group toExperiment:auiCell.experiment];
    
    SMKEpochBlockEnumerator *blockEnumerator = group.epochBlockEnumerator;
    SMKEpochBlock *block;
    while (block = [blockEnumerator nextObject]) {
        @autoreleasepool {
            [self mapEpochBlock:block protocolSettings:protocolSettings keywords:keywords toCell:auiCell];
        }
    }
    
    SMKEpochGroupEnumerator *groupEnumerator = group.epochGroupEnumerator;
    SMKEpochGroup *subGroup;
    while (subGroup = [groupEnumerator nextObject]) {
        [self mapEpochGroup:subGroup protocolSettings:commonProtocolSettings keywords:commonKeywords toCell:auiCell];
    }
}

- (void)mapEpochBlock:(SMKEpochBlock *)block protocolSettings:(NSMutableDictionary *)commonProtocolSettings keywords:(NSMutableSet *)commonKeywords toCell:(RecordedCell *)auiCell
{
    [self addNotesFromEntity:block toExperiment:auiCell.experiment];
    
    SMKEpochEnumerator *epochEnumerator = block.epochEnumerator;
    SMKEpoch *epoch;
    while (epoch = [epochEnumerator nextObject]) {
        Epoch *auiEpoch = [NSEntityDescription insertNewObjectForEntityForName:@"Epoch"
                                                        inManagedObjectContext:_context];
        
        auiEpoch.startDate = epoch.startTime;
        auiEpoch.saveResponse = [NSNumber numberWithBool:YES];
        auiEpoch.includeInAnalysis = [NSNumber numberWithBool:YES];
        auiEpoch.protocolID = block.protocolId;
        auiEpoch.comment = @"";
        auiEpoch.daqConfig = _daqConfigContainer;
        auiEpoch.duration = [NSNumber numberWithDouble:[epoch.endTime timeIntervalSinceDate:epoch.startTime]];
        
        // Protocol settings
        NSMutableDictionary *protocolSettings = [NSMutableDictionary dictionary];
        [protocolSettings addEntriesFromDictionary:commonProtocolSettings];
        [protocolSettings addEntriesFromDictionary:block.protocolParameters];
        [protocolSettings addEntriesFromDictionary:epoch.protocolParameters];
        
        // Epoch block
        [protocolSettings setValue:block.startTime forKey:@"epochBlock:startTime"];
        [protocolSettings setValue:block.endTime forKey:@"epochBlock:endTime"];
        
        // Backgrounds
        for (SMKBackground *background in epoch.backgrounds) {
            NSString *key = [@"background:" stringByAppendingString:[background.device.name stringByReplacingOccurrencesOfString: @" " withString: @"_"]];
            [protocolSettings setValue:background.value forKey:[NSString stringWithFormat:@"%@:%@", key, @"value"]];
            
            for (NSString *paramKey in [background.deviceParameters allKeys]) {
                id value = [background.deviceParameters valueForKey:paramKey];
                NSString *newParamKey = [NSString stringWithFormat:@"%@:%@", key, paramKey];
                if ([protocolSettings hasKey:newParamKey]) {
                    NSLog(@"%@ wants to have two values: %@ and %@. Using the first.", newParamKey, [protocolSettings valueForKey:newParamKey], value);
                } else {
                    [protocolSettings setValue:value forKey:newParamKey];
                }
            }
        }
        
        // Add epoch properties
        [protocolSettings setValue:epoch.startTime forKey:@"epoch:startTime"];
        [protocolSettings setValue:epoch.endTime forKey:@"epoch:endTime"];
        for (NSString *key in [epoch.properties allKeys]) {
            id value = [epoch.properties valueForKey:key];
            NSString *newKey = [@"epoch:" stringByAppendingString:key];
            if ([protocolSettings hasKey:newKey]) {
                NSLog(@"%@ wants to have two values: %@ and %@. Using the first.", newKey, [protocolSettings valueForKey:newKey], value);
            } else {
                [protocolSettings setValue:value forKey:newKey];
            }
        }
        
        // Add epoch keywords
        for (NSString *keyword in epoch.keywords) {
            KeywordTag *tag = [KeywordTag keywordTagWithTag:keyword inManagedObjectContext:_context error:nil];
            [auiEpoch addKeywordsObject:tag];
        }
        
        // Add epoch block keywords
        for (NSString *keyword in block.keywords) {
            KeywordTag *tag = [KeywordTag keywordTagWithTag:keyword inManagedObjectContext:_context error:nil];
            [auiEpoch addKeywordsObject:tag];
        }
        
        // Add source and epoch group keywords
        for (NSString *keyword in commonKeywords) {
            KeywordTag *tag = [KeywordTag keywordTagWithTag:keyword inManagedObjectContext:_context error:nil];
            [auiEpoch addKeywordsObject:tag];
        }
        
        auiEpoch.cell = auiCell;
        _epochCount++;

        // The sample rate is stored in the responses by Symphony and the stimuli by Acquirino
        // It should be consistent throughout all responses of the epoch.
        NSNumber *sampleRate = nil;
        for (SMKResponse *response in epoch.responses) {
            if (sampleRate != nil && ![sampleRate isEqualToNumber:response.sampleRate]) {
                [NSException raise:@"HeterogeneousSampleRate" format:@"Unexpected heterogeneous sample rate in epoch"];
            }
            sampleRate = response.sampleRate;
        }
        
        // Stimuli
        for (SMKStimulus *stimulus in epoch.stimuli) {
            
            // Stream
            [self addStreamForIO:stimulus];
            
            // Stimulus
            Stimulus *auiStimulus = [NSEntityDescription insertNewObjectForEntityForName:@"Stimulus"
                                                                  inManagedObjectContext:_context];
            auiStimulus.type = [NSNumber numberWithInt:stimulus.streamType];
            auiStimulus.externalDeviceMode = [NSNumber numberWithInt:stimulus.deviceMode];
            auiStimulus.externalDeviceGain = [NSNumber numberWithInt:1];
            auiStimulus.channelID = stimulus.channelNumber;
            auiStimulus.duration = auiEpoch.duration;
            auiStimulus.stimulusID = stimulus.stimulusId;
            auiStimulus.sampleRate = sampleRate;
            auiStimulus.version = [NSNumber numberWithInt:0];
            
            // Consolidate stimulus parameters and device parameters into the parameters property
            NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
            for (NSString *key in [stimulus.deviceParameters allKeys]) {
                id value = [stimulus.deviceParameters valueForKey:key];
                NSString *newKey = [NSString stringWithFormat:@"deviceParameter:%@", key];
                [parameters setValue:value forKey:newKey];
            }
            [parameters addEntriesFromDictionary:stimulus.parameters];
            
            [KeyValuePair updateKVPSet:[auiStimulus mutableSetValueForKey:@"parametersKVPairs"]
                        fromDictionary:parameters
                  managedObjectContext:_context];
            
            auiStimulus.epoch = auiEpoch;
            
            // Add stimulus parameters and device parameters to epoch protocol settings for convenience
            NSString* streamName = [stimulus.device.name stringByReplacingOccurrencesOfString: @" " withString: @"_"];
            for (NSString *key in [stimulus.parameters allKeys]) {
                id value = [stimulus.parameters valueForKey:key];
                NSString *newKey = [NSString stringWithFormat:@"stimulus:%@:%@", streamName, key];
                [protocolSettings setValue:value forKey:newKey];
            }
            for (NSString *key in [stimulus.deviceParameters allKeys]) {
                id value = [stimulus.deviceParameters valueForKey:key];
                NSString *newKey = [NSString stringWithFormat:@"stimulus:%@:%@", streamName, key];
                if ([protocolSettings hasKey:newKey]) {
                    NSLog(@"%@ wants to have two values: %@ and %@. Using the first.", newKey, [protocolSettings valueForKey:newKey], value);
                } else {
                    [protocolSettings setValue:value forKey:newKey];
                }
            }
            
            [self assertValid:auiStimulus];
        }
        
        // Responses
        for (SMKResponse *response in epoch.responses) {
            
            // Stream
            [self addStreamForIO:response];
            
            // Response
            Response *auiResponse = [NSEntityDescription insertNewObjectForEntityForName:@"Response"
                                                                  inManagedObjectContext:_context];
            
            auiResponse.type = [NSNumber numberWithInt:response.streamType];
            auiResponse.externalDeviceMode = [NSNumber numberWithInt:response.deviceMode];
            auiResponse.externalDeviceGain = [NSNumber numberWithInt:1];
            auiResponse.channelID = response.channelNumber;
            auiResponse.sampleBytes = [NSNumber numberWithInt:sizeof(double)];

            // Bypass AUIModel's broken save-to-HDF5 hook: generate a UUID,
            // store it on the Response, and write bytes directly to our h5.
            NSString *uuid = [[NSUUID UUID] UUIDString];
            auiResponse.dataUUID = uuid;
            [self writeResponseData:response.data withUUID:uuid];
            _responseCount++;

            auiResponse.epoch = auiEpoch;
            [self assertValid:auiResponse];
        }
        
        [KeyValuePair updateKVPSet:[auiEpoch mutableSetValueForKey:@"protocolSettingsKVPairs"]
                    fromDictionary:protocolSettings
              managedObjectContext:_context];
        
        [self assertValid:auiEpoch];
    }
}

- (void)addStreamForIO:(SMKIOBase *)io
{
    AUIDAQStream *stream = [[AUIDAQStream alloc] initWithIOController:nil
                                                        channelNumber:[io.channelNumber intValue]
                                                                 type:io.streamType];
    stream.userDescription = io.device.name;
    if ([[io.deviceParameters valueForKey:@"HardwareType"] isEqualToString:@"MCTG_HW_TYPE_MC700B"]) {
        stream.externalDevice = [[NSClassFromString(@"AUIMultiClampDevice") alloc] init];
    } else {
        stream.externalDevice = [[AUINullExternalDevice alloc] init];
    }
    // HACK: The stream objects won't compare properly without a controller.
    BOOL exists = NO;
    for (AUIDAQStream *s in _streams) {
        if (s.type == stream.type
            && [s.userDescription isEqualToString:stream.userDescription]
            && s.channelNumber == stream.channelNumber) {
            exists = YES;
            break;
        }
    }
    if (!exists) {
        [_streams addObject:stream];
    }
}

- (void)addNotesFromEntity:(SMKEntity *)entity toExperiment:(Experiment *)experiment
{
    for (SMKNote *note in entity.notes) {
        Note *auiNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note"
                                                      inManagedObjectContext:_context];
        
        auiNote.date = note.timestamp;
        auiNote.text = note.comment;
        auiNote.experiment = experiment;
        
        [self assertValid:auiNote];
    }
}

- (void)assertValid:(NSManagedObject *)objectForInsert
{
    NSError *error;
    
    BOOL isValid = [objectForInsert validateForInsert:&error];
    
    if (!isValid) {
        [NSException raise:@"Failed to validate object" format:@"Failed to validate object: %@", [error localizedDescription]];
    }
}

@end
