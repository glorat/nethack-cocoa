/*
 *  wincocoa.m
 *  NetHackCocoa
 *
 *  Created by dirk on 6/26/09.
 *  Copyright 2010 Dirk Zimmermann. All rights reserved.
 *
 */

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

#include <stdio.h>
#include <fcntl.h>
#import "NetHackCocoaAppDelegate.h"
#import "KeyEvent.h"

#include "hack.h"
#include "func_tab.h"

#import "wincocoa.h"
#import "NhWindow.h"
#import "NhMapWindow.h"
#import "MainWindowController.h"
#import "NhYnQuestion.h"
#import "YesNoWindowController.h"
#import "NhEvent.h"
#import "NhEventQueue.h"
#import "NhItem.h"
#import "NhItemGroup.h"
#import "NhMenuWindow.h"
#import "NhStatus.h"
#import "NSString+Z.h"
#import "NhTextInputEvent.h"
#import "PlayerName.h"

#ifdef __APPLE__
#include "TargetConditionals.h"
#endif

// mainly for tty port implementation
#define BASE_WINDOW ((winid) [NhWindow messageWindow])

#define kNetHackOptions (@"kNetHackOptions")

struct window_procs cocoa_procs = {
"cocoa",
wp_cocoa,
WC_COLOR|WC_HILITE_PET|WC_INVERSE|
WC_ASCII_MAP|WC_TILED_MAP|
WC_FONT_MAP|WC_TILE_FILE|WC_TILE_WIDTH|WC_TILE_HEIGHT|
WC_PLAYER_SELECTION|WC_SPLASH_SCREEN,
WC2_FLUSH_STATUS,
{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},   /* color availability */
cocoa_init_nhwindows,
cocoa_player_selection,
cocoa_askname,
cocoa_get_nh_event,
cocoa_exit_nhwindows,
cocoa_suspend_nhwindows,
cocoa_resume_nhwindows,
cocoa_create_nhwindow,
cocoa_clear_nhwindow,
cocoa_display_nhwindow,
cocoa_destroy_nhwindow,
cocoa_curs,
cocoa_putstr,
cocoa_putmixed,
cocoa_display_file,
cocoa_start_menu,
cocoa_add_menu,
cocoa_end_menu,
cocoa_select_menu,
genl_message_menu,
cocoa_mark_synch,
cocoa_wait_synch,
#ifdef CLIPPING
cocoa_cliparound,
#endif
#ifdef POSITIONBAR
donull,
#endif
cocoa_print_glyph,
cocoa_raw_print,
cocoa_raw_print_bold,
cocoa_nhgetch,
cocoa_nh_poskey,
cocoa_nhbell,
cocoa_doprev_message,
cocoa_yn_function,
cocoa_getlin,
cocoa_get_ext_cmd,
cocoa_number_pad,
cocoa_delay_output,
cocoa_outrip,
cocoa_preference_update,
cocoa_getmsghistory,
cocoa_putmsghistory,
cocoa_status_init,
cocoa_status_finish,
cocoa_status_enablefield,
cocoa_status_update,
win_can_suspend,
cocoa_update_inventory,
cocoa_ctrl_nhwindow,
};


static char s_baseFilePath[FQN_MAX_FILENAME];

coord CoordMake(coordxy i, coordxy j) {
	coord c = {i,j};
	return c;
}

@implementation WinCocoa

static NSMutableDictionary<NSNumber *,NhWindow *>	* g_WindowDict;

+ (void)load
{
	g_WindowDict = [NSMutableDictionary new];

	strcpy(s_baseFilePath, [[[NSBundle mainBundle] resourcePath] cStringUsingEncoding:NSASCIIStringEncoding]);

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *netHackOptions = [defaults stringForKey:kNetHackOptions];
	if ( netHackOptions ) {
		setenv("NETHACKOPTIONS", [netHackOptions cStringUsingEncoding:NSASCIIStringEncoding], 1);
	}
}

+ (const char *)baseFilePath
{
	return s_baseFilePath;
}

+ (void)expandFilename:(const char *)filename intoPath:(char *)path
{
	sprintf(path, "%s/%s", [self baseFilePath], filename);
}

