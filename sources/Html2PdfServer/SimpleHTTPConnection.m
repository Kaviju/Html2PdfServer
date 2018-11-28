//
//  Based on code SimpleHTTPConnection.m
//  SimpleCocoaHTTPServer
//
//  Created by Jürgen Schweizer on 13.09.06.
//  Copyright 2006 Cultured Code.
//  License: Creative Commons Attribution 2.5 License
//           http://creativecommons.org/licenses/by/2.5/
//

#import "SimpleHTTPConnection.h"
#import "SimpleHTTPServer.h"
#import "RendererPool.h"
#import "Renderer.h"

#import <netinet/in.h>      // for sockaddr_in
#import <arpa/inet.h>       // for inet_ntoa
#include <dispatch/dispatch.h>

@implementation SimpleHTTPConnection
{
    NSMutableDictionary *pdfOptions;
}

- (id)initWithFileHandle:(NSFileHandle *)fh server:(SimpleHTTPServer *)aServer
{
    if( self = [super init] )
	{
        fileHandle = fh;
        self.server = aServer;
        currentPageNumber = 1;
        _messages = [NSMutableArray new];
        infoDicts = [NSMutableArray new];
        pdfOptions = [NSMutableDictionary dictionary];
        
        // Get IP address of remote client
        CFSocketRef socket;
        socket = CFSocketCreateWithNative(kCFAllocatorDefault,
                                          [fileHandle fileDescriptor],
                                          kCFSocketNoCallBack, NULL, NULL);
        CFDataRef addrData = CFSocketCopyPeerAddress(socket);
        CFRelease(socket);
        if( addrData )
		{
            struct sockaddr_in *sock = (struct sockaddr_in *)CFDataGetBytePtr(addrData);
            char *naddr = inet_ntoa(sock->sin_addr);
            self.address = [NSString stringWithCString:naddr encoding:NSISOLatin1StringEncoding];
            CFRelease(addrData);
        }
		else
		{
            self.address = @"NULL";
        }
    }
    return self;
}

#pragma mark Request decoding

- (void)processRequest
{
    requestTime = [NSCalendarDate timeIntervalSinceReferenceDate];
	[self readRequest];
	if ([[url path] isEqual:@"/favicon.ico"]) return;
    @try
	{
        NSDictionary *queryDict = [self decodeQueryString:[url query]];
        
        if ([queryDict count] > 0 ) {
            [self processSimpleRequest:queryDict];
        }
        else {
            [self processExtendesRequest];
        }
        
    }
    @catch (NSException *exception)
	{
        NSLog(@"Error while sending response (%@): %@", [url query], [exception  reason]);
        [fileHandle closeFile];
        fileHandle = nil;
    }
}

- (void)processSimpleRequest:(NSDictionary *)queryDict
{
    NSString *sourceUrl = [queryDict objectForKey:@"url"];
    
    NSURL *parsedUrl = [NSURL URLWithString:sourceUrl];
    
    if (parsedUrl == nil || [sourceUrl length] < 10 ){ // we assume an short (<20 chars) url is bad.
        [NSException raise:@"Malformed url" format:@"Cannot parse read url: %@", sourceUrl];
    }
    
    [self logMessage:[NSString stringWithFormat:@"sourceUrl [%@] ", sourceUrl]];
    lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"renderPdfAtUrl:%@", sourceUrl]];
    
    if ([[queryDict objectForKey:@"withRendererInfos"] isEqualToString:@"1"]) {
        [lines addObject:@"addRendererInfos"];
    }
    
    [self processNextLine];
}


- (void)processExtendesRequest
{
    NSString *requestScript = [[NSString alloc] initWithData:requestMessage encoding:NSUTF8StringEncoding];
    if ([requestScript rangeOfString:@"%3A"].location != NSNotFound) {
        requestScript = [requestScript stringByRemovingPercentEncoding];
    }

    lines = [[requestScript componentsSeparatedByString:@"\n"] mutableCopy];
    [self processNextLine];
}

