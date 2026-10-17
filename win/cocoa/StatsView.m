//
//  StatsView.m
//  NetHackCocoa
//
//  Created by Bryce on 2/25/10.
//  Copyright 2010 Bryce Cogswell. All rights reserved.
//

/*
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation, version 2
 of the License.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#import "StatsView.h"
#import "NhStatus.h"

#import "hack.h"


@interface StatusBadgeView : NSView
- (instancetype)initWithBadge:(NhStatusBadge *)badge;
@end

@implementation StatusBadgeView
{
	NhStatusBadge	*	badge;
	NSDictionary	*	attributes;
}

static const CGFloat kBadgePadding = 6.0;

- (instancetype)initWithBadge:(NhStatusBadge *)b
{
	if ( self = [super initWithFrame:NSZeroRect] ) {
		badge = b;
		NSColor * text = b.severity == NhSeverityInfo ? [NSColor labelColor]
			: b.severity == NhSeverityCaution ? [NSColor blackColor]
			: [NSColor whiteColor];
		attributes = @{ NSFontAttributeName : [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold],
						NSForegroundColorAttributeName : text };
		self.translatesAutoresizingMaskIntoConstraints = NO;
		self.toolTip = b.text;
	}
	return self;
}

- (NSSize)intrinsicContentSize
{
	NSSize text = [badge.text sizeWithAttributes:attributes];
	return NSMakeSize(ceil(text.width) + 2 * kBadgePadding, ceil(text.height) + 2);
}

- (void)drawRect:(NSRect)dirtyRect
{
	NSColor * fill = badge.severity == NhSeverityDanger ? [NSColor systemRedColor]
		: badge.severity == NhSeverityWarning ? [NSColor systemOrangeColor]
		: badge.severity == NhSeverityCaution ? [NSColor systemYellowColor]
		: [NSColor quaternaryLabelColor];
	[fill setFill];
	CGFloat radius = self.bounds.size.height / 2;
	[[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:radius yRadius:radius] fill];
	NSSize text = [badge.text sizeWithAttributes:attributes];
	[badge.text drawAtPoint:NSMakePoint(kBadgePadding, round((self.bounds.size.height - text.height) / 2)) withAttributes:attributes];
}

@end


@implementation StatsView
{
	NSStackView	*	badges;
	NSMutableDictionary<NSNumber *, NSTextField *> *	changeMarks;
}


- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

-(void)clearAll
{
	NSString * clear = @"";
	[name 	setStringValue:clear];
	[role	setStringValue:clear];
	[dlvl	setStringValue:clear];
	[hp		setStringValue:clear];
	[pw		setStringValue:clear];
	[level	setStringValue:clear];
	[ac		setStringValue:clear];
	[xp		setStringValue:clear];
	[gold	setStringValue:clear];
	[str	setStringValue:clear];
	[iq		setStringValue:clear];
	[dex	setStringValue:clear];
	[wis	setStringValue:clear];
	[con	setStringValue:clear];
	[cha	setStringValue:clear];
	[turn	setStringValue:clear];
	[state	setStringValue:clear];
}

-(void)awakeFromNib
{
	[self clearAll];

	badges = [[NSStackView alloc] init];
	badges.orientation = NSUserInterfaceLayoutOrientationHorizontal;
	badges.spacing = 4;
	badges.translatesAutoresizingMaskIntoConstraints = NO;
	[badges setClippingResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
	[self addSubview:badges];
	[NSLayoutConstraint activateConstraints:@[
		[badges.leadingAnchor constraintEqualToAnchor:state.leadingAnchor],
		[badges.centerYAnchor constraintEqualToAnchor:state.centerYAnchor],
		[badges.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-8],
	]];
	// keeps its place in the layout for the badges
	state.hidden = YES;

	changeMarks = [NSMutableDictionary dictionary];
}

// drawn in the gap after the value so the grid columns don't shift
-(void)showChange:(int)change improved:(BOOL)improved forField:(int)field after:(NSTextField *)value
{
	NSTextField * mark = changeMarks[@(field)];
	if ( !mark && change ) {
		mark = [NSTextField labelWithString:@""];
		mark.font = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
		mark.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:mark];
		[NSLayoutConstraint activateConstraints:@[
			[mark.leadingAnchor constraintEqualToAnchor:value.trailingAnchor constant:1],
			[mark.firstBaselineAnchor constraintEqualToAnchor:value.firstBaselineAnchor],
		]];
		changeMarks[@(field)] = mark;
	}
	mark.hidden = change == 0;
	mark.stringValue = change > 0 ? @"↑" : @"↓";
	mark.textColor = improved ? [NSColor systemGreenColor] : [NSColor systemRedColor];
}

static void SetMeter(NSLevelIndicator * meter, int current, int maximum)
{
	[meter setMaxValue:maximum];
	[meter setIntValue:current];
	[meter setWarningValue:maximum * 2/3.0];
	[meter setCriticalValue:maximum * 1/3.0];
}

-(void)updateWithStatus:(NhStatus *)status
{
	NSString * (^value)(int) = ^NSString *(int field) {
		return [status valueForField:field] ?: @"";
	};

	[name setStringValue:value(BL_TITLE)];
	[role setStringValue:status.roleText ?: @""];
	[dlvl setStringValue:status.levelText ?: @""];
	[gold setStringValue:value(BL_GOLD)];
	[ac setStringValue:value(BL_AC)];

	[hp setStringValue:[NSString stringWithFormat:@"%@(%@)", value(BL_HP), value(BL_HPMAX)]];
	SetMeter(hpMeter, value(BL_HP).intValue, value(BL_HPMAX).intValue);
	[pw setStringValue:[NSString stringWithFormat:@"%@(%@)", value(BL_ENE), value(BL_ENEMAX)]];
	SetMeter(pwMeter, value(BL_ENE).intValue, value(BL_ENEMAX).intValue);

	if ( [status valueForField:BL_HD] ) {
		[xpLabel setStringValue:@"HD:"];
		[xp setStringValue:value(BL_HD)];
		[level setStringValue:@""];
	} else {
		[xpLabel setStringValue:@"Xp:"];
		[level setStringValue:value(BL_XP)];
		[xp setStringValue:value(BL_EXP)];
	}

	[str setStringValue:value(BL_STR)];
	[dex setStringValue:value(BL_DX)];
	[con setStringValue:value(BL_CO)];
	[iq setStringValue:value(BL_IN)];
	[wis setStringValue:value(BL_WI)];
	[cha setStringValue:value(BL_CH)];
	[turn setStringValue:value(BL_TIME)];
	NSDictionary<NSNumber *, NSTextField *> * values = @{
		@(BL_STR) : str, @(BL_DX) : dex, @(BL_CO) : con, @(BL_IN) : iq, @(BL_WI) : wis, @(BL_CH) : cha,
		@(BL_AC) : ac, @(BL_XP) : level, @(BL_HD) : xp,
	};
	for ( NSNumber * field in values ) {
		BOOL improved = NO;
		int change = [status changeForField:field.intValue improved:&improved];
		[self showChange:change improved:improved forField:field.intValue after:values[field]];
	}

	for ( NSView * view in badges.arrangedSubviews )
		[view removeFromSuperview];
	for ( NhStatusBadge * badge in status.badges )
		[badges addArrangedSubview:[[StatusBadgeView alloc] initWithBadge:badge]];
}

@end
