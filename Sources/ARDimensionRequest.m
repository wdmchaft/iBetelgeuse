//
//  ARDimensionRequest.m
//  iBetelgeuse
//
//  Copyright 2010 Finalist IT Group. All rights reserved.
//
//  This file is part of iBetelgeuse.
//  
//  iBetelgeuse is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//  
//  iBetelgeuse is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with iBetelgeuse.  If not, see <http://www.gnu.org/licenses/>.
//

#import "ARDimensionRequest.h"
#import "ARDimension.h"
#import "ARSpatialState.h"
#import "ARLocation.h"
#import "NSURLRequest+ARFormURLEncoding.h"

#if TARGET_OS_IPHONE
	#import <UIKit/UIDevice.h>
	#import "TCNetworkActivityIndicator.h"
#endif


NSString *const ARDimensionRequestErrorDomain = @"ARDimensionRequestErrorDomain";
const NSInteger ARDimensionRequestErrorHTTP = 1;
NSString *const ARDimensionRequestErrorHTTPStatusCodeKey = @"statusCode";
const NSInteger ARDimensionRequestErrorDocument = 2;


#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_6
@interface ARDimensionRequest () <NSXMLParserDelegate>
#else
@interface ARDimensionRequest ()
#endif

/**
 * Returns a unique identifier suitable for a dimension request. In practice, returns the identifier of the device.
 */
- (NSString *)uniqueIdentifier;

/**
 * Creates and returns a NSURLRequest using the current values of the receiver.
 */
- (NSURLRequest *)prepareRequest;


/**
 * Callback for the dimension parsing.
 *
 * @param aDimension The dimension that was parsed, or nil if parsing failed.
 */
- (void)didParseDimension:(ARDimension *)aDimension;

@end


@implementation ARDimensionRequest

@synthesize delegate, url, spatialState, type, source, screenSize;

#pragma mark NSObject

- (id)initWithURL:(NSURL *)aURL spatialState:(ARSpatialState *)aSpatialState type:(ARDimensionRequestType)aType {
	NSAssert(aURL != nil, @"Expected non-nil URL.");
	NSAssert1(([[NSSet setWithObjects:@"http", @"gamaray", @"file", nil] containsObject:[aURL scheme]]), @"Unexpected URL scheme %@.", [aURL scheme]);
	NSAssert(aSpatialState != nil, @"Expected non-nil spatial state.");
	
	if (self = [super init]) {
		url = [aURL retain];
		spatialState = [aSpatialState retain];
		type = aType;
	}
	return self;
}

- (void)dealloc {
#if TARGET_OS_IPHONE
	// To be sure
	[[TCNetworkActivityIndicator sharedIndicator] releaseWithToken:self];
#endif
	
	[url release];
	[spatialState release];
	[source release];
	
	[connection release];
	[response release];
	[responseData release];
	[parser release];
	[dimension release];
	
	[super dealloc];
}

#pragma mark ARDimensionRequest

#if TARGET_OS_IPHONE

- (NSString *)uniqueIdentifier {
	return [[UIDevice currentDevice] uniqueIdentifier];
}

#else

- (NSString *)uniqueIdentifier {
	// Just return something
	return @"TEST";
}

#endif

- (NSURLRequest *)prepareRequest {
	NSURL *requestURL = url;
	
	// Replace non-http schemes
	if (![requestURL isFileURL] && ![[requestURL scheme] isEqualToString:@"http"]) {
		NSString *urlString = [requestURL absoluteString];
		NSRange urlSchemeRange = [urlString rangeOfString:[requestURL scheme] options:NSAnchoredSearch];
		NSString *httpURLString = [urlString stringByReplacingCharactersInRange:urlSchemeRange withString:@"http"];
		requestURL = [NSURL URLWithString:httpURLString];
	}
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:requestURL];
	[request setHTTPMethod:@"POST"];
	
	NSMutableDictionary *postData = [[NSMutableDictionary alloc] init];

	switch (type) {
		case ARDimensionRequestTypeInit:
			[postData setObject:@"init" forKey:@"event"];
			break;
			
		case ARDimensionRequestTypeTimeRefresh:
			[postData setObject:@"refreshOnTime" forKey:@"event"];
			break;
			
		case ARDimensionRequestTypeDistanceRefresh:
			[postData setObject:@"refreshOnDistance" forKey:@"event"];
			break;
			
		case ARDimensionRequestTypeActionRefresh:
			[postData setObject:@"refreshOnPress" forKey:@"event"];
			break;
	}
	
	if (source) {
		[postData setObject:source forKey:@"eventSrc"];
	}
	else {
		[postData setObject:@"NULL" forKey:@"eventSrc"];
	}
	
	[postData setObject:[NSString stringWithFormat:@"%f", [[spatialState location] latitude]] forKey:@"lat"];
	[postData setObject:[NSString stringWithFormat:@"%f", [[spatialState location] longitude]] forKey:@"lon"];
	[postData setObject:[NSString stringWithFormat:@"%f", [[spatialState location] altitude]] forKey:@"alt"];
	
	[postData setObject:[NSString stringWithFormat:@"%f", [spatialState bearing] / M_PI * 180.] forKey:@"bearing"];
	[postData setObject:[NSString stringWithFormat:@"%f", [spatialState pitch] / M_PI * 180.] forKey:@"pitch"];
	[postData setObject:[NSString stringWithFormat:@"%f", [spatialState roll] / M_PI * 180.] forKey:@"roll"];
	
	if (!CGSizeEqualToSize(screenSize, CGSizeZero)) {
		[postData setObject:[NSString stringWithFormat:@"%d", (int)roundf(screenSize.width)] forKey:@"width"];
		[postData setObject:[NSString stringWithFormat:@"%d", (int)roundf(screenSize.height)] forKey:@"height"];
	}
	
	[postData setObject:[self uniqueIdentifier] forKey:@"uid"];

	[postData setObject:[NSString stringWithFormat:@"%ld", (long long)floorf([[NSDate date] timeIntervalSince1970] * 1000.0)] forKey:@"time"];
	
	[request setHTTPBody:[[NSURLRequest ar_formURLEncodedStringWithDictionary:postData] dataUsingEncoding:NSUTF8StringEncoding]];
	
	[postData release];
	
	return [request autorelease];
}