- (void)readRequest
{
    CFHTTPMessageRef message = NULL;
    @try {
        message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE);
        requestMessage = [NSMutableData data];
        do
        {
            NSData *data = [fileHandle availableData];
            if ( [data length] == 0 )
            {
                @throw ([NSException exceptionWithName:@"Connection closed" reason:@"Remote closed connection" userInfo:nil]);
            }
            CFHTTPMessageAppendBytes(message, [data bytes], [data length]);
        }
        while ( !CFHTTPMessageIsHeaderComplete(message));
        url = CFBridgingRelease(CFHTTPMessageCopyRequestURL(message));
        
        NSString *contentLength = CFBridgingRelease(CFHTTPMessageCopyHeaderFieldValue(message, CFSTR("Content-Length")));
        NSInteger expectedMessageLength = [contentLength integerValue];
        
        [requestMessage appendData:CFBridgingRelease(CFHTTPMessageCopyBody(message))];
        // Read remaining post data if required
        while ([requestMessage length] < expectedMessageLength) {
            NSData *data = [fileHandle availableData];
            if ( [data length] == 0 )
            {
                @throw ([NSException exceptionWithName:@"Connection closed" reason:@"Remote closed connection" userInfo:nil]);
            }
            [requestMessage appendData:data];
        }
    }
    @catch (NSException *exception) {
        [self sendBasicHttpResponse];
    }
    @finally {
        if( message ) CFRelease(message);

    }

}

- (NSMutableDictionary *)decodeQueryString:(NSString *)queryString
{
    NSArray *queryEntries = [queryString componentsSeparatedByString:@"&"];
    
    NSMutableDictionary *returnDictionary = [NSMutableDictionary dictionary];
    
    for (NSString *queryEntry in queryEntries) {
        NSArray *queryEntryArray = [queryEntry componentsSeparatedByString:@"="];
        if ([queryEntryArray count] == 2) {
            NSString *value = [queryEntryArray objectAtIndex:1];
            value = [value stringByReplacingPercentEscapesUsingEncoding:NSISOLatin1StringEncoding];
            [returnDictionary setObject:value forKey:[queryEntryArray objectAtIndex:0]];
        }
        else {
            [returnDictionary setObject:@"1" forKey:[queryEntryArray objectAtIndex:0]];
        }
    }
    return returnDictionary;
}

#pragma mark Request commands processing

- (void)processNextLine
{
    BOOL canContinue = YES;
    while (canContinue) {
        NSString *command = [lines firstObject];
        if (command == nil) {
            [self sendBasicHttpResponse];
            return;
        }
        NSString *paramString;
        [lines removeObjectAtIndex:0];
        
        NSRange endCommandPosition = [command rangeOfString:@":"];
        if (endCommandPosition.location != NSNotFound) {
            paramString = [command substringFromIndex:endCommandPosition.location+1];
            command = [command substringToIndex:endCommandPosition.location];
        }
        
        if ([command isEqualToString:@"setCurrentPageNumber"]) {
            canContinue = [self setCurrentPageNumber:[paramString integerValue]];
        }
        if ([command isEqualToString:@"ensureEvenPageCount"]) {
            canContinue = [self ensureEvenPageCount];
        }
        if ([command isEqualToString:@"insertBlankPage"]) {
            canContinue = [self insertBlankPage];
        }
        else if ([command isEqualToString:@"renderPdfAtUrl"]) {
            canContinue = [self renderPdfAtUrl:paramString];
        }
        else if ([command isEqualToString:@"appendPdfAtUrl"]) {
            canContinue = [self appendPdfAtUrl:paramString];
        }
        else if ([command isEqualToString:@"setOutputFilter"]) {
            canContinue = [self setOutputFilter:paramString];
        }
        else if ([command isEqualToString:@"addRendererInfos"]) {
            canContinue = [self addRendererInfos];
        }
        else if ([command isEqualToString:@"sendBasicResponse"]) {
            canContinue = [self sendBasicHttpResponse];
        }
        else if ([command isEqualToString:@"sendExtendedResponse"]) {
            canContinue = [self sendExtendedHttpResponse];
        }
    }
}

- (BOOL)setCurrentPageNumber:(NSUInteger)pageNumber
{
    currentPageNumber = pageNumber;
    return YES;
}

- (BOOL)ensureEvenPageCount
{
    if ([self.pdfDocument pageCount] % 2 == 1) {
        [self insertBlankPage];
    }
    return YES;
}

- (BOOL)insertBlankPage
{
    PDFPage *blankPage = [[PDFPage alloc] init];
    [self.pdfDocument insertPage:blankPage atIndex:[self.pdfDocument pageCount]];
    currentPageNumber++;
    return YES;
}

- (BOOL)renderPdfAtUrl:(NSString *)sourceUrl
{
    Renderer *renderer = [[RendererPool sharedPool] renderer];
    
    [renderer processRequest:sourceUrl firstPageNumber:currentPageNumber completionBlock:^(NSData *pdfData, NSMutableDictionary *infoDict, NSArray *messages) {
        SimpleHTTPConnection *blocSelf = self;  //Keep a copy of the pointer because self is sometime corrupted after -sendHttpResponse for an unknow reason.
        [blocSelf.messages addObjectsFromArray:messages];
        [blocSelf processRenderedPdf:pdfData withInfos:infoDict];
    }];
    return NO;
}

