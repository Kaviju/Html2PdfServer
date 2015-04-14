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
}

+  (void)setNumberOfRenderers:(NSInteger)number;

+ (RendererPool*)sharedPool;

- (Renderer *)renderer;

- (void)makeRendererAvailable:(Renderer *)renderer;

- (void)replaceRenderer:(Renderer *)renderer;

@end
