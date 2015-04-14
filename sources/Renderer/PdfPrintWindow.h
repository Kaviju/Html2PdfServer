//
//  PdfPrintWindow.h
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 12-08-22.
//  Copyright (c) 2012 Cyber Cat. All rights reserved.
//

#import <AppKit/AppKit.h>
@class WebHTMLView, DOMHTMLDocument, DOMHTMLElement;

@interface PdfPrintWindow : NSWindow {
    NSMutableDictionary *lineBoxRectDict;
}

@property(retain)NSArray *pagesRects;
@property(assign)BOOL hasHeader;
@property(assign)int firstPageNumber;
@property(assign)int currentPageNumber;
@property(assign)CGFloat marginOffsetForEvenPages;

@property(assign)int htmlWidth;
@property(assign)int htmlHeight;
@property(assign)int contentHeight;
@property(assign)NSRect viewToPaginateFrame;
@property(assign)CGFloat scaleFactor;

@property(assign)WebHTMLView *documentView;
@property(retain)DOMHTMLDocument *pageDocument;
@property(retain)NSScrollView *contentScrollView;
@property(retain)DOMHTMLDocument *contentDocument;

@property(retain)NSFileHandle *logFileHandle;
@property(retain)NSMutableDictionary *infoDict;

- (NSArray *)lineBoxRectsForNode:(DOMHTMLElement*)node;

- (int)lastPageNumber;
- (void)setInfo:(id)object forKey:(NSString*)key;
- (void)logMessage:(NSString*)aMessage;

@end
