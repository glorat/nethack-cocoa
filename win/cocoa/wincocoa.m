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
#import <Carbon/Carbon.h>	// key codes

#include "hack.h"
#include "func_tab.h"

#import "wincocoa.h"
#import "NhWindow.h"
#import "NhMapWindow.h"
#import "MainWindowController.h"
#import "NhYnQuestion.h"
#import "NhEvent.h"
#import "NhEventQueue.h"
#import "NhItem.h"
#import "NhItemGroup.h"
#import "NhMenuWindow.h"
#import "NhStatusWindow.h"
#import "NSString+Z.h"
#import "NhTextInputEvent.h"

#ifdef __APPLE__
#include "TargetConditionals.h"
#endif

// mainly for tty port implementation
#define BASE_WINDOW ((winid) [NhWindow messageWindow])

#define kNetHackOptions (@"kNetHackOptions")

struct window_procs cocoa_procs = {
"cocoa",
wp_cocoa,
WC_COLOR|WC_HILITE_PET|
WC_ASCII_MAP|WC_TILED_MAP|
WC_FONT_MAP|WC_TILE_FILE|WC_TILE_WIDTH|WC_TILE_HEIGHT|
WC_PLAYER_SELECTION|WC_SPLASH_SCREEN,
0L,
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
genl_status_init,
genl_status_finish,
genl_status_enablefield,
genl_status_update,
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
	if ( [keyEvent type] != NSEventTypeKeyDown )
		return 0;
		
