#import "TextSize.h"

NSNotificationName const NhTextSizeDidChangeNotification = @"NhTextSizeDidChange";

const CGFloat NhDefaultTextSize = 13;

static const CGFloat kSteps[] = { 10, 11, 12, 13, 14, 16, 18, 20, 22, 24, 28 };
static const int kStepCount = sizeof kSteps / sizeof kSteps[0];

static CGFloat currentSize = NhDefaultTextSize;

CGFloat NhBiggerTextSize(CGFloat size)
{
	for ( int i = 0; i < kStepCount; ++i )
		if ( kSteps[i] > size )
			return kSteps[i];
	return kSteps[kStepCount - 1];
}

CGFloat NhSmallerTextSize(CGFloat size)
{
	for ( int i = kStepCount - 1; i >= 0; --i )
		if ( kSteps[i] < size )
			return kSteps[i];
	return kSteps[0];
}

CGFloat NhTextSizeNearest(CGFloat points)
{
	CGFloat best = kSteps[0];
	for ( int i = 1; i < kStepCount; ++i )
		if ( fabs(kSteps[i] - points) < fabs(best - points) )
			best = kSteps[i];
	return best;
}

CGFloat NhTextSize(void)
{
	return currentSize;
}

void NhSetTextSize(CGFloat size)
{
	size = NhTextSizeNearest(size);
	if ( size == currentSize )
		return;
	currentSize = size;
	[[NSNotificationCenter defaultCenter] postNotificationName:NhTextSizeDidChangeNotification object:nil];
}

CGFloat NhScaledFontSize(CGFloat size)
{
	return round(size * currentSize / NhDefaultTextSize);
}

NSFont * NhScaledFont(NSFont * font)
{
	return [NSFont fontWithDescriptor:font.fontDescriptor size:NhScaledFontSize(font.pointSize)];
}

CGFloat NhLineHeight(NSFont * font)
{
	return ceil(font.ascender - font.descender + font.leading);
}
