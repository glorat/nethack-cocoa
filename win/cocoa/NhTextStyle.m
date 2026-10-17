//
//  NhTextStyle.m
//  NetHack
//

#import "NhTextStyle.h"

#include "hack.h"

static NSColor * Adaptive(NSColor * light, NSColor * dark)
{
	return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance * appearance) {
		NSAppearanceName name = [appearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
		return [name isEqualToString:NSAppearanceNameDarkAqua] ? dark : light;
	}];
}

static NSColor * RGB(CGFloat r, CGFloat g, CGFloat b)
{
	return [NSColor colorWithSRGBRed:r green:g blue:b alpha:1.0];
}

NSColor * NhTextColor(int color)
{
	switch ( color ) {
		case CLR_BLACK:				return Adaptive(RGB(0.25, 0.25, 0.25), RGB(0.55, 0.55, 0.55));
		case CLR_RED:				return [NSColor systemRedColor];
		case CLR_GREEN:				return Adaptive(RGB(0.0, 0.5, 0.0), RGB(0.3, 0.75, 0.3));
		case CLR_BROWN:				return [NSColor systemBrownColor];
		case CLR_BLUE:				return Adaptive(RGB(0.0, 0.2, 0.8), RGB(0.4, 0.55, 1.0));
		case CLR_MAGENTA:			return [NSColor systemPurpleColor];
		case CLR_CYAN:				return Adaptive(RGB(0.0, 0.5, 0.55), RGB(0.3, 0.8, 0.85));
		case CLR_ORANGE:			return [NSColor systemOrangeColor];
		case CLR_BRIGHT_GREEN:		return [NSColor systemGreenColor];
		case CLR_YELLOW:			return Adaptive(RGB(0.65, 0.5, 0.0), [NSColor systemYellowColor]);
		case CLR_BRIGHT_BLUE:		return [NSColor systemBlueColor];
		case CLR_BRIGHT_MAGENTA:	return [NSColor systemPinkColor];
		case CLR_BRIGHT_CYAN:		return [NSColor systemCyanColor];
		default:					return [NSColor labelColor];
	}
}

NSDictionary<NSAttributedStringKey, id> * NhTextAttributes(int color, int attr, NSFont * font)
{
	NSMutableDictionary * attributes = [NSMutableDictionary dictionary];
	NSColor * textColor = NhTextColor(color);
	NSFontManager * fonts = [NSFontManager sharedFontManager];
	switch ( attr & ~(ATR_URGENT | ATR_NOHISTORY) ) {
		case ATR_BOLD:
		case ATR_BLINK:
			font = [fonts convertFont:font toHaveTrait:NSBoldFontMask];
			break;
		case ATR_DIM:
			textColor = [textColor colorWithAlphaComponent:0.55];
			break;
		case ATR_ITALIC:
			font = [fonts convertFont:font toHaveTrait:NSItalicFontMask];
			break;
		case ATR_ULINE:
			attributes[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
			break;
		case ATR_INVERSE:
			attributes[NSBackgroundColorAttributeName] = [textColor colorWithAlphaComponent:0.2];
			break;
	}
	attributes[NSFontAttributeName] = font;
	attributes[NSForegroundColorAttributeName] = textColor;
	return attributes;
}
