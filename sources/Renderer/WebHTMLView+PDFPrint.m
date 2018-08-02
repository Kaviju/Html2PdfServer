//
//  WebHTMLView+PDFPrint.m
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 12-08-22.
//

#import "WebHTMLView+PDFPrint.h"
#import "WebFrameView_Private.h"
#import <WebKit/WebKit.h>

@implementation WebHTMLView (PDFPrint)

- (PdfPrintWindow *)printWindow {
    return (PdfPrintWindow *)self.window;
}

- (NSRect)rectForPage:(int)pageNumber
{
    PdfPrintWindow *printWindow = [self printWindow];
    [printWindow logMessage:[NSString stringWithFormat:@"rectForPage %d", pageNumber]];
    printWindow.currentPageNumber = printWindow.firstPageNumber + pageNumber -1;
    
    NSRect bounds = [self bounds];
    if (printWindow.hasHeader)
    {
        [self adjustNodesVisibilityInDocument:printWindow.pageDocument];
        [self replacePlaceHoldersInDocument:printWindow.contentDocument];
        [self replacePlaceHoldersInDocument:printWindow.pageDocument];
        
        NSDictionary *pageRect = [printWindow.pagesRects objectAtIndex:pageNumber-1];
        
        DOMHTMLIFrameElement *contentFrame = (DOMHTMLIFrameElement *)[printWindow.pageDocument getElementById:@"contentFrame"];
        
        // Adjusting iFrame view to the current page dimensions
        contentFrame.style.height = [NSString stringWithFormat:@"%dpx", [[pageRect valueForKey:@"pageHeight"] intValue]];

        // Scroll the iFrame view to current page offset
        [[printWindow.contentScrollView contentView] scrollToPoint:NSMakePoint(0, [[pageRect valueForKey:@"pageOffset"] intValue])];
        return [printWindow.documentView frame];
    }
    else
    {
        NSDictionary *pageEntry = [printWindow.pagesRects objectAtIndex:pageNumber-1];
        NSRect pageRect = NSMakeRect(
                                     NSMinX(bounds),
                                     [[pageEntry valueForKey:@"pageOffset"] doubleValue],
                                     printWindow.htmlWidth,
                                     [[pageEntry valueForKey:@"pageHeight"] doubleValue]
                                     );
        return pageRect;
    }
}

- (void)adjustNodesVisibilityInDocument:(DOMHTMLDocument *)document
{
    PdfPrintWindow *printWindow = [self printWindow];
    DOMNodeList *nodes;
    
    if (printWindow.currentPageNumber == printWindow.firstPageNumber) {
        // handle node with showOnFirstPage class
        nodes = [document getElementsByClassName:@"showOnFirstPage"];
        [self showNodes:nodes];
        
        // handle node with hideOnFirstPage class
        nodes = [document getElementsByClassName:@"hideOnFirstPage"];
        [self hideNodes:nodes];
    }
    
    
    if (printWindow.currentPageNumber == (printWindow.firstPageNumber + 1)) {
        // handle node with showOnFirstPage class
        nodes = [document getElementsByClassName:@"showOnFirstPage"];
        [self hideNodes:nodes];
        
        // handle node with hideOnFirstPage class
        nodes = [document getElementsByClassName:@"hideOnFirstPage"];
        [self showNodes:nodes];
    }
    
    if (printWindow.currentPageNumber == [printWindow lastPageNumber]) {
        // handle node with hideOnLastPage class, we assume node is not visible by default
        nodes = [document getElementsByClassName:@"showOnLastPage"];
        [self showNodes:nodes];
        
        // handle node with hideOnLastPage class, we assume node is visible by default
        nodes = [document getElementsByClassName:@"hideOnLastPage"];
        [self hideNodes:nodes];
    }
}

- (void)showNodes:(DOMNodeList *)nodes {
    int nodesLength = [nodes length];
    int i;
    for (i=0; i<nodesLength; i++)
    {
        DOMHTMLElement *node = (DOMHTMLElement*)[nodes item:i];
        node.style.display = nil;
    }
}
- (void)hideNodes:(DOMNodeList *)nodes {
    int nodesLength = [nodes length];
    int i;
    for (i=0; i<nodesLength; i++)
    {
        DOMHTMLElement *node = (DOMHTMLElement*)[nodes item:i];
        node.style.display = @"none";
    }
}


