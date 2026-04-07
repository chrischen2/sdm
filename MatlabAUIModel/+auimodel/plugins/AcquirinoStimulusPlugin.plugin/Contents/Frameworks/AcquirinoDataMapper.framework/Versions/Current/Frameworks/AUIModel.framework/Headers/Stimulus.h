//
//  Stimulus.h
//  AcqUI
//
//  Created by Barry Wark on 12/11/06.
//  Copyright 2006 Barry Wark. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <AUIModel/IOBase.h>
#import <AUIModel/AUIKeyValuePair.h>
#import <AUIModel/AUIFileSystemResource.h>

@class Epoch;

@interface Stimulus :  IOBase  
{
}

@property (retain) NSData * data;
@property (retain) NSNumber * duration;
@property (retain) NSNumber * sampleRate;
@property (retain) NSNumber * showPlot;
@property (retain) NSString * stimulusDescription;
@property (retain) NSString * stimulusID;
@property (retain) NSNumber * subStimulusIndex;
@property (retain) NSNumber * version;

@property (retain) Epoch * epoch;
@property (retain) NSSet* parametersKVPairs;
@property (retain) Stimulus * parentStimulus;
@property (retain) NSSet* sKeywords;
@property (retain) NSSet* sResources;
@property (retain) NSSet* subStimuli;

@end

// coalesce these into one @interface Stimulus (CoreDataGeneratedAccessors) section
@interface Stimulus (CoreDataGeneratedAccessors)
- (void)addParametersKVPairsObject:(AUIKeyValuePair *)value;
- (void)removeParametersKVPairsObject:(AUIKeyValuePair *)value;
- (void)addParametersKVPairs:(NSSet *)value;
- (void)removeParametersKVPairs:(NSSet *)value;

- (void)addSKeywordsObject:(KeywordTag *)value;
- (void)removeSKeywordsObject:(KeywordTag *)value;
- (void)addSKeywords:(NSSet *)value;
- (void)removeSKeywords:(NSSet *)value;

- (void)addSResourcesObject:(AUIFileSystemResource *)value;
- (void)removeSResourcesObject:(AUIFileSystemResource *)value;
- (void)addSResources:(NSSet *)value;
- (void)removeSResources:(NSSet *)value;

- (void)addSubStimuliObject:(Stimulus *)value;
- (void)removeSubStimuliObject:(Stimulus *)value;
- (void)addSubStimuli:(NSSet *)value;
- (void)removeSubStimuli:(NSSet *)value;

@end