	int key = 0;
	switch ( [keyEvent keyCode] ) {
			// arrows
		case kVK_LeftArrow:				key = 'h';				break;
		case kVK_RightArrow:			key	= 'l';				break;
		case kVK_DownArrow:				key = 'j';				break;
		case kVK_UpArrow:				key = 'k';				break;
			// keypad
		case kVK_ANSI_Keypad1:			key = 'b';				break;
		case kVK_ANSI_Keypad2:			key = 'j';				break;
		case kVK_ANSI_Keypad3:			key = 'n';				break;
		case kVK_ANSI_Keypad4:			key = 'h';				break;
		case kVK_ANSI_Keypad5:			key = '.';				break;
		case kVK_ANSI_Keypad6:			key = 'l';				break;
		case kVK_ANSI_Keypad7:			key = 'y';				break;
		case kVK_ANSI_Keypad8:			key = 'k';				break;
		case kVK_ANSI_Keypad9:			key = 'u';				break;
			// escape
		case kVK_Escape:				key = '\033';			break;
	}
	if ( key ) {
		NSUInteger modifier = [keyEvent modifierFlags];
		if ( modifier & NSEventModifierFlagShift ) {
			key = toupper(key);
		}
	} else {
		// "real" keys
		NSString * chars = [keyEvent charactersIgnoringModifiers];
		NSUInteger modifier = [keyEvent modifierFlags];
		key = [chars characterAtIndex:0];
		
		switch (key) {
			case NSUpArrowFunctionKey:
			case NSDownArrowFunctionKey:
			case NSLeftArrowFunctionKey:
			case NSRightArrowFunctionKey:
				break;
			default:
				break;
		}
		
		
		if ( modifier & NSEventModifierFlagCommand ) {
			// map Cmd-x to Ctrl-x to match Qt port
			if ( strchr( "ad", key ) != NULL ) {
				modifier &= ~NSEventModifierFlagCommand;
				modifier |= NSEventModifierFlagControl;
			}
		}
		
		if ( modifier & NSEventModifierFlagShift  ) {
			// system already upcases for us
		}
		if ( modifier & NSEventModifierFlagControl ) {
			// convert to control key
			key = toupper(key) - 'A' + 1;
		}
		if ( modifier & NSEventModifierFlagOption ) {
			// convert to meta key
			key = 0x80 | key;
		}
	}
	return key;
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

void cocoa_init_nhwindows(int* argc, char** argv)
{
	//NSLog(@"init_nhwindows");
	flags.runmode = RUN_STEP;
	iflags.window_inited = TRUE;
	iflags.toptenwin = TRUE;
	iflags.menu_tab_sep = TRUE;
	// tiles with transparent backgrounds are drawn over the floor beneath them
	iflags.use_background_glyph = TRUE;
	
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
	
	[[MainWindowController instance] initWindows];
}

void cocoa_askname(void)
{
	//NSLog(@"askname");
	cocoa_getlin("Enter your name", svp.plname);
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
			w = [NhWindow statusWindow];
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
	if (win != [NhWindow messageWindow] && win != [NhWindow statusWindow] && win != [NhWindow mapWindow]) {
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
		[win.currentItemGroup addItem:i];
	} else {
		NhItemGroup *g = [[NhItemGroup alloc] initWithTitle:title];
		g.attr = attr;
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

int cocoa_select_menu(winid wid, int how, menu_item **selected)
{
	//NSLog(@"select_menu %x", wid);
	NhMenuWindow * win = (NhMenuWindow *) g_WindowDict[@(wid)];

	win.how = how;
	*selected = NULL;
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
	[[MainWindowController instance] updateInventory];
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

void cocoa_print_glyph(winid wid, coordxy x, coordxy y, const glyph_info *glyphinfo,
					   const glyph_info *bkglyphinfo)
{
	int glyph = glyphinfo->glyph;
	int bkglyph = bkglyphinfo ? bkglyphinfo->glyph : GLYPH_UNEXPLORED;
	//NSLog(@"print_glyph %x %d,%d", wid, x, y);
	NhMapWindow * win = (NhMapWindow *) g_WindowDict[@(wid)];
	[win printGlyph:glyph background:bkglyph atX:x y:y];
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
	}
	[[MainWindowController instance] refreshAllViews];
	NhEvent *e = [[NhEventQueue instance] nextEvent];
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
	
	NSString * text = [NSString stringWithFormat:@"%s", question];
	if ( choices && choices[0] ) {
		text = [text stringByAppendingFormat:@" [%s]", choices];
	}
	if ( def ) {
		text = [text stringByAppendingFormat:@" (%c)", def];
	}
	
	if ( [text containsString:@"direction"] ) {
		[[MainWindowController instance] showDirectionWithPrompt:text];
		NhEvent * e = [[NhEventQueue instance] nextEvent];
		return e.key;
	}
	
	if ( choices ) {
		static const char * yesNo[] = {
			"yn",
			"ynq",
			"rl",
		};
		for ( int i = 0; i < sizeof yesNo/sizeof yesNo[0]; ++i ) {
			if ( strcmp( choices, yesNo[i] ) == 0 ) {
				NhYnQuestion * q = [[NhYnQuestion alloc] initWithQuestion:question choices:choices default:def];
				[[MainWindowController instance] showYnQuestion:q];
				NhEvent * e = [[NhEventQueue instance] nextEvent];
				return e.key;
			}
		}
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
	cocoa_putstr(WIN_MESSAGE, 0, prompt);
	[[MainWindowController instance] refreshAllViews];
	[[MainWindowController instance] getLine];
	NhTextInputEvent *e = (NhTextInputEvent *) [[NhEventQueue instance] nextEvent];
	if ( [e class] == [NhTextInputEvent class]  &&  e.text ) {
		[e.text getCString:line maxLength:BUFSZ encoding:NSASCIIStringEncoding];
	} else {
		// cancel
		strcpy(line, "\033\000");
	}
}

int cocoa_get_ext_cmd()
{
	//NSLog(@"get_ext_cmd");
	if ([[NhEventQueue instance] peek]) {
		// already have extended command in queue
	} else {
		// get command event
		[[MainWindowController instance] showExtendedCommands];
	}
	NhTextInputEvent *e = (NhTextInputEvent *) [[NhEventQueue instance] nextEvent];
	assert( [e class] == [NhTextInputEvent class] );
	const char * cmd = [e.text UTF8String];
		
	// return index of command, not its key
	for ( int i = 0; extcmdlist[i].ef_txt; ++i ) {
		if ( strcmp( extcmdlist[i].ef_txt, cmd ) == 0 ) {
			return i;
		}
	}
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
