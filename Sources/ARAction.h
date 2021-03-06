//
//  ARAction.h
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

#import <Foundation/Foundation.h>


/**
 * Describes the type of an ARAction.
 */
typedef enum {
	ARActionTypeRefresh,
	ARActionTypeURL,
	ARActionTypeDimension,
} ARActionType;


/**
 * Represents an action in a Gamaray dimension.
 */
@interface ARAction : NSObject {
@private
	ARActionType type;
	NSURL *URL;
}

/**
 * Initialize with a string formatted as one of the following:
 *
 * "<action>"
 * "<action>: <URL>"
 *
 * <action> may be one of: refresh, webpage, dimension. If <action> is webpage or dimension, not specifying a URL results in nil.
 *
 * @param string String to be parsed, may be nil.
 *
 * @return The receiver, or nil if the string was nil or incorrectly formatted.
 */
- (ARAction *)initWithString:(NSString *)string;

/**
 * The type of the receiver.
 */
@property(nonatomic, readonly) ARActionType type;

/**
 * The URL of the receiver, which may be nil if type equals ARActionTypeRefresh, and non-nil otherwise.
 */
@property(nonatomic, readonly) NSURL *URL;

@end