+ (int)keyWithKeyEvent:(NSEvent *)keyEvent
{
	return NhKeyFromEvent(keyEvent, gc.Cmd.dirchars);
}

@end

const char *cocoa_resource_dir(void)
{
	return s_baseFilePath;
}

// These must be defined but are not used (they handle keyboard interrupts).
void intron() {}
void introff() {}

int dosuspend()
{
	NSLog(@"dosuspend");
	return 0;
}

void error(const char *s, ...)
{
	//NSLog(@"error: %s");
	char message[512];
	va_list ap;
	va_start(ap, s);
	vsprintf(message, s, ap);
	va_end(ap);
	cocoa_raw_print(message);
	// todo (button to wait for user?)
	exit(0);
}

void cocoa_prepare_for_exit()
{
	NetHackCocoaAppDelegate * delegate = [[NSApplication sharedApplication] delegate];
	[delegate unlockNethackCore];

	// give UI thread a chance to settle down before we tear down data structures (e.g. inventory)
	for ( int i = 0; i < 100; ++i ) {
		usleep(20);
		dispatch_sync( dispatch_get_main_queue(), ^{});
	}
}

void nethack_exit(int status)
{
	//	indicate were exiting
	[[MainWindowController instance] nethackExited];

	cocoa_prepare_for_exit();

	// exit thread
	[NSThread exit];
}

#if 0
void cocoa_decgraphics_mode_callback()
{
	// user tried to switch to DECgraphics, so switch them to IBM instead
	switch_graphics( IBM_GRAPHICS );	
}
#endif

#pragma mark nethack window API

// the first matching rule wins, so the player's own rules go ahead of these
static void AddDefaultMenuColors(void)
{
	static const char * rules[] = {
		"\" blessed \"=green",
		"\" holy water\"=green",
		"\" cursed \"=red",
		"\" unholy water\"=red",
	};
	struct menucoloring * players = gm.menu_colorings;
	gm.menu_colorings = NULL;
	for ( int i = 0; i < SIZE(rules); ++i ) {
		char rule[BUFSZ];
		Strcpy(rule, rules[i]);
		(void) add_menu_coloring(rule);
	}
	if ( players ) {
		struct menucoloring * last = players;
		while ( last->next )
			last = last->next;
		last->next = gm.menu_colorings;
		gm.menu_colorings = players;
	}
	iflags.use_menu_color = TRUE;
}

void cocoa_init_nhwindows(int* argc, char** argv)
{
	//NSLog(@"init_nhwindows");
	flags.runmode = RUN_STEP;
	iflags.window_inited = TRUE;
	iflags.toptenwin = TRUE;
	iflags.menu_tab_sep = TRUE;
	// tiles with transparent backgrounds are drawn over the floor beneath them
	iflags.use_background_glyph = TRUE;
	// the inventory sidebar lists gold too, like the 'i' menu
	if ( iflags.perminv_mode == InvOptNone )
		iflags.perminv_mode = InvOptFull;
	
	// default ASCII mode is to use IBM graphics with color
	iflags.use_color = TRUE;
#if 0
	switch_graphics(IBM_GRAPHICS);
#endif

#if 0
	// if user switches to DEC graphics don't let them
	extern void NDECL((*decgraphics_mode_callback));
	decgraphics_mode_callback = cocoa_decgraphics_mode_callback;
#endif

	// hardwire OPTIONS=time,showexp for issue 8
	flags.time = TRUE;
	flags.showexp = TRUE;

	iflags.hilite_pet = TRUE;
	iflags.hilite_pile = TRUE;
	AddDefaultMenuColors();
	
	[[MainWindowController instance] initWindows];
}

void cocoa_askname(void)
{
	//NSLog(@"askname");
	char typed[BUFSZ];
	do {
		cocoa_getlin("Who are you?", typed);
		if ( typed[0] == '\033' ) {
			cocoa_exit_nhwindows("Until next time then...");
			nh_terminate(EXIT_SUCCESS);
		}
	} while ( !NhPlayerName(typed, svp.plname, sizeof svp.plname) );
}

void cocoa_get_nh_event()
{
	//NSLog(@"get_nh_event");
}

