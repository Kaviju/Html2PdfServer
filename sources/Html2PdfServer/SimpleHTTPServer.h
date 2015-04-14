//
//  Initial code from SimpleHTTPServer.h
//  Web2PDF Server
//
//  Created by Jürgen on 19.09.06.
//  Copyright 2006 Cultured Code.
//  License: Creative Commons Attribution 2.5 License
//           http://creativecommons.org/licenses/by/2.5/
//

#import <Cocoa/Cocoa.h>

@class SimpleHTTPConnection;

@interface SimpleHTTPServer : NSObject {
    NSFileHandle *serverFileHandle;
    NSMutableSet *connections;
}

- (id)initWithTCPPort:(unsigned)po address:(NSString *)address;

- (void)forgetConnection:(SimpleHTTPConnection *)connection;

@end