- (BOOL)appendPdfAtUrl:(NSString *)sourceUrl
{
    [self.messages addObject:[NSString stringWithFormat:@"appending pdf at Url: %@", sourceUrl]];

    NSURL *pdfSourceUrl = [NSURL URLWithString:sourceUrl];
    NSError *error;
    NSData *pdfData = [NSData dataWithContentsOfURL:pdfSourceUrl options:nil error:&error];
    if (pdfData == nil) {
        [self.messages addObject:[NSString stringWithFormat:@"Url failed with error: %@", error]];
    }
    else {
        [self appendPdf:pdfData];
    }
    return YES;
}

- (BOOL)addRendererInfos
{
    Renderer *renderer = [[RendererPool sharedPool] renderer];
    
    NSString *infosHtml = [self createRendererInfosHtml];
    [renderer processHtmlSource:infosHtml firstPageNumber:currentPageNumber completionBlock:^(NSData *pdfData, NSMutableDictionary *infoDict, NSArray *messages) {
        SimpleHTTPConnection *blocSelf = self;  //Keep a copy of the pointer because self is sometime corrupted after -sendHttpResponse for an unknow reason.
        [blocSelf.messages addObjectsFromArray:messages];
        [blocSelf processRenderedPdf:pdfData withInfos:infoDict];
    }];
    return NO;
}

- (void)processRenderedPdf:(NSData *)pdfData withInfos:(NSMutableDictionary *)infoDict
{
    [infoDicts addObject:infoDict];
    [self appendPdf:pdfData];
    [self processNextLine];
}

- (void)appendPdf:(NSData *)pdfData
{
    if (pdfData != nil) {
        PDFDocument *newDocument = [[PDFDocument alloc] initWithData:pdfData];
        if (self.pdfDocument == nil) {
            self.pdfDocument = newDocument;
        }
        else {
            for (NSUInteger i = 0; i < [newDocument pageCount]; i++) {
                PDFPage *page = [newDocument pageAtIndex:i];
                [self.pdfDocument insertPage:page atIndex:[self.pdfDocument pageCount]];
            }
        }
        [self setCurrentPageNumber:currentPageNumber + [newDocument pageCount]];
    }
}

- (BOOL)setOutputFilter:(NSString *)filterName
{
    NSURL *filterUrl = [[NSBundle mainBundle] URLForResource:[@"" stringByAppendingString:filterName] withExtension:@"qfilter"];
    filterName = [filterName stringByAppendingString:@".qfilter"];
    if ([filterUrl checkResourceIsReachableAndReturnError:NULL] == NO) {
        filterUrl = [NSURL fileURLWithPath:[@"/Library/Filters/" stringByAppendingString:filterName]];
    }
    if ([filterUrl checkResourceIsReachableAndReturnError:NULL] == NO) {
        filterUrl = [NSURL fileURLWithPath:[@"/System/Library/Filters/" stringByAppendingString:filterName]];
    }
    if ([filterUrl checkResourceIsReachableAndReturnError:NULL]) {
        QuartzFilter *quartzFilter = [QuartzFilter quartzFilterWithURL:filterUrl];
        [pdfOptions setObject:quartzFilter forKey:@"QuartzFilter"];
        [self logMessage:[NSString stringWithFormat:@"Quatz output filter %@ added.", filterUrl]];
    }
    return YES;
}

#pragma mark Send response and log

- (BOOL)sendBasicHttpResponse
{
    CFHTTPMessageRef msg = NULL;
    CFDataRef msgData = NULL;
    NSData *pdfData = [self.pdfDocument dataRepresentationWithOptions:pdfOptions];
    
    NSLog(@"printing done, %ld messages, pdf size: %ld", [_messages count], [pdfData length]);
    
    @try
    {
        msg = [self newHttpMessage];
        
        NSString *length = [NSString stringWithFormat:@"%ld", (unsigned long)[pdfData length]];
        CFHTTPMessageSetHeaderFieldValue(msg,
                                         (CFStringRef)@"Content-Length",
                                         (__bridge CFStringRef)length);
        CFHTTPMessageSetHeaderFieldValue(msg,
                                         (CFStringRef)@"Connection",
                                        (CFStringRef)@"close");

        
        msgData = CFHTTPMessageCopySerializedMessage(msg);
        [fileHandle writeData:(__bridge NSData *)msgData];
        [fileHandle writeData:pdfData];
        NSLog(@"messages: %@", self.messages);
    }
    @catch (NSException *exception)
    {
        NSLog(@"Error while sending response (%@): %@", url, [exception  reason]);
    }
    @finally {
        [fileHandle closeFile];
        [self.server forgetConnection:self];
    }
    if (msgData) CFRelease(msgData);
    if (msg) CFRelease(msg);
    return NO;
}