void cocoa_exit_nhwindows(const char *str) {
	if ( str ) {
		cocoa_raw_print( str );

		// string is only set during user save, which means user wants to exit
		[[MainWindowController instance] setTerminatedByUser:YES];
	}
}

void cocoa_suspend_nhwindows(const char *str)
{
	NSLog(@"suspend_nhwindows %s", str);
}

void cocoa_resume_nhwindows()
{
	NSLog(@"resume_nhwindows");
}

winid cocoa_create_nhwindow(int type)
{
	static int wid_index = 1;
	NhWindow *w = nil;
	switch (type) {
		case NHW_MAP:
			w =  [NhWindow mapWindow];
			break;
		case NHW_STATUS:
			w = [[NhWindow alloc] initWithType:NHW_STATUS];
			break;
		case NHW_MESSAGE:
			w = [NhWindow messageWindow];
			break;
		case NHW_MENU:
			w = [[NhMenuWindow alloc] initWithType:NHW_MENU];
			break;
		case NHW_TEXT:
			w = [[NhWindow alloc] initWithType:NHW_TEXT];
			break;
		default:
			assert(NO);
	}
	g_WindowDict[@(wid_index)] = w;
//	NSLog(@"create_nhwindow(%x) %x = %p", type, wid_index, w);

	return wid_index++;
}

void cocoa_clear_nhwindow(winid wid)
{
	//NSLog(@"clear_nhwindow %x", wid);
	NhWindow * win = g_WindowDict[@(wid)];
	[win clear];
}

void cocoa_display_nhwindow(winid wid, boolean block)
{
	//NSLog(@"display_nhwindow %x, %i, %i", wid, ((NhWindow *) wid).type, block);
	NhWindow * win = g_WindowDict[@(wid)];
	win.blocking = block;
	[[MainWindowController instance] displayWindow:win];
}

void cocoa_destroy_nhwindow(winid wid)
{
	NhWindow * win = g_WindowDict[@(wid)];
//	NSLog(@"destroy_nhwindow %x = %p", wid, win);
	if (win != [NhWindow messageWindow] && win != [NhWindow mapWindow]) {
		[g_WindowDict removeObjectForKey:@(wid)];
	}
}

void cocoa_curs(winid wid, int x, int y)
{
	//NSLog(@"curs %x %d,%d", wid, x, y);

	if (wid == WIN_MAP) {
		NhMapWindow * win = (NhMapWindow *) g_WindowDict[@(wid)];
		[win setCursX:x y:y];
	}
}

void cocoa_putstr(winid wid, int attr, const char *text)
{
	//NSLog(@"putstr %x %s", wid, text);
	if (wid == WIN_ERR || !wid) {
		wid = BASE_WINDOW;
	}
	// normal output to a window
	NhWindow * win = g_WindowDict[@(wid)];
	[win print:text attr:attr];
	if (wid == WIN_MESSAGE || wid == BASE_WINDOW) {
		[[MainWindowController instance] refreshMessages];
	}
}

void cocoa_putmixed(winid wid, int attr, const char *text)
{
	genl_putmixed(wid, attr, text);
}

void cocoa_display_file(const char *filename, boolean must_exist)
{
	char tmp[ PATH_MAX ];
	[WinCocoa expandFilename:filename intoPath:tmp];

	NSString * text = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:tmp] encoding:NSUTF8StringEncoding error:NULL];
	if ( text ) {
		[[MainWindowController instance] displayMessageWindow:text];
	} else {
		if ( must_exist ) {
			char msg[512];
			sprintf(msg, "Could not display file %s", filename);
			cocoa_raw_print(msg);
		}
	}
}

#pragma mark menu

void cocoa_start_menu(winid wid, unsigned long mbehavior)
{
	//NSLog(@"start_menu %x", wid);
	NhMenuWindow * win = (NhMenuWindow *) g_WindowDict[@(wid)];
	[win startMenu];
}

