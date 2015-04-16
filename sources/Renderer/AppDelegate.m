//
//  AppDelegate.m
//  Renderer
//
//  Created by Samuel Pelletier on 2013-01-19.
//

#import "AppDelegate.h"
#import "PdfPrintWindow.h"
#import "PagedWebView.h"

@implementation AppDelegate

// With Maverick and/or latest WebKit when using the header mode, the window size needs to be large enough to completly include the inner iFrame.
// If windows size is too small, the iFrame content is croped in the PDF. Adjust these constants for the maximum template document size allowed.
// The units is in rendered pixels by the WebView.
float MaxTemplateWidthInWebPixels = 2000;
float MaxTemplateHeightInWebPixels = 2000;

- (instancetype)init
{
    self = [super init];
    if (self) {
        infoDict = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
    
    NSFileHandle *stdIN = [NSFileHandle fileHandleWithStandardInput];
    [stdIN readInBackgroundAndNotify];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(readRequest:) name:NSFileHandleReadCompletionNotification object:stdIN];
}

- (void)readRequest:(NSNotification *)aNotification
{
    @autoreleasepool {
        [infoDict removeAllObjects];
        beginTime = [NSCalendarDate timeIntervalSinceReferenceDate];
        endFetch = endPrint = beginTime;
        NSData *readData = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
        
        NSError *error;
        NSMutableDictionary *paramsDict = [NSPropertyListSerialization propertyListWithData:readData options:NSPropertyListMutableContainers format:NULL error:&error];
        if (error != nil) {
            [infoDict setObject:error forKey:@"error"];
            [self sendResponse:nil];
        }
        else {
            NSString *requestURL = [paramsDict objectForKey:@"url"];
            requestURL = [requestURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            NSString *guid = [[[NSProcessInfo processInfo] globallyUniqueString] stringByAppendingPathExtension:@"pdf"];
            pdfPath = [NSTemporaryDirectory() stringByAppendingPathComponent:guid];
            
            [infoDict setObject:requestURL forKey:@"documentSourceURL"];
            [self logMessage:[NSString stringWithFormat:@"sourceUrl [%@] ", requestURL]];
            [self logMessage:[NSString stringWithFormat:@"pdfPath [%@] ", pdfPath]];
            
            window = [[PdfPrintWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000, MaxTemplateWidthInWebPixels, MaxTemplateHeightInWebPixels)
                                                       styleMask:NSTitledWindowMask|NSResizableWindowMask|NSClosableWindowMask
                                                         backing:NSBackingStoreBuffered defer:NO];
            [window setReleasedWhenClosed:NO]; //We have a reference, this break ARC.
            window.logFileHandle = [NSFileHandle fileHandleWithStandardError];
            window.infoDict = infoDict;
            window.firstPageNumber = [[paramsDict objectForKey:@"firstPageNumber"] intValue];
            
            [window setBackgroundColor:[NSColor blueColor]];
            window.title = [NSString stringWithFormat:@"PDF %@", [NSCalendarDate date]];
            
            PagedWebView *mainView = [[PagedWebView alloc] initWithFrame:NSMakeRect(0, 0, DEFAULT_VIEW_WIDTH, 200) hostWindow:window];
            [mainView setDelegate:self];
            [window setContentView:mainView];
            
            NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:requestURL]
                                                        cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                    timeoutInterval:10.0];
            [mainView saveRequest:urlRequest toPath:pdfPath];
        }
        [[NSFileHandle fileHandleWithStandardInput] readInBackgroundAndNotify];
    }
}

- (void)fetchDone
{
    endFetch = [NSCalendarDate timeIntervalSinceReferenceDate];
    [infoDict setObject:[NSNumber numberWithDouble:(endFetch-beginTime)] forKey:@"fetchDuration"];
    [self logMessage:[NSString stringWithFormat:@"Fetch done in %f s.", (endFetch-beginTime)]];
}

- (void)releasesRessources
{
    [[NSFileManager defaultManager] removeItemAtPath:pdfPath error:NULL];
    [window close];
	window = nil;
	pdfPath = nil;
}

- (void)sendResponse:(NSData *)pdfData
{
    NSFileHandle *stdOUT = [NSFileHandle fileHandleWithStandardOutput];
    
    NSError *error;
    NSData *infoDictData = [NSPropertyListSerialization dataWithPropertyList:infoDict
                                                                      format:NSPropertyListXMLFormat_v1_0
                                                                     options:NSPropertyListMutableContainers error:&error];
    
    NSString *infoDictDataLength = [NSString stringWithFormat:@"%11ld\n", [infoDictData length]];
    [stdOUT writeData:[infoDictDataLength dataUsingEncoding:NSUTF8StringEncoding]];
    [stdOUT writeData:infoDictData];
    
    NSString *pdfDataLength = [NSString stringWithFormat:@"%11ld\n", [pdfData length]];
    [stdOUT writeData:[pdfDataLength dataUsingEncoding:NSUTF8StringEncoding]];
    if (pdfData != nil) {
        [stdOUT writeData:pdfData];
    }
}

- (void)printingDone
{
    @try {
        endPrint = [NSCalendarDate timeIntervalSinceReferenceDate];
        [infoDict setObject:[NSNumber numberWithDouble:(endPrint-endFetch)] forKey:@"printDuration"];
        [infoDict setObject:[NSNumber numberWithDouble:(endPrint-beginTime)] forKey:@"totalDuration"];
        [self logMessage:[NSString stringWithFormat:@"Print done in %f s.", (endPrint-endFetch)]];
        [self logMessage:[NSString stringWithFormat:@"Total time %f s.", (endPrint-beginTime)]];
        
        NSData *pdfData = [NSData dataWithContentsOfFile:pdfPath];
        [infoDict setObject:[NSNumber numberWithInteger:[pdfData length]] forKey:@"pdfFileSize"];
        [self logMessage:[NSString stringWithFormat:@"pdf size: %ld path: %@", [pdfData length], pdfPath]];

        [self sendResponse:pdfData];
    }
    @catch (NSException *exception) {
        NSLog(@"Error while printingDone %@", [exception  reason]);
    }
    @finally {
        [self releasesRessources];
    }
}

- (void)logMessage:(NSString*)aMessage
{
    NSFileHandle *stdERR = [NSFileHandle fileHandleWithStandardError];
    aMessage = [NSString stringWithFormat:@"%@: %@", [NSCalendarDate date], aMessage];
	[stdERR writeData:[aMessage dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
