//
//  Html2PdfServerAppDelegate.h
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 11-10-12.
//  Copyright 2011. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class SimpleHTTPServer;

@interface Html2PdfServerAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
    SimpleHTTPServer *httpServer;
}

@property IBOutlet NSWindow *window;

@end
