//
//  RendererPool.m
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 2013-01-26.
//

#import "RendererPool.h"
#import "Renderer.h"
#import <sys/sysctl.h> 
#define LOCK_NO_DATA 0
#define LOCK_HAS_DATA 1

@interface RendererPool (Private)

- (void)addRenderer;

- (void)unlock;

@end

@implementation RendererPool

static RendererPool *sharedPool = nil;
static NSUInteger numberOfRenderers = 0;
static NSUInteger numberOfRequestsPerRenderer = 100;

- (id)initWithNumberOfRenderer:(long) number
{
    self = [super init];
    if (self)
	{
        condLock = [[NSConditionLock alloc] initWithCondition:LOCK_NO_DATA];
        _availableRenderers = [NSMutableSet new];
        _inUseRenderers = [NSMutableSet new];
        while (number--)
        {
            [self addRenderer];
        }
    }
    return self;
}

+  (void)setNumberOfRenderers:(NSUInteger)number
{
    numberOfRenderers = number;
}

+  (void)setNumberOfRequestsPerRenderer:(NSUInteger)number
{
    numberOfRequestsPerRenderer = number;
}

+ (int)numberOfCPUs
{
    int nm[2];
    size_t len = 4;
    uint32_t count;

    nm[0] = CTL_HW; nm[1] = HW_AVAILCPU;
    sysctl(nm, 2, &count, &len, NULL, 0);

    if(count < 1) {
        nm[1] = HW_NCPU;
        sysctl(nm, 2, &count, &len, NULL, 0);
        if(count < 1) { count = 1; }
        }
    return count;
}

+ (RendererPool*)sharedPool
{
    if (sharedPool == nil)
    {
        if (numberOfRenderers == 0) {
            numberOfRenderers = [self numberOfCPUs];
        }
        sharedPool = [[RendererPool alloc] initWithNumberOfRenderer:numberOfRenderers];
    }
    return sharedPool;
}

- (NSUInteger)numberOfRenderers
{
    return numberOfRenderers;
}

- (NSUInteger)numberOfRequestsPerRenderer
{
    return numberOfRequestsPerRenderer;
}

- (NSUInteger)numberOfAvailableRenderers
{
    return [_availableRenderers count];
}

- (NSSet*)allRenderers
{
    return [_availableRenderers setByAddingObjectsFromSet:_inUseRenderers];
}


- (Renderer *)renderer
{
    NSLog(@"renderer asked queue size: %ld", (unsigned long)[_availableRenderers count]);
    [condLock lockWhenCondition:LOCK_HAS_DATA];
    Renderer *renderer = [_availableRenderers anyObject];
    [_availableRenderers removeObject:renderer];
    [_inUseRenderers addObject:renderer];
    [self unlock];
    NSLog(@"renderer returned %@", renderer);
    return renderer;
}

- (void)makeRendererAvailable:(Renderer *)renderer
{
    if (renderer.numberOfRequests >= numberOfRequestsPerRenderer) {
        NSLog(@"renderer has processing %ld requests, stop it %@", renderer.numberOfRequests, renderer);
        [renderer stopTask];
    }
    else {
        [condLock lock];
        [_availableRenderers addObject:renderer];
        [_inUseRenderers removeObject:renderer];
        NSLog(@"renderer available %@", renderer);
        [self unlock];
    }
}

- (void)replaceRenderer:(Renderer *)renderer
{
    [condLock lock];
    [_availableRenderers removeObject:renderer];
    [_inUseRenderers removeObject:renderer];
    [self unlock];
    [self addRenderer];
}

- (void)addRequestDuration:(double)duration
{
    numberOfProcessedRequests += 1;
    totalRequestProcessingDuration += duration;
    maxRequestProcessingDuration = MAX(maxRequestProcessingDuration, duration);
}

- (NSUInteger)numberOfProcessedRequests
{
    return numberOfProcessedRequests;
}

- (double)averageRequestDuration
{
    if (numberOfProcessedRequests == 0) {
        return 0.0;
    }
    return totalRequestProcessingDuration / numberOfProcessedRequests;
}

- (double)maxRequestProcessingDuration
{
    return maxRequestProcessingDuration;
}

@end

@implementation RendererPool (Private)

- (void)addRenderer
{
    [condLock lock];
    Renderer *newRenderer = [[Renderer alloc] initWithPool:self];
    [newRenderer startTask];

    [_availableRenderers addObject:newRenderer];
    [self unlock];
}

- (void)unlock
{
    [condLock unlockWithCondition:([_availableRenderers count]>0 ? LOCK_HAS_DATA : LOCK_NO_DATA)];
}

@end
