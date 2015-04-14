//
//  Based on code from SimpleHTTPServer.m
//  Web2PDF Server
//
//  Created by Jürgen on 19.09.06.
//  Copyright 2006 Cultured Code.
//  License: Creative Commons Attribution 2.5 License
//           http://creativecommons.org/licenses/by/2.5/
//

#import "SimpleHTTPServer.h"
#import "SimpleHTTPConnection.h"
#import <sys/socket.h>   // for AF_INET, PF_INET, SOCK_STREAM, SOL_SOCKET, SO_REUSEADDR
#import <netinet/in.h>   // for IPPROTO_TCP, sockaddr_in
#include <netdb.h>

@interface SimpleHTTPServer (PrivateMethods)
- (void)setCurrentRequest:(NSDictionary *)value;
- (void)processNextRequestIfNecessary;
@end

@implementation SimpleHTTPServer

- (id)initWithTCPPort:(unsigned)port address:(NSString *)address
{
    if ((self = [super init]) != nil)
    {
        connections = [NSMutableSet set];
        NSLog(@"Starting SimpleHTTPServer on host %@ port: %d.", address, port);
        
		int fd = -1;
        CFSocketRef socket;
        socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, 0, NULL, NULL);
        if( socket )
		{
            fd = CFSocketGetNative(socket);
            int yes = 1;
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
            
            struct sockaddr_in addr4;
            memset(&addr4, 0, sizeof(addr4));
            addr4.sin_len = sizeof(addr4);
            addr4.sin_family = AF_INET;
            addr4.sin_port = htons(port);
			if ([address isEqual:@"*"])
				addr4.sin_addr.s_addr = htonl(INADDR_ANY);
			else
			{
				struct  hostent *host, *gethostbyname();
				host = gethostbyname([address UTF8String]);
				bcopy( host->h_addr, &(addr4.sin_addr.s_addr), host->h_length);
			}
            NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
            if (kCFSocketSuccess != CFSocketSetAddress(socket, (__bridge CFDataRef)address4)) {
                NSLog(@"Could not bind to address");
            }
            CFRelease(socket);
        } else {
            NSLog(@"No server socket");
        }
        
        serverFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd
                                                   closeOnDealloc:YES];

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(newConnection:)
                   name:NSFileHandleConnectionAcceptedNotification
                 object:nil];
        
        [serverFileHandle acceptConnectionInBackgroundAndNotify];
    }
    return self;
}

- (void)newConnection:(NSNotification *)notification
{
    @autoreleasepool { // Leaks if no autorelease pool here 2013-03-15
    NSDictionary *userInfo = [notification userInfo];
    NSFileHandle *remoteFileHandle = [userInfo objectForKey:
                                            NSFileHandleNotificationFileHandleItem];
    NSNumber *errorNo = [userInfo objectForKey:@"NSFileHandleError"];
    if( errorNo ) {
        NSLog(@"NSFileHandle Error: %@", errorNo);
        return;
    }

    [serverFileHandle acceptConnectionInBackgroundAndNotify];

    if( remoteFileHandle )
	{
        __block SimpleHTTPConnection *connection = [[SimpleHTTPConnection alloc] initWithFileHandle:remoteFileHandle server:self];
        if( connection )
		{
            [connections addObject:connection];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [connection processRequest];
            });
        }
    }
    }
}

- (void)forgetConnection:(SimpleHTTPConnection *)connection
{
    [connections removeObject:connection];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
