#import <Cocoa/Cocoa.h>

// Posted on the main thread when the text size changes
extern NSNotificationName const NhTextSizeDidChangeNotification;

// The size of message text in points; other text is drawn in proportion to it
extern const CGFloat NhDefaultTextSize;

// The next step up or down from size, or the end step when there is none
CGFloat NhBiggerTextSize(CGFloat size);
CGFloat NhSmallerTextSize(CGFloat size);

// The nearest step to a size asked for in points, such as font_size_message
CGFloat NhTextSizeNearest(CGFloat points);

CGFloat NhTextSize(void);
void NhSetTextSize(CGFloat size);

// A size given for the default text size, scaled to the current one
CGFloat NhScaledFontSize(CGFloat size);
NSFont * NhScaledFont(NSFont * font);

// How tall a line of text in font is
CGFloat NhLineHeight(NSFont * font);
