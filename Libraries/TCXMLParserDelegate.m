//
//  TCXMLParserDelegate.m
//
//  Copyright 2009 Dennis Stevense. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//  
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "TCXMLParserDelegate.h"
#import "TCXMLParserDelegate+Protected.h"


@implementation TCXMLParserDelegate

#pragma mark NSObject

- (void)dealloc {
	[parentParserDelegate release];
	[target release];
	[userInfo release];
	[startElement release];
	[elementAttributes release];
	[stringBuffer release];
	
	[super dealloc];
}

#pragma mark TCXMLParserDelegate

- (void)startWithXMLParser:(NSXMLParser *)parser element:(NSString *)name attributes:(NSDictionary *)attributes notifyTarget:(id)obj selector:(SEL)sel userInfo:(id)info {
	NSAssert(parser != nil, @"Expected non-nil parser.");
	NSAssert(name != nil, @"Expected non-nil parser.");
	NSAssert(obj == nil || sel != NULL, @"Expected selector when target is given.");
	
	// Hang on to the current parser delegate
	[parentParserDelegate release];
	parentParserDelegate = [[parser delegate] retain];

	[target release];
	target = [obj retain];
	selector = sel;
	[userInfo release];
	userInfo = [info retain];

	// Replace the parser delegate with ourselves and make sure we are not released
	[parser setDelegate:self];
	[self retain];

	[startElement release];
	startElement = [name copy];
	elementDepth = 0;
	[elementAttributes release];
	elementAttributes = [attributes copy];
	simpleElement = YES;
	[stringBuffer release];
	stringBuffer = [[NSMutableString alloc] init];
	
	[self parsingDidStartWithElement:name attributes:attributes];
}

- (void)parsingDidStartWithElement:(NSString *)name attributes:(NSDictionary *)attributes {
}

- (void)parsingDidFindSimpleElement:(NSString *)name attributes:(NSDictionary *)attributes content:(NSString *)content {
}

- (id)parsingDidEndWithElementContent:(NSString *)content {
	return self;
}

#pragma mark NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
	elementDepth++;
	[elementAttributes release];
	elementAttributes = [attributeDict copy];
	simpleElement = YES;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	if (simpleElement) {
		[stringBuffer appendString:string];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	NSString *content = nil;
	
	if (simpleElement) {
		content = [stringBuffer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		[self parsingDidFindSimpleElement:elementName attributes:elementAttributes content:content];
	}

	// Is this the closing tag for the element we started with?
	if (elementDepth == 0 && [elementName isEqualToString:startElement]) {
		id arg = [self parsingDidEndWithElementContent:content];
		
		// Notify if necessary
		if (target != nil && selector != NULL) {
			[target performSelector:selector withObject:arg withObject:userInfo];
		}
		
		// Restore the parser delegate and autorelease ourselves
		// Note: don't release ourselves immediately because we want to finish this method first, otherwise our instance variables could be released twice
		[parser setDelegate:parentParserDelegate];
		[self autorelease];
		[parentParserDelegate release];
		parentParserDelegate = nil;
		[target release];
		target = nil;
		[userInfo release];
		userInfo = nil;
		[startElement release];
		startElement = nil;
		[stringBuffer release];
		stringBuffer = nil;
	}
	else {
		elementDepth--;
	}
	
	// If we encountered a closing tag, the enclosing element is not 'simple'
	[elementAttributes release];
	elementAttributes = nil;
	simpleElement = NO;
	[stringBuffer setString:@""];
}

@end