void cocoa_add_menu(winid wid, const glyph_info *glyphinfo, const ANY_P *identifier,
					char accelerator, char group_accel, int attr, int clr,
					const char *str, unsigned int itemflags)
{
	int glyph = glyphinfo ? glyphinfo->glyph : NO_GLYPH;
	BOOL presel = (itemflags & MENU_ITEMFLAGS_SELECTED) != 0;
	//NSLog(@"add_menu %x %s", wid, str);
	NhMenuWindow * win = (NhMenuWindow *) g_WindowDict[@(wid)];

	NSString *title = [NSString stringWithFormat:@"%s", str];
	if (identifier->a_void) {
		NhItem *i = [[NhItem alloc] initWithTitle:title
									   identifier:*identifier accelerator:accelerator group_accel:group_accel glyph:glyph selected:presel];
		i.color = clr;
		i.attr = attr;
		[win.currentItemGroup addItem:i];
	} else {
		NhItemGroup *g = [[NhItemGroup alloc] initWithTitle:title];
		g.attr = attr;
		g.color = clr;
		[win addItemGroup:g];
	}
}

void cocoa_end_menu(winid wid, const char *prompt)
{
	//NSLog(@"end_menu %x, %s", wid, prompt);
	NhMenuWindow * win = (NhMenuWindow *) g_WindowDict[@(wid)];
	if (prompt) {
		win.prompt = [NSString stringWithFormat:@"%s", prompt];
		//cocoa_putstr(WIN_MESSAGE, 0, prompt);
	} else {
		win.prompt = nil;
	}
}

// With force_invmenu the item prompt offers only likely items, but at the
// old text prompt any inventory letter could be typed; keep allowing that.
static NSArray<NhItem *> * UnlistedInventory(NhMenuWindow * win)
{
	NSMutableSet<NSNumber *> * listed = [NSMutableSet set];
	BOOL isItemPrompt = NO;
	for ( NhItemGroup * g in win.itemGroups ) {
		for ( NhItem * item in g.items ) {
			[listed addObject:@(item.inventoryLetter)];
			if ( item.identifier.a_char == '*' && [item.title hasPrefix:@"(list everything)"] )
				isItemPrompt = YES;
		}
	}
	if ( !isItemPrompt )
		return nil;
	NSMutableArray * unlisted = [NSMutableArray array];
	for ( struct obj * otmp = gi.invent; otmp; otmp = otmp->nobj ) {
		if ( [listed containsObject:@(otmp->invlet)] )
			continue;
		anything any = cg.zeroany;
		any.a_char = otmp->invlet;
		[unlisted addObject:[[NhItem alloc] initWithTitle:[NSString stringWithFormat:@"%c", otmp->invlet] identifier:any accelerator:otmp->invlet group_accel:0 glyph:NO_GLYPH selected:NO]];
	}
	return unlisted;
}

static BOOL s_buildingSidebar = NO;
static void RefreshPeacefulMarks(void);

int cocoa_select_menu(winid wid, int how, menu_item **selected)
{
	//NSLog(@"select_menu %x", wid);
	NhMenuWindow * win = (NhMenuWindow *) g_WindowDict[@(wid)];

	*selected = NULL;
	if ( s_buildingSidebar && wid == WIN_INVEN ) {
		[[MainWindowController instance] setInventoryGroups:[win.itemGroups copy]];
		return 0;
	}
	RefreshPeacefulMarks();
	NhEvent * next = [[NhEventQueue instance] peek];
	if ( how == PICK_ONE && [next isKindOfClass:[NhMenuPickEvent class]] ) {
		[[NhEventQueue instance] nextEvent];
		for ( NhItemGroup * g in win.itemGroups ) {
			for ( NhItem * item in g.items ) {
				if ( item.inventoryLetter == ((NhMenuPickEvent *)next).letter ) {
					*selected = calloc(1, sizeof(menu_item));
					(*selected)->item = item.identifier;
					(*selected)->count = -1;
					return 1;
				}
			}
		}
		return -1;
	}

	win.how = how;
	if ( how == PICK_ONE )
		win.unlistedItems = UnlistedInventory(win);
	// pick menus wait for their answer in nextEvent; PICK_NONE has none to wait for
	win.blocking = (how == PICK_NONE);
	[[MainWindowController instance] showMenuWindow:win];
	
	if ( how != PICK_NONE ) {
		NhEvent *e = [[NhEventQueue instance] nextEvent];
		if (e.key > 0) {
			menu_item *pMenu = *selected = calloc(sizeof(menu_item), win.selected.count);
			for (NhItem *item in win.selected) {
				pMenu->count = item.amount;
				pMenu->item = item.identifier;
				pMenu++;
			}
			return win.selected.count;
		} else {
			// cancelled
			return -1;
		}
	} else {
		return 0;
	}
}

