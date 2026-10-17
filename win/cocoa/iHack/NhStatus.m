//
//  NhStatus.m
//  NetHack
//

#import "NhStatus.h"

@implementation NhStatusBadge

+ (instancetype)badgeWithText:(NSString *)text severity:(NhSeverity)severity
{
	NhStatusBadge * badge = [[self alloc] init];
	badge->_text = [text copy];
	badge->_severity = severity;
	return badge;
}

@end

@implementation NhStatus
{
	NSMutableDictionary<NSNumber *, NSString *> *	values;
	NSMutableIndexSet *	enabled;
}

- (instancetype)init
{
	if ( self = [super init] ) {
		values = [NSMutableDictionary dictionary];
		enabled = [NSMutableIndexSet indexSet];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	NhStatus * copy = [[NhStatus alloc] init];
	copy->values = [values mutableCopy];
	copy->enabled = [enabled mutableCopy];
	copy.levelText = self.levelText;
	copy.roleText = self.roleText;
	copy.badges = self.badges;
	return copy;
}

- (void)setValue:(NSString *)value forField:(int)field
{
	values[@(field)] = value;
}

- (NSString *)valueForField:(int)field
{
	return [enabled containsIndex:field] ? values[@(field)] : nil;
}

- (void)setEnabled:(BOOL)enable forField:(int)field
{
	if ( enable )
		[enabled addIndex:field];
	else
		[enabled removeIndex:field];
}

@end
