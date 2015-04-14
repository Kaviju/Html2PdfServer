//
//  Html2PdfServerAppDelegate.m
//  Html2PdfServer
//
//  Created by Samuel Pelletier on 11-10-12.
//

#import "Html2PdfServerAppDelegate.h"
#import <crt_externs.h>
#import "SimpleHTTPServer.h"
#import "RendererPool.h"

@implementation Html2PdfServerAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"0", @"numberOfRenderers", // will use the number of CPUs
                                 @"localhost", @"listenAddress", // will listen on localhost only
                                 @"1453", @"listenPort", // will listen port 1453
                                 nil];
    [defaults registerDefaults:appDefaults];
    
    NSInteger listenPort = [defaults integerForKey:@"listenPort"];
    
    NSString *listenAddress = [defaults stringForKey:@"listenAddress"];
    
    [RendererPool setNumberOfRenderers:[defaults integerForKey:@"numberOfRenderers"]];

    [RendererPool sharedPool];
    httpServer = [[SimpleHTTPServer alloc] initWithTCPPort:(unsigned)listenPort address:listenAddress];
}

@end