- (void)start {
#if TARGET_OS_IPHONE
	[[TCNetworkActivityIndicator sharedIndicator] retainWithToken:self];
#endif

	DebugLog(@"Starting dimension request with URL: %@", url);
	
	[connection release];
	if ([delegate respondsToSelector:@selector(dimensionRequest:connectionWithRequest:delegate:)]) {
		connection = [[delegate dimensionRequest:self connectionWithRequest:[self prepareRequest] delegate:self] retain];
		NSAssert(connection != nil, @"Expected non-nil connection from delegate.");
	}
	else {
		connection = [[NSURLConnection alloc] initWithRequest:[self prepareRequest] delegate:self];
	}
}

- (void)cancel {
	[connection cancel];
	[connection release];
	connection = nil;
	
	DebugLog(@"Cancelled dimension request with URL: %@", url);
	
#if TARGET_OS_IPHONE
	[[TCNetworkActivityIndicator sharedIndicator] releaseWithToken:self];
#endif
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)aResponse {
	NSUInteger capacity = [aResponse expectedContentLength] == NSURLResponseUnknownLength ? 0 : [aResponse expectedContentLength];
	
	[response release];
	response = [aResponse retain];
	
	[responseData release];
	responseData = [[NSMutableData alloc] initWithCapacity:capacity];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	if ([response isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)response statusCode] != 200) {
		NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
		
		DebugLog(@"Failed dimension request, received HTTP %d", statusCode);
		
		NSString *errorDescription = [NSString stringWithFormat:NSLocalizedString(@"Received HTTP %@.", @"dimension request error description"), [NSHTTPURLResponse localizedStringForStatusCode:statusCode]];
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:errorDescription, NSLocalizedDescriptionKey, [NSNumber numberWithInteger:statusCode], ARDimensionRequestErrorHTTPStatusCodeKey, nil];
		NSError *error = [NSError errorWithDomain:ARDimensionRequestErrorDomain code:ARDimensionRequestErrorHTTP userInfo:errorInfo];
		[delegate dimensionRequest:self didFailWithError:error];
	}
	else {
		[parser release];
		parser = [[NSXMLParser alloc] initWithData:responseData];
		[parser setDelegate:self];
		
		didAbortParsing = NO;
		if ([parser parse] && dimension) {
			DebugLog(@"Finished dimension request");
			
			[delegate dimensionRequest:self didFinishWithDimension:dimension];
		}
		else if (!didAbortParsing && [parser parserError]) {
			DebugLog(@"Failed to parse response to dimension request, received error %@", [parser parserError]);
			
			[delegate dimensionRequest:self didFailWithError:[parser parserError]];
		}
		else {
			DebugLog(@"Failed to find a dimension in dimension request");
			
			NSString *errorDescription = NSLocalizedString(@"Dimension not found.", @"dimension request error description");
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:errorDescription, NSLocalizedDescriptionKey, nil];
			NSError *error = [NSError errorWithDomain:ARDimensionRequestErrorDomain code:ARDimensionRequestErrorDocument userInfo:errorInfo];
			[delegate dimensionRequest:self didFailWithError:error];
		}
	}
	
#if TARGET_OS_IPHONE
	[[TCNetworkActivityIndicator sharedIndicator] releaseWithToken:self];
#endif
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	DebugLog(@"Failed dimension request, received error %@", error);
	
	[delegate dimensionRequest:self didFailWithError:error];
	
#if TARGET_OS_IPHONE
	[[TCNetworkActivityIndicator sharedIndicator] releaseWithToken:self];
#endif
}

#pragma mark NSXMLParserDelegate

- (void)parser:(NSXMLParser *)aParser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
	if ([elementName isEqualToString:@"dimension"]) {
		[ARDimension startParsingWithXMLParser:aParser element:elementName attributes:attributeDict notifyTarget:self selector:@selector(didParseDimension:) userInfo:nil];
	}
	else {
		// We want the root element to be 'dimension', so we don't want to look any further
		[aParser abortParsing];
		didAbortParsing = YES;
	}
}

- (void)didParseDimension:(ARDimension *)aDimension {
	[dimension release];
	dimension = [aDimension retain];
}

@end
