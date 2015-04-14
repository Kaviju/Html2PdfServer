//
//  WebHTMLView+PDFPrint.h
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 12-08-22.
//  Copyright (c) 2012. All rights reserved.
//

#import "WebHTMLView.h"
#import "PdfPrintWindow.h"
@class DOMNode, DOMNodeList;

@interface WebHTMLView (PDFPrint)

- (PdfPrintWindow *)printWindow;

- (void)replacePlaceHoldersInDocument:(DOMHTMLDocument *)document;
- (void)adjustNodesVisibilityInDocument:(DOMHTMLDocument *)document;
- (void)showNodes:(DOMNodeList *)nodes;
- (void)hideNodes:(DOMNodeList *)nodes;


- (int)nextPageBreakForView:(WebHTMLView *)view startingAt:(int)previousY pageHeight:(int)pageHeight;
- (NSArray *)forcedPagesBreakInDocument:(DOMHTMLDocument *)document;
- (NSRect)restrictedPageBreakForNode:(DOMNode *)node startingAt:(int)previousY pageHeight:(int)pageHeight suggestedBreak:(int)suggestedBreak;
- (NSRect)checkForRestrictedTRNode:(DOMNode *)node;

@end