- (BOOL)sendExtendedHttpResponse
{
    CFHTTPMessageRef msg = NULL;
    CFDataRef msgData = NULL;
    NSData *pdfData = [self.pdfDocument dataRepresentationWithOptions:pdfOptions];
    NSLog(@"printing done, %ld messages, pdf size: %ld", [_messages count], [pdfData length]);
    
    @try
    {
        msg = [self newHttpMessage];
        
        msgData = CFHTTPMessageCopySerializedMessage(msg);
        [fileHandle writeData:(__bridge NSData *)msgData];
        
        NSString *pdfDataLength = [NSString stringWithFormat:@"%11ld\n", [pdfData length]];
        [fileHandle writeData:[pdfDataLength dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle writeData:pdfData];
        
        NSMutableDictionary *responseDict;
        NSError *error;
        NSData *infoDictData = [NSJSONSerialization dataWithJSONObject:responseDict options:NSJSONWritingPrettyPrinted error:&error];

        NSString *infoDictDataLength = [NSString stringWithFormat:@"%11ld\n", [infoDictData length]];
        [fileHandle writeData:[infoDictDataLength dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle writeData:infoDictData];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Error while sending response (%@): %@", url, [exception  reason]);
    }
    @finally {
        [fileHandle closeFile];
        [self.server forgetConnection:self];
    }
    if (msgData) CFRelease(msgData);
    if (msg) CFRelease(msg);
    return NO;
}

- (CFHTTPMessageRef)newHttpMessage
{
	CFHTTPMessageRef msg = NULL;
    msg = CFHTTPMessageCreateResponse(kCFAllocatorDefault,
                                      200,  // 200 = 'OK'
                                      NULL, // Use standard status description 
                                      kCFHTTPVersion1_1);
    
    CFHTTPMessageSetHeaderFieldValue(msg, (CFStringRef)@"Content-Type", (CFStringRef)@"application/pdf");
    CFHTTPMessageSetHeaderFieldValue(msg, (CFStringRef)@"Expires", (CFStringRef)@"Fri, 1 Jan 2100 00:00:00 GMT");
    CFHTTPMessageSetHeaderFieldValue(msg, (CFStringRef)@"Last-Modified", (CFStringRef)@"Mon, 1 Jan 2007 00:00:00 GMT");
    CFHTTPMessageSetHeaderFieldValue(msg, (CFStringRef)@"ETag", (__bridge CFStringRef)[url path]);
    CFHTTPMessageSetHeaderFieldValue(msg, (CFStringRef)@"Cache-Control", (CFStringRef)@"public");
    return msg;
}

- (NSString *)createRendererInfosHtml
{
    NSMutableString *html = [NSMutableString new];
    [html appendString:@"<!DOCTYPE html>\n<html>\n\n<head>\n"];
    [html appendString:@"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"/>\n"];
    [html appendString:@"</head>\n<body width=\"100%\">\n"];
    NSTimeInterval totalTime = [NSCalendarDate timeIntervalSinceReferenceDate] - requestTime;
    [html appendFormat:@"<b>Total time:</b> %f seconds<br/>\n", totalTime];
    if (self.pdfDocument != nil) {
        [html appendFormat:@"<b>Total number of pages:</b> %lu<br/>\n", (unsigned long)[self.pdfDocument pageCount]];
        [html appendFormat:@"<b>PDF size:</b> %lu<br/>\n", [[self.pdfDocument dataRepresentation] length]];
    }
    
    [html appendString:@"<h3>Infos</h3>\n<pre>"];
    [html appendString:[infoDicts description]];
    [html appendString:@"</pre>"];
    [html appendString:@"<h3>Messages</h3>\n<pre>"];
    [html appendString:[_messages description]];
    [html appendString:@"</pre>"];
    
    [html appendString:@"</body>\n</html>\n"];
    return html;
}

- (void)logMessage:(NSString*)aMessage
{
	[_messages addObject:aMessage];
}


- (void)dealloc
{
    [fileHandle closeFile];
}

@end