void cocoa_update_inventory(int arg)
{
	//NSLog(@"update_inventory");
	// build the sidebar's list the way the core builds a persistent inventory
	if ( WIN_INVEN != WIN_ERR && !program_state.gameover && !s_buildingSidebar ) {
		s_buildingSidebar = YES;
		(void) display_inventory((char *) 0, FALSE);
		s_buildingSidebar = NO;
	}
	[[MainWindowController instance] updateInventory];
}

#pragma mark status

static NhStatus * s_status;
// starting gear changes AC and stats before the first turn
static BOOL s_showChanges;

void cocoa_status_init(void)
{
	s_status = [[NhStatus alloc] init];
	s_showChanges = NO;
}

void cocoa_status_finish(void)
{
	s_status = nil;
}

void cocoa_status_enablefield(int fld, const char *nm, const char *fmt, boolean enable)
{
	[s_status setEnabled:enable forField:fld];
}

static NSString * LevelText(NSString * desc)
{
	NSString * dungeon = @(svd.dungeons[u.uz.dnum].dname);
	if ( ![desc hasPrefix:@"Dlvl:"] )
		return [NSString stringWithFormat:@"%@: %@", dungeon, desc];
	NSString * depth = [[desc substringFromIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	int lvl = dunlev(&u.uz);
	if ( lvl == depth.integerValue )
		return [NSString stringWithFormat:@"%@: level %@", dungeon, depth];
	return [NSString stringWithFormat:@"%@ %d: level %@", dungeon, lvl, depth];
}

static NSString * RoleText(NSString * alignment)
{
	return [NSString stringWithFormat:Upolyd ? @"%@ (%s) %s" : @"%@ %s %s",
			alignment ?: @"", gu.urace.adj, pmname(&mons[u.umonnum], Ugender)];
}

// mirrors the core's major_troubles, minor_troubles and movement condition groups
#define MAJOR_TROUBLES (BL_MASK_FOODPOIS | BL_MASK_GRAB | BL_MASK_INLAVA | BL_MASK_SLIME \
						| BL_MASK_STONE | BL_MASK_STRNGL | BL_MASK_TERMILL)
#define MINOR_TROUBLES (BL_MASK_BLIND | BL_MASK_CONF | BL_MASK_DEAF | BL_MASK_HALLU \
						| BL_MASK_PARLYZ | BL_MASK_SUBMERGED | BL_MASK_STUN)
#define MOVEMENT (BL_MASK_LEV | BL_MASK_FLY | BL_MASK_RIDE)

static NSArray<NhStatusBadge *> * StatusBadges(NSString * hunger, NSString * encumbrance, unsigned long active)
{
	NSMutableArray * badges = [NSMutableArray array];
	if ( hunger.length ) {
		NhSeverity severity = u.uhs == SATIATED ? NhSeverityInfo
			: u.uhs == HUNGRY ? NhSeverityCaution
			: u.uhs == WEAK ? NhSeverityWarning
			: NhSeverityDanger;
		[badges addObject:[NhStatusBadge badgeWithText:hunger severity:severity]];
	}
	if ( encumbrance.length ) {
		int cap = near_capacity();
		NhSeverity severity = cap == SLT_ENCUMBER ? NhSeverityCaution
			: cap == MOD_ENCUMBER ? NhSeverityWarning
			: NhSeverityDanger;
		[badges addObject:[NhStatusBadge badgeWithText:encumbrance severity:severity]];
	}
	for ( int i = 0; i < CONDITION_COUNT; ++i ) {
		const struct conditions_t * condition = &conditions[cond_idx[i]];
		if ( !(active & condition->mask) )
			continue;
		NhSeverity severity = (condition->mask & MAJOR_TROUBLES) ? NhSeverityDanger
			: (condition->mask & MINOR_TROUBLES) ? NhSeverityWarning
			: (condition->mask & MOVEMENT) ? NhSeverityInfo
			: NhSeverityCaution;
		[badges addObject:[NhStatusBadge badgeWithText:@(condition->text[0]) severity:severity]];
	}
	return badges;
}

