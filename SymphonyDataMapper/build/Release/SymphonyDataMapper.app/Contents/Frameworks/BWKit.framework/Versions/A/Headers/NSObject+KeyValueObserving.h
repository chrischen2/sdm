//
//  NSObject+KeyValueObserving.h
//  BWKit
//
//  Created by Barry Wark on 8/13/09.
//  Copyright 2009 Barry Wark. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSObject (BWKeyValueObservingAdditions)
// Use this instead of [NSObject addObserver:forKeyPath:options:context:]
- (void)bw_addObserver:(id)observer 
            forKeyPath:(NSString *)keyPath 
              selector:(SEL)selector 
              userInfo:(id)userInfo 
               options:(NSKeyValueObservingOptions)options;

// Use this instead of [NSObject removeObserver:forKeyPath:]
- (void)bw_removeObserver:(id)observer 
               forKeyPath:(NSString *)keyPath 
                 selector:(SEL)selector;
@end
