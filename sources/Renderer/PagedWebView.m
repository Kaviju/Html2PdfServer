//
//  PagedWebView.m
//  html2pdf
//
//  Created by Samuel Pelletier on 07-03-01.
//

#import "PagedWebView.h"
#import "PdfPrintWindow.h"

@implementation PagedWebView

- (id)initWithFrame:(NSRect)frame hostWindow:(NSWindow *)window
{
    self = [super initWithFrame:frame];
    if (self)
	{
        ressourcesLoading = [NSMutableSet set];
        mainFrameLoaded = NO;
        isPrinting = NO;
        pageView = [[WebView alloc] initWithFrame:frame frameName:nil groupName:nil];
        [pageView setHostWindow:window];
        [pageView setShouldUpdateWhileOffscreen:YES];
        
        
        [self addSubview:pageView];
        [pageView setFrameLoadDelegate:self];
        [pageView setResourceLoadDelegate:self];
        
        WebPreferences* prefs = [WebPreferences standardPreferences];
        [prefs setShouldPrintBackgrounds: YES];
        [prefs setAllowsAnimatedImages:NO];
        [prefs setUsesPageCache:NO];
        [prefs setAutosaves:NO];
        [prefs setCacheModel:WebCacheModelDocumentViewer];
        [prefs setJavaScriptCanOpenWindowsAutomatically:NO];
        [pageView setPreferences:prefs];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(loadProgress:) name: WebViewProgressEstimateChangedNotification object: pageView];
        [nc addObserver: self selector:@selector(loadProgress:) name: WebViewProgressStartedNotification object: pageView];
        [nc addObserver: self selector:@selector(loadFinished:) name: WebViewProgressFinishedNotification object: pageView];
    }
    return self;
}

- (void)saveRequest:(NSURLRequest *)request toPath:(NSString*)path
{
	pdfPath = path;
	
	[_delegate logMessage:@"Begin loading."];
	[[pageView mainFrame] loadRequest:request];
}

