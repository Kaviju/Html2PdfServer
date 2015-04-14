//
//  Renderer.h
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 2013-01-26.
//  Copyright (c) 2013. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^RendererCompletionBlock)(NSData *, NSMutableDictionary *, NSArray *);

@class RendererPool;

@interface Renderer : NSObject
{
    NSMutableArray *messages;
}

@property (nonatomic, copy) RendererCompletionBlock completionBlock;

- (id)initWithPool:(RendererPool *)pool;

- (void)processRequest:(NSString *)requestUrl firstPageNumber:(int)firstPageNumber completionBlock:(RendererCompletionBlock)aBlock;

- (void)startTask;

@end
