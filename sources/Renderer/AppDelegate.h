//
//  AppDelegate.h
//  Renderer
//
//  Created by Samuel Pelletier on 2013-01-19.
//  Copyright (c) 2013 Cyber Cat. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PagedWebView.h"

@class PdfPrintWindow;

@interface AppDelegate : NSObject <NSApplicationDelegate, PagedWebViewDelegate>
{
    PdfPrintWindow *window;
    NSString *pdfPath;
    
    NSMutableDictionary *infoDict;

    NSTimeInterval beginTime;
    NSTimeInterval endFetch;
    NSTimeInterval endPrint;
}

- (void)logMessage:(NSString*)aMessage;

- (void)releasesRessources;

@end
