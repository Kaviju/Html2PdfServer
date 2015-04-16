//
//  Renderer.m
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 2013-01-26.
//

#import "Renderer.h"
#import "RendererPool.h"

#define BlockLengthSize 12

@implementation Renderer
{
    RendererPool *_parentPool;
    NSTask *_rendererTask;
    NSPipe *_requestPipe;
    NSPipe *_pdfPipe;
    NSPipe *_errorPipe;
}

- (id)initWithPool:(RendererPool *)pool
{
    self = [super init];
    if (self)
	{
        _parentPool = pool;
    }
    return self;
}

- (void)startTask
{
    _rendererTask = [[NSTask alloc] init];
    NSString *rendererPath = [[NSBundle mainBundle] pathForResource:@"Html2PdfRenderer" ofType:@"app"];
    rendererPath = [rendererPath stringByAppendingPathComponent:@"Contents/MacOS/Html2PdfRenderer"];
    [_rendererTask setLaunchPath:rendererPath];
    
    _requestPipe = [[NSPipe alloc] init];
    _pdfPipe = [[NSPipe alloc] init];
    _errorPipe = [[NSPipe alloc] init];
    [_rendererTask setStandardInput:_requestPipe];
    [_rendererTask setStandardError:_errorPipe];
    [_rendererTask setStandardOutput:_pdfPipe];
    [_rendererTask launch];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    
    // When app quit, quit all renderer sub processes.
    [nc addObserverForName:NSApplicationWillTerminateNotification object:nil queue:mainQueue usingBlock:^(NSNotification *note) {
        [_rendererTask terminate];
    }];
    
    // If renderer process die, replace it in the pool and notify the client.
    [nc addObserverForName:NSTaskDidTerminateNotification object:_rendererTask queue:mainQueue usingBlock:^(NSNotification *note) {
        NSTask *task = note.object;
        if ( [task terminationReason] == NSTaskTerminationReasonUncaughtSignal) {
            [_parentPool replaceRenderer:self];
            if (_completionBlock != nil) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL), ^{
                    _completionBlock(nil, nil, messages);
                });
            }
        }
    }];
    
    
    NSFileHandle *errorFH = [_errorPipe fileHandleForReading];
    [nc addObserver:self selector:@selector(readMessage:) name:NSFileHandleReadCompletionNotification object:errorFH];
    [errorFH readInBackgroundAndNotify];
    
    NSFileHandle *pdfFH = [_pdfPipe fileHandleForReading];
    [nc addObserver:self selector:@selector(readPdf:) name:NSFileHandleReadCompletionNotification object:pdfFH];
    [pdfFH readInBackgroundAndNotify];
}

- (void)processRequest:(NSString *)requestUrl firstPageNumber:(int)firstPageNumber completionBlock:(RendererCompletionBlock)aBlock
{
    self.completionBlock = aBlock;
    messages = [NSMutableArray new];

    NSDictionary *paramDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:firstPageNumber], @"firstPageNumber",
                               requestUrl, @"url",
                               nil];
    NSError *error;
    NSData *paramDictData = [NSPropertyListSerialization dataWithPropertyList:paramDict
                                                                      format:NSPropertyListXMLFormat_v1_0
                                                                     options:NSPropertyListMutableContainers error:&error];

    NSFileHandle *requestFH = [_requestPipe fileHandleForWriting];
    [requestFH writeData:paramDictData];
}

- (void)readMessage:(NSNotification *)aNotification
{
    NSData *messageData = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    if ([messageData length] == 0) { // FileHandle was closed
        return;
    }
    NSString *message = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    [messages addObject:message];
    
    NSFileHandle *fh = [aNotification object];
    [fh readInBackgroundAndNotify];
}

- (int)readBlockLength:(NSData *)readData atIndex:(unsigned)offset
{
    NSData *blockLength = [readData subdataWithRange:NSMakeRange(offset, BlockLengthSize)];
    NSString *blockLengthAsString = [[NSString alloc] initWithData:blockLength encoding:NSUTF8StringEncoding];
    blockLengthAsString = [blockLengthAsString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    int pdfLength = [blockLengthAsString intValue];
    return pdfLength;
}

- (void)readPdf:(NSNotification *)aNotification
{
    @autoreleasepool { // Leaks if no autorelease pool here 2013-03-15
        NSFileHandle *pdfFileHandle = [aNotification object];
        NSData *readData = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
        
        if ([readData length] == 0) { // FileHandle was closed
            return;
        }
        
        int infoDictLength = [self readBlockLength:readData atIndex:0];
        NSMutableData *infoDictData = [NSMutableData dataWithCapacity:infoDictLength];
        unsigned infoDictDataOffset = BlockLengthSize;
        [infoDictData appendData:[readData subdataWithRange:NSMakeRange(infoDictDataOffset, MIN([readData length]-infoDictDataOffset, infoDictLength))]];

        if ([infoDictData length] < infoDictLength) {
             [infoDictData appendData:[pdfFileHandle readDataOfLength:infoDictLength - [infoDictData length]]];
        }
        NSError *error;
        NSMutableDictionary *infoDict = [NSPropertyListSerialization propertyListWithData:infoDictData options:NSPropertyListMutableContainers format:NULL error:&error];

        
        int pdfLength = [self readBlockLength:readData atIndex:infoDictLength + BlockLengthSize];
        NSMutableData *pdfData = [NSMutableData dataWithCapacity:pdfLength];
        unsigned pdfDataOffset = infoDictLength + BlockLengthSize + BlockLengthSize;
        if ([readData length] >= pdfDataOffset) {
            [pdfData appendData:[readData subdataWithRange:NSMakeRange(pdfDataOffset, MIN([readData length]-pdfDataOffset, pdfLength))]];
        }
        if ([pdfData length] < pdfLength) {
            [pdfData appendData:[pdfFileHandle readDataOfLength:pdfLength - [pdfData length]]];
        }
        
        [pdfFileHandle readInBackgroundAndNotify];
        
        NSArray *receivedMessages = [messages copy];
        [messages removeAllObjects];
        
        if (_completionBlock != nil) {
            RendererCompletionBlock completionBlock = _completionBlock;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, NULL), ^{
                completionBlock(pdfData, infoDict, receivedMessages);
            });
            _completionBlock = nil;
        }
        [_parentPool makeRendererAvailable:self];
    }
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if ([_rendererTask isRunning]) {
        [_rendererTask terminate];
    }
}

@end
