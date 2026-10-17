//
//  NhTextStyle.h
//  NetHack
//

#import <Cocoa/Cocoa.h>

// a core color (CLR_*) as a text color that reads on the window background in light and dark mode
NSColor * NhTextColor(int color);

// font and color attributes for text the core gave a color and an attribute (ATR_*)
NSDictionary<NSAttributedStringKey, id> * NhTextAttributes(int color, int attr, NSFont * font);
