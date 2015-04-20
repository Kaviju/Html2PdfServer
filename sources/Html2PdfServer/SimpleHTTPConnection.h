//
//  SimpleHTTPConnection.h
//  SimpleCocoaHTTPServer
//
//  Created by Jürgen Schweizer on 13.09.06.
//  Copyright 2006 Cultured Code.
//  License: Creative Commons Attribution 2.5 License
//           http://creativecommons.org/licenses/by/2.5/
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "PagedWebView.h"
@class SimpleHTTPServer;

@interface SimpleHTTPConnection : NSObject
{
    NSFileHandle *fileHandle;

	NSURL *url;
	NSMutableData *requestMessage;
	
    NSUInteger currentPageNumber;
    NSMutableArray *lines;
    NSMutableArray *infoDicts;
    
    NSTimeInterval beginTime;
    NSTimeInterval beginPrint;
    NSTimeInterval endPrint;
}

@property SimpleHTTPServer *server;
@property NSString *address;  // client IP address
@property NSMutableArray *messages;
@property PDFDocument *pdfDocument;


- (id)initWithFileHandle:(NSFileHandle *)fh server:(SimpleHTTPServer *)aServer;

- (void)readRequest;
- (void)processRequest;

@end
