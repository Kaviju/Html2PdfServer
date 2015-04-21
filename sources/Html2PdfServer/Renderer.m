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
        _numberOfRequests = 0;
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
                    _completionBlock(nil, [NSMutableDictionary new], messages);
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

- (void)processRequest:(NSString *)requestUrl firstPageNumber:(NSUInteger)firstPageNumber completionBlock:(RendererCompletionBlock)aBlock
{
    _numberOfRequests++;
    self.completionBlock = aBlock;
    messages = [NSMutableArray new];

    NSDictionary *paramDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedLong:firstPageNumber], @"firstPageNumber",
                               requestUrl, @"url",
                               nil];
    [self sendRequest:paramDict completionBlock:aBlock];
}

- (void)processHtmlSource:(NSString *)html firstPageNumber:(NSUInteger)firstPageNumber completionBlock:(RendererCompletionBlock)aBlock
{
    _numberOfRequests++;
    self.completionBlock = aBlock;
    messages = [NSMutableArray new];
    
    NSDictionary *paramDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedLong:firstPageNumber], @"firstPageNumber",
                               html, @"htmlSource",
                               nil];
    [self sendRequest:paramDict completionBlock:aBlock];
}

- (void)sendRequest:(NSDictionary *)paramDict completionBlock:(RendererCompletionBlock)aBlock
{
    NSError *error;
    NSData *paramDictData = [NSPropertyListSerialization dataWithPropertyList:paramDict
                                                                       format:NSPropertyListXMLFormat_v1_0
                                                                      options:NSPropertyListMutableContainers error:&error];
    
    NSFileHandle *requestFH = [_requestPipe fileHandleForWriting];
    NSString *paramDictDataLength = [NSString stringWithFormat:@"%11ld\n", [paramDictData length]];
    [requestFH writeData:[paramDictDataLength dataUsingEncoding:NSUTF8StringEncoding]];
    [requestFH writeData:paramDictData];
}

- (void)readMessage:(NSNotification *)aNotification
{
    @autoreleasepool { // Leaks if no autorelease pool here 2013-03-15
    NSData *messageData = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    if ([messageData length] == 0) { // FileHandle was closed
        return;
    }
    NSString *stringReceived = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    NSArray *receivedMessages = [stringReceived componentsSeparatedByString:@"\n"];
    for (NSString *message in receivedMessages) {
        if ([message length] > 0) {
            [messages addObject:message];
        }
    }
    
    NSFileHandle *fh = [aNotification object];
    [fh readInBackgroundAndNotify];
    }
}

- (int)readBlockLength:(NSData *)blockLengthData
{
    NSString *blockLengthAsString = [[NSString alloc] initWithData:blockLengthData encoding:NSUTF8StringEncoding];
    blockLengthAsString = [blockLengthAsString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    int pdfLength = [blockLengthAsString intValue];
    return pdfLength;
}

- (void)readPdf:(NSNotification *)aNotification
{
    @autoreleasepool { // Leaks if no autorelease pool here 2013-03-15
        NSFileHandle *pdfFileHandle = [aNotification object];
        NSData *readData = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
        NSUInteger readDataCurrentOffset = 0;
        
        if ([readData length] == 0) { // FileHandle was closed
            return;
        }
        
        // Read the info dict
        NSData *infoDictLengthData = [readData subdataWithRange:NSMakeRange(0, BlockLengthSize)];
        int infoDictLength = [self readBlockLength:infoDictLengthData];
        readDataCurrentOffset += BlockLengthSize;
        
        NSMutableData *infoDictData = [NSMutableData dataWithCapacity:infoDictLength];
        
        NSUInteger infoDictDataLengthFromInitialData = MIN([readData length]-readDataCurrentOffset, infoDictLength);
        [infoDictData appendData:[readData subdataWithRange:NSMakeRange(readDataCurrentOffset, infoDictDataLengthFromInitialData)]];
        readDataCurrentOffset += infoDictDataLengthFromInitialData;

        if ([infoDictData length] < infoDictLength) {
             [infoDictData appendData:[pdfFileHandle readDataOfLength:infoDictLength - [infoDictData length]]];
        }
        NSError *error;
        NSMutableDictionary *infoDict = [NSPropertyListSerialization propertyListWithData:infoDictData options:NSPropertyListMutableContainers format:NULL error:&error];

        // Now the PDF
        NSMutableData *pdfLengthData = [NSMutableData dataWithCapacity:BlockLengthSize];
        if ([readData length] > readDataCurrentOffset) {
            NSUInteger pdfDataBlockLengthFromInitialData = MIN([readData length]-readDataCurrentOffset, BlockLengthSize);
            [pdfLengthData appendData:[readData subdataWithRange:NSMakeRange(readDataCurrentOffset, pdfDataBlockLengthFromInitialData)]];
            readDataCurrentOffset += pdfDataBlockLengthFromInitialData;
        }
        if ([pdfLengthData length] < BlockLengthSize) {
            [pdfLengthData appendData:[pdfFileHandle readDataOfLength:BlockLengthSize - [pdfLengthData length]]];
        }
        
        int pdfLength = [self readBlockLength:pdfLengthData];
        NSMutableData *pdfData = [NSMutableData dataWithCapacity:pdfLength];
        if ([readData length] >= readDataCurrentOffset) {
            [pdfData appendData:[readData subdataWithRange:NSMakeRange(readDataCurrentOffset, MIN([readData length]-readDataCurrentOffset, pdfLength))]];
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


- (void)stopTask
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if ([_rendererTask isRunning]) {
        [_rendererTask terminate];
    }
}

@end
