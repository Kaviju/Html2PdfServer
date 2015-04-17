//
//  PagedWebView.h
//  html2pdf
//
//  Created by Samuel Pelletier on 07-03-01.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "WebHTMLView.h"

#define DEFAULT_VIEW_WIDTH 499

@protocol PagedWebViewDelegate

- (void)logMessage:(NSString*)aMessage;
- (void)fetchDone;
- (void)printingDone;

@end

@interface PagedWebView : NSView
{
	WebView *pageView;
	
	BOOL isPrinting;
    BOOL mainFrameLoaded;
	BOOL hasHeader;
	int htmlWidth;
	int htmlHeight;
	int contentHeight;
	int scrollFrameOffset;
    CGFloat scaleFactor;
    
    NSRange printPageRange;
    int noPage;
	
	NSRect documentFrame;
		
	NSString *pdfPath;
	NSMutableArray *pagesRects;
    NSMutableSet *ressourcesLoading;
}
@property(assign)NSObject<PagedWebViewDelegate>* delegate;

- (id)initWithFrame:(NSRect)frameRect hostWindow:(NSWindow *)window;

- (void)startPrintingIfLoadCompleted;
- (void)printPages:(NSPrintInfo *)printInfo;

- (void)saveRequest:(NSURLRequest *)request toPath:(NSString*)path;

- (void)releaseResources;

@end