void cocoa_status_update(int fld, genericptr_t ptr, int chg, int percent, int color, unsigned long *colormasks)
{
	static unsigned long s_conditions;
	NSCharacterSet * whitespace = [NSCharacterSet whitespaceCharacterSet];

	s_status.turn = svm.moves;
	if ( fld == BL_FLUSH || fld == BL_RESET ) {
		s_status.levelText = LevelText([s_status valueForField:BL_LEVELDESC] ?: @"");
		s_status.roleText = RoleText([s_status valueForField:BL_ALIGN]);
		s_status.badges = StatusBadges([s_status valueForField:BL_HUNGER], [s_status valueForField:BL_CAP], s_conditions);
		[[MainWindowController instance] updateStatus:[s_status copy]];
		if ( program_state.in_moveloop )
			s_showChanges = YES;
		return;
	}
	if ( fld < 0 || fld >= MAXBLSTATS || !ptr )
		return;
	if ( fld == BL_CONDITION ) {
		s_conditions = *(unsigned long *) ptr;
		return;
	}
	NSString * value = [[NSString stringWithCString:(const char *) ptr encoding:NSISOLatin1StringEncoding] stringByTrimmingCharactersInSet:whitespace];
	// gold comes with its symbol in front: "$:12"
	if ( fld == BL_GOLD )
		value = [value componentsSeparatedByString:@":"].lastObject;
	[s_status setValue:value forField:fld];

	switch ( fld ) {
		case BL_STR: case BL_DX: case BL_CO: case BL_IN: case BL_WI: case BL_CH:
		case BL_XP: case BL_HD:
			if ( s_showChanges && chg )
				[s_status noteChange:chg improved:chg > 0 forField:fld];
			break;
		case BL_AC:
			if ( s_showChanges && chg )
				[s_status noteChange:chg improved:chg < 0 forField:fld];
			break;
	}
}

void cocoa_mark_synch()
{
	//NSLog(@"mark_synch");
}

void cocoa_wait_synch()
{
	NSLog(@"wait_synch");
//	[[MainViewController instance] refreshAllViews];
}

void cocoa_cliparound(int x, int y)
{
	//NSLog(@"cliparound %d,%d", x, y);
	cocoa_cliparound_window(NHW_MAP, x, y);
}

void cocoa_cliparound_window(winid wid, int x, int y)
{
	//	NSLog(@"cliparound_window %x %d,%d", wid, x, y);
	if (wid == NHW_MAP) {
		[[MainWindowController instance] clipAroundX:x y:y];
	}
}

// the core has no glyph flag for peaceful monsters
static BOOL ShowsPeacefulMonster(coordxy x, coordxy y, int glyph)
{
	if ( Hallucination || !glyph_is_monster(glyph) || glyph_is_pet(glyph) || glyph_is_ridden_monster(glyph) )
		return NO;
	struct monst * mtmp = m_at(x, y);
	int shown = glyph_to_mon(glyph);
	return mtmp && mtmp->mpeaceful && !mtmp->mtame && M_AP_TYPE(mtmp) == M_AP_NOTHING
		&& (monsndx(mtmp->data) == shown || (shown == PM_LONG_WORM_TAIL && mtmp->data == &mons[PM_LONG_WORM]))
		&& canspotmon(mtmp);
}

void cocoa_print_glyph(winid wid, coordxy x, coordxy y, const glyph_info *glyphinfo,
					   const glyph_info *bkglyphinfo)
{
	int glyph = glyphinfo->glyph;
	int bkglyph = bkglyphinfo ? bkglyphinfo->glyph : GLYPH_UNEXPLORED;
	//NSLog(@"print_glyph %x %d,%d", wid, x, y);
	NhMapWindow * win = (NhMapWindow *) g_WindowDict[@(wid)];
	unsigned flags = glyphinfo->gm.glyphflags;
	if ( ShowsPeacefulMonster(x, y, glyph) )
		flags |= kMapPeaceful;
	[win printGlyph:glyph background:bkglyph flags:flags atX:x y:y];
}