- (void)print:(id) sender
{
    [self performSelectorOnMainThread:@selector(printPages) withObject:nil waitUntilDone:NO];
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{		
    //NSLog(@"==========didFailProvisionalLoadWithError: %@", error);
	[_delegate logMessage:[NSString stringWithFormat:@"Error didFailProvisionalLoadWithError (%@): %@", [error  localizedDescription], [error  userInfo]]];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    //NSLog(@"==========didFailLoadWithError: %@", error);
	[_delegate logMessage:[NSString stringWithFormat:@"Error didFailLoadWithError (%@): %@", [error  localizedDescription], [error  userInfo]]];
    [[pageView mainFrame] stopLoading];
	[_delegate printingDone];
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource {
//    NSLog(@"==========didFinishLoadingFromDataSource: %@", identifier);
    [ressourcesLoading removeObject:identifier];
    [self startPrintingIfLoadCompleted];
}

- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource {
    //NSLog(@"==========didFailLoadingWithError: %@", identifier);
    [ressourcesLoading removeObject:identifier];
    [self startPrintingIfLoadCompleted];
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
    [ressourcesLoading addObject:identifier];
//    NSLog(@"==========willSendRequest: %@", identifier);
    return request;
}

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource {
    static int resNo = 0;
    NSString *identifier = [NSString stringWithFormat:@"%d:%@", resNo++, [request URL]];
    //NSLog(@"==========identifierForInitialRequest: %@", identifier);
    return identifier;
}


- (void)loadProgress:(NSNotification *)sender
{
	[_delegate logMessage:[NSString stringWithFormat:@"loadProgress: %f", [pageView estimatedProgress]]];
}

- (void)loadFinished:(NSNotification *)sender
{
    mainFrameLoaded = YES;
    [self startPrintingIfLoadCompleted];
}

// Check if the mainframe AND all resources are loaded before printing the HTML.
// Required with the paginated mode that trigger resource loading when the content is moved into the iFrame.
- (void)startPrintingIfLoadCompleted {
    if (mainFrameLoaded && [ressourcesLoading count] == 0) {
        if (isPrinting) {
            [_delegate logMessage:[NSString stringWithFormat:@"startPrinting requested but already printing, do nothing"]];
            return;
        }
        PdfPrintWindow *printWindow = (PdfPrintWindow *)self.window;
        isPrinting = YES;
        [_delegate fetchDone];
        
        [pageView setMediaStyle:@"print"];  // Switch the document CSS media to print
        
        NSPrintInfo *printInfo = [self createPrintInfo];
    	        
        printWindow.documentView = (WebHTMLView *)[[[pageView mainFrame] frameView] documentView];
        documentFrame = [printWindow.documentView frame];
        if (documentFrame.size.width == DEFAULT_VIEW_WIDTH) {
            documentFrame.size.width = [self computeOptimalViewWidthForPaper:printInfo];
        }

        // Set view frame to display all contents so elementAtPoint will works and we will be able to find the pagebreaks.
        [self setFrame:documentFrame];
        [pageView setFrame:documentFrame];
        
        [self performSelectorOnMainThread:@selector(printPages:) withObject:printInfo waitUntilDone:NO];
    }
}

- (CGFloat)computeOptimalViewWidthForPaper:(NSPrintInfo *)printInfo
{
    CGFloat width;
    if ([printInfo orientation] == NSPortraitOrientation) {
        width = [printInfo paperSize].width;
    }
    else {
        width = [printInfo paperSize].height;
    }
    CGFloat margins = [printInfo leftMargin] + [printInfo rightMargin];
    width -= margins;
    
    return floor(width * 1.333); // CSS assume 96 dpi, Cocoa is 72 dpi, we adjust for a pt in css to appears as a pt when printed.
}

- (NSPrintInfo *)createPrintInfo
{
    PdfPrintWindow *printWindow = (PdfPrintWindow *)self.window;
    WebFrame *mainFrame = [pageView mainFrame];
	printWindow.pageDocument = (DOMHTMLDocument*)[mainFrame DOMDocument];
	DOMNodeList *elems = [printWindow.pageDocument getElementsByTagName:@"body"];
    DOMElement *bodyElem = (DOMElement*)[elems item:0];

	NSMutableDictionary *printInfoDict = [[NSPrintInfo sharedPrintInfo] dictionary];
	[printInfoDict setObject:[NSURL fileURLWithPath:pdfPath] forKey:NSPrintJobSavingURL];
    
	NSPrintInfo *printInfo = [[NSPrintInfo alloc] initWithDictionary:(NSMutableDictionary*)printInfoDict]; 
	
    NSString *marginOffsetForEvenPages = [bodyElem getAttribute:@"marginOffsetForEvenPages"];
    if ([marginOffsetForEvenPages length] > 0) {
        printWindow.marginOffsetForEvenPages = [marginOffsetForEvenPages floatValue];
    }
    [printWindow setInfo:[NSNumber numberWithFloat:printWindow.marginOffsetForEvenPages] forKey:@"marginOffsetForEvenPages"];

    
    NSString *paperSizeName = [bodyElem getAttribute:@"customPaperSize"];
	if ([paperSizeName length] > 0) {
		
	}
	else {
        [printInfo setPaperSize:NSMakeSize(612, 792)];
		paperSizeName = [bodyElem getAttribute:@"paperSize"];
		if ([paperSizeName isEqual:@"Leter"])
		{
			[printInfo setPaperSize:NSMakeSize(612, 792)];
		}
		if ([paperSizeName isEqual:@"Legal"])
		{
			[printInfo setPaperSize:NSMakeSize(612, 1008)];
		}
		if ([paperSizeName isEqual:@"Tabloid"])
		{
			[printInfo setPaperSize:NSMakeSize(792, 1224)];
		}
		if ([paperSizeName isEqual:@"A4"])
		{
			[printInfo setPaperSize:NSMakeSize(595.44, 841.68)];
		}
		if ([paperSizeName isEqual:@"A3"])
		{
			[printInfo setPaperSize:NSMakeSize(841.68, 1190.88)];
		}
		
		NSString *paperOrientation = [bodyElem getAttribute:@"paperOrientation"];
		if ([paperOrientation length] == 0 || [paperOrientation isEqual:@"Portrait"])
		{
			[printInfo setOrientation: NSPortraitOrientation];
		}
		else
		{
			[printInfo setOrientation: NSLandscapeOrientation];
		}
	}
	
	NSString *margin;
	margin = [bodyElem getAttribute:@"marginTop"];
	if ([margin length] == 0) margin = @"20";
	[printInfo setTopMargin:[margin floatValue]];
	margin = [bodyElem getAttribute:@"marginLeft"];
	if ([margin length] == 0) margin = @"20";
	[printInfo setLeftMargin:[margin floatValue]];
	margin = [bodyElem getAttribute:@"marginBottom"];
	if ([margin length] == 0) margin = @"20";
	[printInfo setBottomMargin:[margin floatValue]];
	margin = [bodyElem getAttribute:@"marginRight"];
	if ([margin length] == 0) margin = @"20";
	[printInfo setRightMargin:[margin floatValue]];

    [printWindow setInfo:[NSNumber numberWithFloat:[printInfo topMargin]] forKey:@"marginTop"];
    [printWindow setInfo:[NSNumber numberWithFloat:[printInfo leftMargin]] forKey:@"marginLeft"];
    [printWindow setInfo:[NSNumber numberWithFloat:[printInfo bottomMargin]] forKey:@"marginBottom"];
    [printWindow setInfo:[NSNumber numberWithFloat:[printInfo rightMargin]] forKey:@"marginRight"];

	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setHorizontallyCentered: NO];
	[printInfo setVerticallyCentered: NO];
	[printInfo setJobDisposition:NSPrintSaveJob];  // NSPrintPreviewJob to open directly in Preview.app
	
    return printInfo;
}

- (void)printPages:(NSPrintInfo *)printInfo
{
    [pageView display];
    [self display];
    PdfPrintWindow *printWindow = (PdfPrintWindow *)self.window;
    [printWindow logMessage:[NSString stringWithFormat:@"Begin printing."]];
    
    WebFrame *mainFrame = [pageView mainFrame];
    printWindow.pageDocument = (DOMHTMLDocument*)[mainFrame DOMDocument];
    DOMNodeList *elems = [printWindow.pageDocument getElementsByTagName:@"body"];
    DOMElement *bodyElem = (DOMElement*)[elems item:0];
    
    DOMHTMLIFrameElement *contentFrameElement = (DOMHTMLIFrameElement *)[printWindow.pageDocument getElementById:@"contentFrame"];
    // Switch behavior of operation to use the paginated iFrame
    if (contentFrameElement != nil)
    {
        printWindow.hasHeader = YES;
        printWindow.contentDocument = (DOMHTMLDocument *)[contentFrameElement contentDocument];
        if ([[[[contentFrameElement contentFrame] frameView] documentView] frame].size.height == 0)
        {
            [printWindow logMessage:[NSString stringWithFormat:@"Document view is empty"]];
            [_delegate printingDone];
            return;
        }
    }
    else
    {
        printWindow.hasHeader = NO;
    }
    
    NSString *firstPageNumber = [bodyElem getAttribute:@"firstPageNumber"];
    if ([firstPageNumber length] > 0) {
        printWindow.firstPageNumber = [firstPageNumber intValue];
    }
    [printWindow setInfo:[NSNumber numberWithInteger:printWindow.firstPageNumber] forKey:@"firstPageNumber"];
    
    NSPrintOperation *op;
    
    WebHTMLView *documentView = (WebHTMLView *)[[[pageView mainFrame] frameView] documentView];
    // Switch the HTMLView to print mode so it does not toggle between print and non print mode during the process.
    [documentView _web_setPrintingModeRecursiveAndAdjustViewSize];
    
    op = [[[pageView mainFrame] frameView] printOperationWithPrintInfo:printInfo];
    
    [op setShowsPrintPanel:NO];
    [op setShowsProgressPanel:NO];
    
    [op runOperation];
    // We cannot run printOperation in backgroup because WebView does not work in secondary thread for DOM searching and modifications.
    [op cleanUpOperation];
    
    [_delegate printingDone];
    [self setDelegate:nil];
    [self releaseResources];
}

- (BOOL)isFlipped
{
	return TRUE;
}

- (void)releaseResources
{
    // Delete the inner iFrame to stop a memory huge leak found when using web kit from in Safari 8.0.5 (10600.5.17) on Yosemite
    PdfPrintWindow *printWindow = (PdfPrintWindow *)self.window;
    DOMHTMLIFrameElement *contentFrameElement = (DOMHTMLIFrameElement *)[printWindow.pageDocument getElementById:@"contentFrame"];
    [[contentFrameElement parentNode]removeChild:contentFrameElement];

    [pageView stopLoading:nil]; // Stop loading of resources if any to prevent delegate callback to invalid object
    [pageView setHostWindow:nil]; // Break retain cycle between window and WebView
    pageView = nil;
}

- (void)dealloc
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self];
}

@end