- (void)replacePlaceHoldersInDocument:(DOMHTMLDocument *)document
{
    PdfPrintWindow *printWindow = [self printWindow];
    NSString *pageNumberText = [NSString stringWithFormat:@"%d", printWindow.currentPageNumber];
    unsigned long lastPageNumber = printWindow.firstPageNumber + [printWindow.pagesRects count] - 1;
    
    NSString *lastPageNumberText = [NSString stringWithFormat:@"%ld", lastPageNumber];
    
    DOMNodeList *nodes = [document getElementsByName:@"pageNumber"];
    int nodesLength = [nodes length];
    int i;
    for (i=0; i<nodesLength; i++)
    {
        DOMHTMLElement *node = (DOMHTMLElement*)[nodes item:i];
        [node setInnerText:pageNumberText];
    }
    
    nodes = [document getElementsByName:@"lastPageNumber"];
    nodesLength = [nodes length];
    for (i=0; i<nodesLength; i++)
    {
        DOMHTMLElement *node = (DOMHTMLElement*)[nodes item:i];
        [node setInnerText:lastPageNumberText];
    }
    
    // totalPageNumber is for backward compatibility support
    nodes = [document getElementsByName:@"totalPageNumber"];
    nodesLength = [nodes length];
    for (i=0; i<nodesLength; i++)
    {
        DOMHTMLElement *node = (DOMHTMLElement*)[nodes item:i];
        [node setInnerText:lastPageNumberText];
    }
}

- (NSPoint)locationOfPrintRect:(NSRect)aRect
{
    NSPoint originalLocation = [super locationOfPrintRect:aRect];
    PdfPrintWindow *printWindow = [self printWindow];
    if (printWindow.currentPageNumber % 2 == 0) {
        originalLocation.x -= printWindow.marginOffsetForEvenPages;
    }
    
    return originalLocation;
}

