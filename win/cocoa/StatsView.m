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


@implementation StatsView


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
	[state setStringValue:status.stateText ?: @""];
}

@end
