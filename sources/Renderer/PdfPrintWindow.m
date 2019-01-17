//
//  PdfPrintWindow.m
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 12-08-22.
//

#import "PdfPrintWindow.h"
#import <WebKit/WebKit.h>

@implementation PdfPrintWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
    if ((self = [super initWithContentRect:(NSRect)contentRect 
                                 styleMask:(NSUInteger)windowStyle 
                                   backing:(NSBackingStoreType)bufferingType 
                                     defer:(BOOL)deferCreation]) != nil) {
        self.firstPageNumber = 1;
        self.marginOffsetForEvenPages = 0;
        lineBoxRectDict = [NSMutableDictionary dictionary];
    }
    return self;
}

// lineBoxRects computation is very expensive on large bloc of text, we keep the result in cache.
// This optimization is especially usefull on long textual documents where the same lines can be requested many times.
- (NSArray *)lineBoxRectsForNode:(DOMHTMLElement*)node
{
    NSArray *linesBoxes = [lineBoxRectDict objectForKey:[node description]];
    if (linesBoxes == nil) {
        linesBoxes = [node lineBoxRects];
        [lineBoxRectDict setObject:linesBoxes forKey:[node description]];
    }
    return linesBoxes;
}

- (int)lastPageNumber
{
    return self.firstPageNumber + (int)[self.pagesRects count] - 1;
}

- (void)setInfo:(id)object forKey:(NSString*)key
{
    [_infoDict setObject:object forKey:key];
}

- (void)logMessage:(NSString*)aMessage
{
    NSString *message = [NSString stringWithFormat:@"%@: %@\n", [NSCalendarDate calendarDate], aMessage];
    [_logFileHandle writeData:[message dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