- (BOOL)knowsPageRange:(NSRangePointer)range
{
    [super knowsPageRange:range];
    PdfPrintWindow *printWindow = [self printWindow];
    NSPrintOperation *printOperation = [NSPrintOperation currentOperation];
    NSPrintInfo *printInfo = [printOperation printInfo];
    NSSize paperSize = [printInfo paperSize];
    
    // Compute the scale factor to fit the HTMP into the paper size less the margins.
    NSRect printViewFrame = [printWindow.documentView frame];
    printWindow.viewToPaginateFrame = [printWindow.documentView bounds];
    
    float viewWidth = NSWidth([printWindow.documentView bounds]);
    float printableWidth = [printInfo paperSize].width - [printInfo leftMargin] - [printInfo rightMargin];
    float printableHeight = [printInfo paperSize].height - [printInfo topMargin] - [printInfo bottomMargin];
    
    printWindow.scaleFactor = printableWidth / (viewWidth + 1); // Make sure we include the last pixel, rounding error may put it outside if we do not pad
    printWindow.htmlWidth = printableWidth/printWindow.scaleFactor;
    printWindow.htmlHeight = printableHeight/printWindow.scaleFactor;
    
    [printWindow setInfo:[NSString stringWithFormat:@"%f X %f", paperSize.width, paperSize.height] forKey:@"paperSize"];
    [printWindow setInfo:[NSString stringWithFormat:@"%f X %f", printableWidth, printableHeight] forKey:@"paperPrintableSize"];
    
    [printWindow setInfo:[NSString stringWithFormat:@"%f X %f", printViewFrame.size.width, printViewFrame.size.height] forKey:@"mainHtmlSize"];
    [printWindow setInfo:[NSNumber numberWithFloat:printWindow.scaleFactor] forKey:@"printScaleFactor"];
    [printWindow setInfo:[NSString stringWithFormat:@"%d X %d", printWindow.htmlWidth, printWindow.htmlHeight] forKey:@"paperSizeScaled"];
    
    [printWindow logMessage:[NSString stringWithFormat:@"Paper dimensions: %f X %f", paperSize.width, paperSize.height]];
    [printWindow logMessage:[NSString stringWithFormat:@"marginTop:%f marginLeft:%f marginBottom:%f marginRight:%f",
                             [printInfo topMargin], [printInfo leftMargin],
                             [printInfo bottomMargin], [printInfo rightMargin]]];
    
    [printWindow logMessage:[NSString stringWithFormat:@"Printer used: %@", printInfo.printer]];
    [printWindow logMessage:[NSString stringWithFormat:@"Printer imageablePageBounds: %@", NSStringFromRect(printInfo.imageablePageBounds)]];
    
    [printWindow logMessage:[NSString stringWithFormat:@"Printed dimensions: %f X %f", printableWidth, printableHeight]];
    [printWindow logMessage:[NSString stringWithFormat:@"HTML dimensions: %f X %f", printViewFrame.size.width, printViewFrame.size.height]];
    [printWindow logMessage:[NSString stringWithFormat:@"Shrink factor: %f", printWindow.scaleFactor]];
    
    [printWindow logMessage:[NSString stringWithFormat:@"Scaled Page dimensions: %d X %d", printWindow.htmlWidth, printWindow.htmlHeight]];
    
    
    NSMutableArray *pagesRects = [NSMutableArray array];
    if (printWindow.hasHeader)
    {
        // For the frame HTML view to layout so it's frame reflect real content size
        DOMHTMLIFrameElement *contentFrameElement = (DOMHTMLIFrameElement *)[printWindow.pageDocument getElementById:@"contentFrame"];
        
        printWindow.contentScrollView = (NSScrollView*)[[[contentFrameElement contentFrame] frameView] _scrollView];
        printWindow.viewToPaginateFrame = [contentFrameElement boundingBox];
        
        NSRect contentViewFrame = [[printWindow.contentScrollView documentView] frame];
        
        [printWindow logMessage:[NSString stringWithFormat:@"Content iframe dimensions: %d X %d", contentFrameElement.offsetWidth, contentFrameElement.offsetHeight]];
        [printWindow setInfo:[NSString stringWithFormat:@"%d X %d", contentFrameElement.offsetWidth, contentFrameElement.offsetHeight] forKey:@"contentIframeDimensions"];
        
        int printableHtmlHeight = printableHeight/printWindow.scaleFactor;
        int unusedPrintableHtmlHeight = printableHtmlHeight - (int)printViewFrame.size.height;
        [printWindow logMessage:[NSString stringWithFormat:@"Unused HTML height: %d", unusedPrintableHtmlHeight]];
        [printWindow setInfo:[NSNumber numberWithInt:unusedPrintableHtmlHeight] forKey:@"unusedPrintableHtmlHeight"];
        
        [printWindow logMessage:[NSString stringWithFormat:@"HTML content dimensions: %f X %f", contentViewFrame.size.width, contentViewFrame.size.height]];
        
        int currentFrameHeight = contentFrameElement.offsetHeight;
        
        int contentHeight = (int)ceilf(contentViewFrame.size.height);
        printWindow.contentHeight = contentHeight;
        [printWindow logMessage:[NSString stringWithFormat:@"contentHeight: %d", contentHeight]];
        
        NSArray *forcedBreaks = [self forcedPagesBreakInDocument:printWindow.contentDocument];
        int processedHeight = 0;
        
        NSEnumerator *en = [forcedBreaks objectEnumerator];
        NSNumber *pageBreak;
        while( (pageBreak = [en nextObject]) != nil  && processedHeight < contentHeight)
        {
            int nextForcedBreak = [pageBreak intValue];
            while ( processedHeight+currentFrameHeight < nextForcedBreak  && processedHeight < contentHeight)
            {
                //int nextPage = [self nextPageBreakForView:[contentScrollView documentView] startingAt:processedHeight pageHeight:currentFrameHeight];
                int nextPage = [self nextPageBreakForView:printWindow.documentView startingAt:processedHeight pageHeight:currentFrameHeight];
                NSNumber *pageOffset = [NSNumber numberWithInt:processedHeight];
                NSNumber *pageHeight = [NSNumber numberWithInt:nextPage-processedHeight];
                [pagesRects addObject:[NSDictionary dictionaryWithObjectsAndKeys:pageOffset, @"pageOffset", pageHeight, @"pageHeight", [NSNumber numberWithUnsignedInteger:[pagesRects count]+1], @"pageNumber", nil]];
                processedHeight = nextPage;
            }
            if (processedHeight < contentHeight)
            {
                NSNumber *pageOffset = [NSNumber numberWithInt:processedHeight];
                NSNumber *pageHeight = [NSNumber numberWithInt:nextForcedBreak-processedHeight];
                [pagesRects addObject:[NSDictionary dictionaryWithObjectsAndKeys:pageOffset, @"pageOffset", pageHeight, @"pageHeight", [NSNumber numberWithUnsignedInteger:[pagesRects count]+1], @"pageNumber",nil]];
                
                processedHeight = nextForcedBreak;
            }
        }
        
        while (processedHeight < contentHeight)
        {
            int nextPage = [self nextPageBreakForView:printWindow.documentView startingAt:processedHeight pageHeight:currentFrameHeight];
            NSNumber *pageOffset = [NSNumber numberWithInt:processedHeight];
            NSNumber *pageHeight = [NSNumber numberWithInt:nextPage-processedHeight];
            [pagesRects addObject:[NSDictionary dictionaryWithObjectsAndKeys:pageOffset, @"pageOffset", pageHeight, @"pageHeight", [NSNumber numberWithUnsignedInteger:[pagesRects count]+1], @"pageNumber",nil]];
            processedHeight = nextPage;
        }
        
        [printWindow logMessage:[NSString stringWithFormat:@"HTML content height: %f  iFrame height: %d  nbPages: %ld", [[printWindow.contentScrollView documentView] frame].size.height, currentFrameHeight, (unsigned long)[pagesRects count]]];
        [printWindow logMessage:[NSString stringWithFormat:@"Pages offsets: %@",pagesRects]];
    }
    else
    {
        NSArray *forcedBreaks = [self forcedPagesBreakInDocument:printWindow.pageDocument];
        
        int contentHeight = (int)ceilf(printViewFrame.size.height);
        printWindow.contentHeight = contentHeight;
        int processedHeight = 0;
        
        NSEnumerator *en = [forcedBreaks objectEnumerator];
        NSNumber *pageBreak;
        while( (pageBreak = [en nextObject]) != nil && processedHeight < contentHeight)
        {
            int nextForcedBreak = [pageBreak intValue];
            while ( processedHeight+printWindow.htmlHeight < nextForcedBreak && processedHeight < contentHeight)
            {
                int nextPage = [self nextPageBreakForView:printWindow.documentView startingAt:processedHeight pageHeight:printWindow.htmlHeight];
                NSNumber *pageOffset = [NSNumber numberWithInt:processedHeight];
                NSNumber *pageHeight = [NSNumber numberWithInt:nextPage-processedHeight];
                [pagesRects addObject:[NSDictionary dictionaryWithObjectsAndKeys:pageOffset, @"pageOffset", pageHeight, @"pageHeight", [NSNumber numberWithUnsignedInteger:[pagesRects count]+1], @"pageNumber",nil]];
                processedHeight = nextPage;
            }
            if (processedHeight < contentHeight)
            {
                NSNumber *pageOffset = [NSNumber numberWithInt:processedHeight];
                NSNumber *pageHeight = [NSNumber numberWithInt:nextForcedBreak-processedHeight];
                [pagesRects addObject:[NSDictionary dictionaryWithObjectsAndKeys:pageOffset, @"pageOffset", pageHeight, @"pageHeight", [NSNumber numberWithUnsignedInteger:[pagesRects count]+1], @"pageNumber",nil]];
                
                processedHeight = nextForcedBreak;
            }
        }
        
        while (processedHeight < contentHeight)
        {
            int nextPage = [self nextPageBreakForView:printWindow.documentView startingAt:processedHeight pageHeight:printWindow.htmlHeight];
            NSNumber *pageOffset = [NSNumber numberWithInt:processedHeight];
            NSNumber *pageHeight = [NSNumber numberWithInt:nextPage-processedHeight];
            [pagesRects addObject:[NSDictionary dictionaryWithObjectsAndKeys:pageOffset, @"pageOffset", pageHeight, @"pageHeight", [NSNumber numberWithUnsignedInteger:[pagesRects count]+1], @"pageNumber",nil]];
            processedHeight = nextPage;
        }
        [printWindow logMessage:[NSString stringWithFormat:@"Pages offsets: %@", pagesRects]];
    }
    printWindow.pagesRects = pagesRects;
    range->location = 1;
    range->length = [pagesRects count];
    [self setNeedsDisplay:YES];
    return YES;
}

