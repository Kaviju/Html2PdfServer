//
//  RendererPool.m
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 2013-01-26.
//

#import "RendererPool.h"
#import "Renderer.h"
#import <sys/sysctl.h> 
#define NO_DATA 0
#define HAS_DATA 1

@interface RendererPool (Private)

- (void)addRenderer;

- (void)unlock;

@end

@implementation RendererPool

static RendererPool *sharedPool = nil;
static NSInteger numberOfRenderers = 0;

- (id)initWithNumberOfRenderer:(long) number
{
    self = [super init];
    if (self)
	{
        condLock = [[NSConditionLock alloc] initWithCondition:NO_DATA];
        _availableRenderers = [NSMutableSet new];
        _inUseRenderers = [NSMutableSet new];
        while (number--)
        {
            [self addRenderer];
        }
    }
    return self;
}

+  (void)setNumberOfRenderers:(NSInteger)number
{
    numberOfRenderers = number;
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


- (Renderer *)renderer
{
    NSLog(@"renderer asked queue size: %ld", (unsigned long)[_availableRenderers count]);
    [condLock lockWhenCondition:HAS_DATA];
    Renderer *renderer = [_availableRenderers anyObject];
    [_availableRenderers removeObject:renderer];
    [_inUseRenderers addObject:renderer];
    [self unlock];
    NSLog(@"renderer returned %@", renderer);
    return renderer;
}

- (void)makeRendererAvailable:(Renderer *)renderer
{
    [condLock lock];
    [_availableRenderers addObject:renderer];
    [_inUseRenderers removeObject:renderer];
    NSLog(@"renderer available %@", renderer);
    [self unlock];
}

- (void)replaceRenderer:(Renderer *)renderer
{
    [condLock lock];
    [_availableRenderers removeObject:renderer];
    [_inUseRenderers removeObject:renderer];
    [self unlock];
    [self addRenderer];
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
    [condLock unlockWithCondition:([_availableRenderers count]>0 ? HAS_DATA : NO_DATA)];
}

@end