// a monster can be angered or pacified without being redrawn
static void RefreshPeacefulMarks(void)
{
	if ( !program_state.in_moveloop || program_state.gameover )
		return;
	NhMapWindow * map = (NhMapWindow *) [NhWindow mapWindow];
	BOOL changed = NO;
	for ( coordxy y = 0; y < ROWNO; ++y ) {
		for ( coordxy x = 1; x < COLNO; ++x ) {
			int glyph = [map glyphAtX:x y:y];
			if ( glyph == kNoGlyph )
				continue;
			BOOL peaceful = ShowsPeacefulMonster(x, y, glyph);
			if ( peaceful != (([map flagsAtX:x y:y] & kMapPeaceful) != 0) ) {
				[map setPeaceful:peaceful atX:x y:y];
				changed = YES;
			}
		}
	}
	if ( changed )
		cocoa_display_nhwindow(WIN_MAP, FALSE);
}

void cocoa_raw_print(const char *str)
{
#ifdef DEBUG
	NSLog(@"%s",str);
#endif
	//NSLog(@"raw_print %s", str);
	cocoa_putstr((winid) [NhWindow messageWindow], 0, str);
}

void cocoa_raw_print_bold(const char *str)
{
	//NSLog(@"raw_print_bold %s", str);
	cocoa_raw_print(str);
}

int cocoa_nhgetch(void)
{
	RefreshPeacefulMarks();
	[[MainWindowController instance] refreshAllViews];
	for (;;) {
		NhEvent *e = [[NhEventQueue instance] nextEvent];
		if (e.isKeyEvent)
			return e.key;
	}
}

int cocoa_nh_poskey(coordxy *x, coordxy *y, int *mod)
{
	static BOOL s_inventoryShown = NO;

	//NSLog(@"nh_poskey");
	// the core only reports inventory changes made inside the game loop,
	// so the starting inventory has to be picked up here
	if (!s_inventoryShown && program_state.in_moveloop) {
		s_inventoryShown = YES;
		cocoa_update_inventory(0);
		[[MainWindowController instance] updateWizardMenu];
	}
	RefreshPeacefulMarks();
	[[MainWindowController instance] refreshAllViews];
	NhEvent *e;
	do {
		e = [[NhEventQueue instance] nextEvent];
	} while ( [e isKindOfClass:[NhMenuPickEvent class]] );
	if (!e.isKeyEvent) {
		*x = e.x;
		*y = e.y;
		*mod = e.mod;
	}
	return e.key;
}

void cocoa_nhbell()
{
	NSLog(@"nhbell");
	NSBeep();
}

int cocoa_doprev_message()
{
	NSLog(@"doprev_message");
	return 0;
}

#pragma mark yn_function 

char cocoa_yn_function(const char *question, const char *choices, char def)
{
	//NSLog(@"yn_function %s", question);
	static const char * AlwaysYes[] = {
		"Really save?",
		"Overwrite the old file?",
		//		"Do you want to keep the save file?",
	};
	for ( int i = 0; i < sizeof AlwaysYes/sizeof AlwaysYes[0]; ++i ) {
		if ( !strcmp(AlwaysYes[i], question) ) {
			return 'y';
		}
	}
	
	RefreshPeacefulMarks();
	yn_number = 0;
	NSString * text = [NSString stringWithFormat:@"%s", question];
	if ( choices && choices[0] ) {
		NSString * shown = [[NSString stringWithCString:choices encoding:NSASCIIStringEncoding] componentsSeparatedByString:@"\033"].firstObject;
		text = [text stringByAppendingFormat:@" [%@]", shown];
	}
	if ( def ) {
		text = [text stringByAppendingFormat:@" (%c)", def];
	}
	
	if ( [text containsString:@"direction"] ) {
		if ( ![[NhEventQueue instance] peek] )
			[[MainWindowController instance] showDirectionWithPrompt:text];
		NhEvent * e = [[NhEventQueue instance] nextEvent];
		return e.key;
	}
	
	if ( [YesNoWindowController canAskWithChoices:choices] ) {
		NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:question choices:choices default:def];
		[[MainWindowController instance] showYnQuestion:q];
		char key = [[NhEventQueue instance] nextEvent].key;
		char answer[QBUFSZ];
		if ( key == '#' ) {
			yn_number = q.count;
			Sprintf(answer, "#%ld", yn_number);
		} else {
			(void) key2txt((uchar) key, answer);
		}
		cocoa_putstr(WIN_MESSAGE, 0, [[text stringByAppendingFormat:@" %s", answer] UTF8String]);
		return key;
	}
	
	cocoa_putstr(WIN_MESSAGE, ATR_BOLD, [text UTF8String] );
	for (;;) {
		NhEvent *e = nil;
		e = [[NhEventQueue instance] nextEvent];
		if ( e.isKeyEvent ) {
			if ( choices == NULL || strchr( choices, e.key ) != NULL ) {
				return e.key;
			}
			if ( def && e.key == '\r' )
				return def;
		}
	}
}