- (int)nextPageBreakForView:(WebHTMLView *)view startingAt:(int)previousY pageHeight:(int)pageHeight
{
    PdfPrintWindow *printWindow = [self printWindow];
    int nextY = MIN(previousY + pageHeight, printWindow.contentHeight);
    int scrollingOffset = 0;
    int lastY;
    
    [printWindow logMessage:[NSString stringWithFormat:@"Next break initial: %d", nextY]];
    
    if (printWindow.contentHeight <= nextY) {
        return nextY;
    }
    
    if (printWindow.hasHeader)
    {
        // ScrollingOffset is use to transform coordinates from from the outer document to the inner document.
        scrollingOffset = previousY - printWindow.viewToPaginateFrame.origin.y + 1;
        // Scroll the iFrame view to current page offset
        [[printWindow.contentScrollView contentView] scrollToPoint:NSMakePoint(0, previousY)];
    }
    do
    {
        lastY = nextY;
        int x = printWindow.viewToPaginateFrame.origin.x;
        int viewWidth = printWindow.viewToPaginateFrame.size.width;
        while (x < viewWidth)
        {
            int nextX = x + 10;
            NSPoint elemPoint = NSMakePoint(x, nextY-scrollingOffset);
            NSDictionary *elem = [view elementAtPoint:elemPoint];
            DOMHTMLElement *node = (DOMHTMLElement*)[elem objectForKey:@"WebElementDOMNode"];
            NSRect restrictedBreak = [self restrictedPageBreakForNode:node startingAt:previousY pageHeight:pageHeight suggestedBreak:nextY];
            NSRect nodeRect = [node boundingBox];
            
            if (restrictedBreak.origin.y != 0)
            {
                nextX = MAX(nextX, restrictedBreak.origin.x + restrictedBreak.size.width);
                if (nextY > restrictedBreak.origin.y && previousY < restrictedBreak.origin.y)
                {
                    nextY = restrictedBreak.origin.y + 1;
                    break;
                }
            }
            else if ( [node nodeType] == DOM_TEXT_NODE || ([node nodeType] == DOM_ELEMENT_NODE && ![[node tagName] isEqual:@"HTML"] ) ) // Check text lines of no restrictions
            {
                NSArray *lines = [self.printWindow lineBoxRectsForNode:node];
                for (NSValue *line in lines)
                {
                    NSRect lineRect = [line rectValue];
                    if (lineRect.origin.y > nextY) break;
                    if (lineRect.origin.y < nextY && lineRect.origin.y+lineRect.size.height > nextY)
                    {
                        if (nextY > lineRect.origin.y)
                        {
                            nextY = lineRect.origin.y + 1;
                            nextX = MAX(nextX, lineRect.origin.x + lineRect.size.width);
                            break;
                        }
                    }
                }
                
                if ([self nodeHasOnlyTextChilds:node]) {  // skip remaining of the node width if no childrens
                    nextX = MAX(nextX, nodeRect.origin.x + nodeRect.size.width);
                }
            }
            x = nextX;
        }
    }
    while (lastY != nextY);
    if (nextY <= previousY)
    {
        nextY = previousY + pageHeight;
    }
    return nextY;
}

