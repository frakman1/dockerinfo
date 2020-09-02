//
//  NSString+ANSI.m
//  BitBar
//
//  Created by Kent Karlsson on 3/11/16.
//  Copyright © 2016 Bit Bar. All rights reserved.
//

#import "Cocoa/Cocoa.h"
#import "NSString+ANSI.h"
#import "NSColor+ANSI.h"
#import "NSColor+Hex.h"

@implementation NSMutableDictionary (ANSI)

- (NSMutableDictionary*)modifyAttributesForANSICodes:(NSString*)codes {
  BOOL bold = NO, color256 = NO;
  NSNumber *foreground = nil;
  NSFont* font = self[NSFontAttributeName];

  NSArray* codeArray = [codes componentsSeparatedByString:@";"];

  for (NSString* codeString in codeArray) {
    int code = codeString.intValue;
    
    if (foreground) {
      if (color256) {
        color256 = NO;
        
        NSColor *color = [NSColor colorForAnsi256ColorIndex:code];
        if (color) {
          self[foreground.boolValue ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName] = color;
          foreground = nil;
          continue;
        }
        
        // support the first 16 colors here
        bold = code >= 8 && code < 16;
        if (bold) code -= 8;
        code += foreground.boolValue ? 30 : 40;
      } else if (code == 5) {
        color256 = YES;
        continue;
      }
      
      foreground = nil;
    }

    switch (code) {
      case 0:
        [self removeAllObjects];
        // remove italic and bold from font here
        if (font) self[NSFontAttributeName] = font;
        break;

      case 1:
      case 22:
        bold = (code == 1);
        break;

    // case 3: italic
    // case 23: italic off

      case 4: //underlined
        self[NSUnderlineStyleAttributeName] = [NSNumber numberWithInt:NSUnderlineStyleSingle];
        break;
        
      case 9: //strikethrough
        self[NSStrikethroughStyleAttributeName] = [NSNumber numberWithInt:0x1];
        break;
        
     case 24: //underlined off
        self[NSUnderlineStyleAttributeName] = [NSNumber numberWithInt:NSUnderlineStyleNone];
        break;

      case 29: //strikethrough off
        self[NSStrikethroughStyleAttributeName] = [NSNumber numberWithInt:0x0];
        break;

      case 30:
        self[NSForegroundColorAttributeName] = [NSColor colorWithHexColorString:bold ? @"7f7f7f" : @"000000"];
        break;
      case 31:
        self[NSForegroundColorAttributeName] = [NSColor colorWithHexColorString:bold ? @"cd0000" : @"ff0000"];
        break;
      case 32:
        self[NSForegroundColorAttributeName] = [NSColor colorWithHexColorString:bold ? @"00cd00" : @"00ff00"];
        break;
      case 33:
        self[NSForegroundColorAttributeName] = [NSColor colorWithHexColorString:bold ? @"cdcd00" : @"ffff00"];
        break;
      case 34:
        self[NSForegroundColorAttributeName] = [NSColor colorWithHexColorString:bold ? @"0000ee" : @"5c5cff"];
        break;
      case 35:
        self[NSForegroundColorAttributeName] = [NSColor colorWithHexColorString:bold ? @"cd00cd" : @"ff00ff"];
        break;
      case 36:
        self[NSForegroundColorAttributeName] = [NSColor colorWithHexColorString:bold ? @"00cdcd" : @"00ffff"];
        break;
      case 37:
        self[NSForegroundColorAttributeName] = [NSColor colorWithHexColorString:bold ? @"e5e5e5" : @"ffffff"];
        break;

//      case 38:
//        self[NSForegroundColorAttributeName] = [NSColor colorWithWebColorString:bold ? @"orange" : @"orange"];
//        break;

      case 38:
        foreground = @YES;
        break;
        

      case 39:
        [self removeObjectForKey:NSForegroundColorAttributeName];
        break;

      case 40:
        self[NSBackgroundColorAttributeName] = [NSColor colorWithHexColorString:@"7f7f7f"];
        break;
      case 41:
        self[NSBackgroundColorAttributeName] = [NSColor colorWithHexColorString:@"cd0000"];
        break;
      case 42:
        self[NSBackgroundColorAttributeName] = [NSColor colorWithHexColorString:@"00cd00"];
        break;
      case 43:
        self[NSBackgroundColorAttributeName] = [NSColor colorWithHexColorString:@"cdcd00"];
        break;
      case 44:
        self[NSBackgroundColorAttributeName] = [NSColor colorWithHexColorString:@"0000ee"];
        break;
      case 45:
        self[NSBackgroundColorAttributeName] = [NSColor colorWithHexColorString:@"cd00cd"];
        break;
      case 46:
        self[NSBackgroundColorAttributeName] = [NSColor colorWithHexColorString:@"00cdcd"];
        break;
      case 47:
        self[NSBackgroundColorAttributeName] = [NSColor colorWithHexColorString:@"e5e5e5"];
        break;
      case 48:
        foreground = @NO;
        break;

      case 49:
        [self removeObjectForKey:NSBackgroundColorAttributeName];
        break;

      default:
        break;
    }
  }

  return self;
}

@end

@implementation NSString (ANSI)

- (BOOL)containsANSICodes {
  return [self rangeOfString:@"\033["].location != NSNotFound;
}

- (NSMutableAttributedString*)attributedStringParsingANSICodes {
  NSMutableAttributedString* result = [[NSMutableAttributedString alloc] init];

  NSMutableDictionary* attributes = [NSMutableDictionary.alloc init];
  NSArray* parts = [self componentsSeparatedByString:@"\033["];
  [result appendAttributedString:[NSAttributedString.alloc initWithString:parts.firstObject attributes:nil]];
  
  for (NSString* part in [parts subarrayWithRange:NSMakeRange(1, parts.count - 1)]) {
    if (part.length == 0)
      continue;

    NSArray* sequence = [part componentsSeparatedByString:@"m"];
    NSString* text = sequence.lastObject;

    if (sequence.count < 2) {
      [result appendAttributedString:[NSAttributedString.alloc initWithString:text attributes:attributes]];
    } else if (sequence.count >= 2) {
      text = [[sequence subarrayWithRange:NSMakeRange(1, sequence.count - 1)] componentsJoinedByString:@"m"];
      [attributes modifyAttributesForANSICodes:sequence[0]];
      [result appendAttributedString:[NSAttributedString.alloc initWithString:text attributes:attributes]];
    }
  }

  return result;
}

@end
