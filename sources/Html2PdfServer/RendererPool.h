//
//  RendererPool.h
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 2013-01-26.
//  Copyright (c) 2013 All rights reserved.
//

#import <Foundation/Foundation.h>
@class Renderer;

@interface RendererPool : NSObject
{
    NSConditionLock *condLock;
    NSMutableSet *_availableRenderers;
    NSMutableSet *_inUseRenderers;
    NSUInteger numberOfProcessedRequests;
    double totalRequestProcessingDuration;
    double maxRequestProcessingDuration;
}

+  (void)setNumberOfRenderers:(NSUInteger)number;
+  (void)setNumberOfRequestsPerRenderer:(NSUInteger)number;

- (NSUInteger)numberOfRenderers;
- (NSUInteger)numberOfRequestsPerRenderer;
- (NSUInteger)numberOfAvailableRenderers;
- (NSSet*)allRenderers;

+ (RendererPool*)sharedPool;

- (Renderer *)renderer;

- (void)makeRendererAvailable:(Renderer *)renderer;

- (void)addRequestDuration:(double)duration;
- (NSUInteger)numberOfProcessedRequests;
- (double)averageRequestDuration;
- (double)maxRequestProcessingDuration;


- (void)replaceRenderer:(Renderer *)renderer;

@end
