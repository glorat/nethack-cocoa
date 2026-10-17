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

// matches the core's default for statushilites
static const long kChangeTurns = 3;

@interface NhStatusChange : NSObject
@property (nonatomic, assign) int change;
@property (nonatomic, assign) BOOL improved;
@property (nonatomic, assign) long turn;
@end

@implementation NhStatusChange
@end

@implementation NhStatus
{
	NSMutableDictionary<NSNumber *, NSString *> *	values;
	NSMutableIndexSet *	enabled;
	NSMutableDictionary<NSNumber *, NhStatusChange *> *	changes;
}

- (instancetype)init
{
	if ( self = [super init] ) {
		values = [NSMutableDictionary dictionary];
		enabled = [NSMutableIndexSet indexSet];
		changes = [NSMutableDictionary dictionary];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	NhStatus * copy = [[NhStatus alloc] init];
	copy->values = [values mutableCopy];
	copy->enabled = [enabled mutableCopy];
	copy->changes = [changes mutableCopy];
	copy.turn = self.turn;
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

- (void)noteChange:(int)change improved:(BOOL)improved forField:(int)field
{
	NhStatusChange * noted = [[NhStatusChange alloc] init];
	noted.change = change;
	noted.improved = improved;
	noted.turn = self.turn;
	changes[@(field)] = noted;
}

- (int)changeForField:(int)field improved:(BOOL *)improved
{
	NhStatusChange * noted = changes[@(field)];
	if ( !noted || self.turn - noted.turn >= kChangeTurns || ![enabled containsIndex:field] )
		return 0;
	if ( improved )
		*improved = noted.improved;
	return noted.change;
}

- (void)setEnabled:(BOOL)enable forField:(int)field
{
	if ( enable )
		[enabled addIndex:field];
	else
		[enabled removeIndex:field];
}

@end