- (BOOL)nodeHasOnlyTextChilds:(DOMHTMLElement *)node
{
    BOOL onlyTextChilds = YES;
    
    DOMNodeList *nodes = [node childNodes];
    int nodesLength = [nodes length];
    int i;
    for (i=0; i<nodesLength; i++)
    {
        DOMHTMLElement *node = (DOMHTMLElement*)[nodes item:i];
        if ([node nodeType] != DOM_TEXT_NODE ) {
            onlyTextChilds = NO;
            break;
        }
    }
    return onlyTextChilds;
}

- (NSArray *)forcedPagesBreakInDocument:(DOMHTMLDocument *)document
{
    NSArray *elementNames = [NSArray arrayWithObjects:@"h1", @"h2", @"h3", @"h4", @"h5", @"br", @"p", @"table", @"tr", @"div", NULL];
    NSMutableArray *pagesBreaks = [NSMutableArray array];
    
    NSEnumerator *en = [elementNames objectEnumerator];
    NSString *tagName;
    while( (tagName = [en nextObject]) != nil)
    {
        DOMNodeList *nodes = [document getElementsByTagName:tagName];
        int nodesLength = [nodes length];
        int i;
        for (i=0; i<nodesLength; i++)
        {
            DOMHTMLElement *node = (DOMHTMLElement*)[nodes item:i];
            DOMCSSStyleDeclaration *nodeStyle = [document getComputedStyle:node pseudoElement:nil];
            
            if ([[nodeStyle pageBreakBefore] isEqual:@"always"])
            {
                int elemTop = [node boundingBox].origin.y;
                if (elemTop > 0)
                {
                    [pagesBreaks addObject:[NSNumber numberWithInt:elemTop]];
                }
            }
            
            if ([[nodeStyle pageBreakAfter] isEqual:@"always"])
            {
                int elemTop = [node boundingBox].origin.y;
                int elemHeight = [node boundingBox].size.height;
                if (elemTop+elemHeight > 0)
                {
                    [pagesBreaks addObject:[NSNumber numberWithInt:elemTop+elemHeight]];
                }
            }
        }
    }
    [pagesBreaks sortUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    [[self printWindow] logMessage:[NSString stringWithFormat:@"Forced Breaks: %@", pagesBreaks]];
    return pagesBreaks;
}

- (NSRect)restrictedPageBreakForNode:(DOMNode *)node startingAt:(int)previousY pageHeight:(int)pageHeight suggestedBreak:(int)suggestedBreak
{
    NSRect elemRect = NSRectFromCGRect(CGRectZero);
    
    // TextNode are not HTMLElement and does not have style or offset, we go directly to the enclosing HTML node for style check.
    if ([node isKindOfClass:[DOMText class]]) {
        node = node.parentNode;
    }
    
    if ([node isKindOfClass:[DOMHTMLElement class]])
    {
        do
        {
            // Check node for page-break-avoid: avoid style
            DOMCSSStyleDeclaration *elemStyle = [[self _webView] computedStyleForElement:(DOMHTMLElement *)node pseudoElement:nil];
            if ([[elemStyle pageBreakInside] isEqual:@"avoid"])
            {
                NSRect nodeRect = [node boundingBox];
                UInt nodeBottom = nodeRect.origin.y+nodeRect.size.height;
                [[self printWindow] logMessage:[NSString stringWithFormat:@"Restricted %@ found start: %f to: %u", [node nodeName], nodeRect.origin.y, nodeBottom]];
                if ( nodeRect.size.height < pageHeight && nodeRect.origin.y > previousY && suggestedBreak < nodeBottom)
                {
                    elemRect = nodeRect;
                }
            }
            
            if ([node isKindOfClass:[DOMHTMLTableCellElement class]]) {
                NSRect nodeRect = [self checkForRestrictedTRNode:[node parentNode]];
                if (nodeRect.size.height > 0 && nodeRect.size.height < pageHeight) {
                    [[self printWindow] logMessage:[NSString stringWithFormat:@"Restricted TR found start: %f to: %f", nodeRect.origin.y, nodeRect.origin.y+nodeRect.size.height]];
                    node = node.parentNode;
                    
                    if ( nodeRect.size.height < pageHeight && nodeRect.origin.y > previousY && suggestedBreak < nodeRect.origin.y+nodeRect.size.height)
                    {
                        elemRect = nodeRect;
                    }
                }
            }
        }
        // Check parent node hirarchie for page-break-avoid: avoid style
        while ( (node = node.parentNode) != NULL);
    }
    return elemRect;
}

- (NSRect)checkForRestrictedTRNode:(DOMNode *)trNode
{
    if (![trNode isKindOfClass:[DOMHTMLTableRowElement class]])
    {
        return NSMakeRect(0, 0, 0, 0);
    }
    NSRect trRect = NSMakeRect(0, 0, 0, 0);
    
    DOMCSSStyleDeclaration *elemStyle = [[self _webView] computedStyleForElement:(DOMHTMLElement *)trNode pseudoElement:nil];
    if ([[elemStyle pageBreakInside] isEqual:@"avoid"])
    {
        DOMNodeList *childs = [trNode childNodes];
        int nbChilds = [childs length];
        int i;
        for (i=0; i<nbChilds; i++)
        {
            DOMHTMLElement *node = (DOMHTMLElement*)[childs item:i];
            if ( ![node isKindOfClass:[DOMHTMLTableCellElement class]] ) {
                continue;
            }
            NSRect tdRect = [node boundingBox];
            if (trRect.origin.x == 0 || trRect.origin.x > tdRect.origin.x) {
                trRect.origin.x = tdRect.origin.x;
            }
            if (trRect.origin.y == 0 || trRect.origin.y > tdRect.origin.y) {
                trRect.origin.y = tdRect.origin.y;
            }
            trRect.size.width += tdRect.size.width;
            if (trRect.size.height == 0 || trRect.size.height < tdRect.size.height) {
                trRect.size.height = tdRect.size.height;
            }
        }
    }
    return trRect;
}

// This method is used by WebHTMLView to return the scale foactor to use for printing.
// The default method return the same thing as us but there is a lower limit set to 0.5.
// We want to support any values, the html designer is responsible for the result.
- (float)_scaleFactorForPrintOperation:(NSPrintOperation *)printOperation
{
    return [self printWindow].scaleFactor;
}

@end