void cocoa_getlin(const char *prompt, char *line)
{
	//NSLog(@"getlin %s", prompt);
	RefreshPeacefulMarks();
	[[MainWindowController instance] refreshAllViews];
	[[MainWindowController instance] getLineWithPrompt:[NSString stringWithCString:prompt encoding:NSISOLatin1StringEncoding]];
	// keys typed before the window opened can't be the answer
	NhEvent * e;
	do {
		e = [[NhEventQueue instance] nextEvent];
	} while ( ![e isKindOfClass:[NhTextInputEvent class]] );
	NSData * text = [((NhTextInputEvent *)e).text dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	size_t n = MIN(text.length, BUFSZ - 1);
	memcpy(line, text.bytes, n);
	line[n] = '\0';
	char logged[BUFSZ * 2];
	snprintf(logged, sizeof logged, "%s %s", prompt, line[0] == '\033' ? "" : line);
	cocoa_putstr(WIN_MESSAGE, 0, logged);
}

int cocoa_get_ext_cmd()
{
	//NSLog(@"get_ext_cmd");
	RefreshPeacefulMarks();
	// a menu item queues its command name after the '#'; otherwise ask
	if ( ![[[NhEventQueue instance] peek] isKindOfClass:[NhTextInputEvent class]] )
		[[MainWindowController instance] showExtendedCommands];
	// keys typed before the window opened can't be the answer
	NhEvent * e;
	do {
		e = [[NhEventQueue instance] nextEvent];
	} while ( ![e isKindOfClass:[NhTextInputEvent class]] );
	const char * cmd = [((NhTextInputEvent *)e).text UTF8String];
		
	if ( !*cmd )
		return -1;
	int * matches;
	if ( extcmds_match(cmd, ECM_IGNOREAC | ECM_EXACTMATCH, &matches) == 1 )
		return matches[0];
	pline("%s%.60s: unknown extended command.", visctrl(extcmd_initiator()), cmd);
	return -1;
}

void cocoa_number_pad(int num)
{
	//NSLog(@"number_pad %d", num);
}

void cocoa_delay_output()
{
	//NSLog(@"delay_output");
	usleep(50000);
}

void cocoa_outrip(winid wid, int how, time_t when)
{
	NSLog(@"outrip %lx", wid);
}


void cocoa_preference_update(const char * pref)
{
	[[MainWindowController instance] preferenceUpdate:[NSString stringWithUTF8String:pref]];
}

char *cocoa_getmsghistory(boolean init)
{
	// return messages oldest to newest
	return NULL;
}
void cocoa_putmsghistory(const char * msg, boolean is_restoring)
{
}
boolean win_can_suspend(void)
{
	return YES;
}

win_request_info *cocoa_ctrl_nhwindow(winid wid, int request, win_request_info *wri)
{
	return NULL;
}


#pragma mark window API player_selection()


// from tty port
void cocoa_player_selection(void)
{
	int ro = flags.initrole, ra = flags.initrace, g = flags.initgend, a = flags.initalign;

	// fully specified via options (e.g. NETHACKOPTIONS): no dialog, like the other ports
	if (ro >= 0 && ra >= 0 && g >= 0 && a >= 0
		&& validrole(ro) && validrace(ro, ra) && validgend(ro, ra, g) && validalign(ro, ra, a))
		return;
	[[MainWindowController instance] showPlayerSelection];
}
