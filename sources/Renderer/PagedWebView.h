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

@interface PagedWebView : NSView <WebFrameLoadDelegate, WebResourceLoadDelegate>
{
	WebView *pageView;
	
	BOOL isPrinting;
    BOOL startPrintingManually;
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
		
    NSURLRequest *_request;
	NSString *pdfPath;
	NSMutableArray *pagesRects;
    NSMutableSet *ressourcesLoading;
}
@property(assign)NSObject<PagedWebViewDelegate>* delegate;

- (id)initWithFrame:(NSRect)frameRect hostWindow:(NSWindow *)window;

- (void)startPrintingIfLoadCompleted;
- (void)printPages:(NSPrintInfo *)printInfo;

- (void)saveRequest:(NSURLRequest *)request toPath:(NSString*)path;
- (void)saveHtmlSource:(NSString *)htmlSource toPath:(NSString*)path;

- (void)releaseResources;

@end

