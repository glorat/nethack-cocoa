//
//  MainViewController.m
//  NetHack
//
//  Created by dirk on 2/1/10.
//  Copyright 2010 Dirk Zimmermann. All rights reserved.
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

#import <AVFoundation/AVFoundation.h>

#import "MainWindowController.h"
#import "MainView.h"
#import "NhYnQuestion.h"
#import "NSString+Z.h"
#import "NhEventQueue.h"
#import "NhWindow.h"
#import "NhMenuWindow.h"
#import "MainView.h"
#import "NhEvent.h"
#import "NhTextInputEvent.h"
#import "NhCommand.h"
#import "MenuWindowController.h"
#import "MessageWindowController.h"
#import "DirectionWindowController.h"
#import "YesNoWindowController.h"
#import "InputWindowController.h"
#import "ExtCommandWindowController.h"
#import "ExtCommandInput.h"
#import "PlayerSelectionWindowController.h"
#import "StatsView.h"
#import "TileSet.h"
#import "NetHackCocoaAppDelegate.h"
#import "EquipmentView.h"

#import "wincocoa.h" // cocoa_getpos etc.

#include "hack.h" // BUFSZ etc.
#include "func_tab.h"

static MainWindowController* instance;

@implementation MainWindowController

@synthesize useSpeech;


+ (MainWindowController *)instance {
	return instance;
}

- (void)setFont:(NSFont *)font
{
	for ( NSTableColumn * column in [self->messagesView tableColumns] ) {
		NSCell * cell = [column dataCell];
		[cell setFont:font];
	}
}

// Convert keyEquivs in menu items to use their shifted equivalent
// This makes them display with their more conventional character
// bindings and lets us work internationally.
- (void)fixMenuKeyEquivalents:(NSMenu *)menu
{
	for ( NSMenuItem * item in [menu itemArray] ) {
		if ( [item hasSubmenu] ) {
			NSMenu * submenu = [item submenu];
			[self fixMenuKeyEquivalents:submenu];
		} else {
			NSUInteger mask = [item keyEquivalentModifierMask];
			if ( mask & NSEventModifierFlagShift ) {
				NSString * key = [item keyEquivalent];
				switch ( [key characterAtIndex:0] ) {
					case '1':		key = @"!";		break;
					case '2':		key = @"@";		break;
					case '3':		key = @"#";		break;
					case '4':		key = @"$";		break;
					case '5':		key = @"%";		break;
					case '6':		key = @"^";		break;
					case '7':		key = @"&";		break;
					case '8':		key = @"*";		break;
					case '9':		key = @"(";		break;
					case '0':		key = @")";		break;
					case '.':		key = @">";		break;
					case ',':		key = @"<";		break;
					case '/':		key = @"?";		break;
					case '[':		key = @"{";		break;
					case ']':		key = @"}";		break;
					case ';':		key = @":";		break;
					case '\'':		key = @"\"";	break;
					case '-':		key = @"_";		break;
					case '=':		key = @"+";		break;
					default:		key = nil;		break;
				}
				if ( key ) {
					mask &= ~NSEventModifierFlagShift;
					[item setKeyEquivalent:key];
					[item setKeyEquivalentModifierMask:mask];
				}				
			}
		}
	}
}

-(NSSize)tileSetSizeFromName:(NSString *)name
{
	int dx, dy;
	if ( sscanf([name UTF8String], "%*[^0-9]%dx%d.%*s", &dx, &dy ) == 2 ) {
		// fully described
	} else if ( sscanf([name UTF8String], "%*[^0-9]%d.%*s", &dx ) == 1 ) {
		dy = dx;
	} else {
		dx = dy = 16;
	}
	NSSize size = NSMakeSize( dx, dy );
	return size;
}

- (void)awakeFromNib {
	instance = self;

	self.appDelegate = [[NSApplication sharedApplication] delegate];

#if 0
	{
		NSFont * font = [NSFont fontWithName:@"Lucida Bright" size:13];
		[self setFont:font];
	}
#endif
	
	NSMenu * menu = [[NSApplication sharedApplication] mainMenu];
	[self fixMenuKeyEquivalents:menu];
	
	[[self window] setAcceptsMouseMovedEvents:YES];
}

// called when user options have been read and engine wants windows to be created
-(void)initWindows
{
	if ( ![NSThread isMainThread] ) {
		[self performSelectorOnMainThread:@selector(initWindows) withObject:nil waitUntilDone:YES];
	} else {
		// read tile set preferences
		NSString *	tileSetName = [[NSUserDefaults standardUserDefaults] objectForKey:@"TileSetName"];
		NSString *	asciiFontName = [[NSUserDefaults standardUserDefaults] objectForKey:@"AsciiFontName"];
		CGFloat		asciiFontSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"AsciiFontSize"];
		
		self.useSpeech = [[NSUserDefaults standardUserDefaults] boolForKey:@"UseSpeech"];
		
		iflags.wc_ascii_map = [[NSUserDefaults standardUserDefaults] boolForKey:@"UseAscii"];
		
		// set defaults if no user preference
		if ( tileSetName == nil ) {
			tileSetName = @"tiles128.png";
		}
		NSSize size = [self tileSetSizeFromName:tileSetName];
		if ( ![self setTileSet:tileSetName size:size] ) {

		}
		_tileSetName = tileSetName;

		NSFont * font = [NSFont fontWithName:asciiFontName size:asciiFontSize];
		if ( font == nil ) {
			font = [NSFont systemFontOfSize:14.0];
		}
		[mainView setAsciiFont:font];

		CGFloat zoom = [[NSUserDefaults standardUserDefaults] floatForKey:@"MapZoom"];
		[mainView setZoom:zoom > 0 ? zoom : 1.0];
		
		// place check mark on ASCII menu item
		[asciiModeMenuItem setState:iflags.wc_ascii_map ? NSControlStateValueOn : NSControlStateValueOff];
		
		// select ascii mode in map view
		[mainView enableAsciiMode:iflags.wc_ascii_map];
		
		// set table row spacing to zero in messages window
		[messagesView setIntercellSpacing:NSMakeSize(0,0)];
		
		// use system colors for dark mode compatibility
		[messagesView setBackgroundColor:NSColor.textBackgroundColor];
		
		// initialize speech engine
		voice = [[AVSpeechSynthesizer alloc] init];
		[voice setDelegate:self];
		voiceQueue = [NSMutableArray array];
	}
}

-(void)windowWillClose:(NSNotification *)notification
{
	// save tile set preferences
	[[NSUserDefaults standardUserDefaults] setObject:_tileSetName forKey:@"TileSetName"];
	NSFont * font = [mainView asciiFont];
	[[NSUserDefaults standardUserDefaults] setObject:[font fontName] forKey:@"AsciiFontName"];
	[[NSUserDefaults standardUserDefaults] setFloat:[font pointSize] forKey:@"AsciiFontSize"];
	BOOL	useAscii = iflags.wc_ascii_map;
	[[NSUserDefaults standardUserDefaults] setBool:useAscii forKey:@"UseAscii"];
	[[NSUserDefaults standardUserDefaults] setFloat:[mainView zoom] forKey:@"MapZoom"];
	[[NSUserDefaults standardUserDefaults] setBool:self.useSpeech forKey:@"UseSpeech"];
	
	// save user defined tile sets
	[[NSUserDefaults standardUserDefaults] setObject:userTiles forKey:@"UserTileSets"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	// if window closes then application needs to terminate
	[self terminateApplication:nil];
}

- (void)setTerminatedByUser:(BOOL)byUser
{
	terminatedByUser = YES;
}

-(void)nethackExited
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(nethackExited) withObject:nil waitUntilDone:NO];
	} else {
		
		if ( terminatedByUser ) {
			[self.window close];
		} else {
			// nethack exited, but let user close the app manually 
		}
	}		
}


#pragma mark menu actions

// a click runs the item's command by name, so number_pad and bindings can't
// change it; a shortcut reaches the menu before the map, so it stays a key
- (void)performMenuAction:(id)sender
{
	NSEvent * event = [NSApp currentEvent];
	if ( event.type == NSEventTypeKeyDown && [event.charactersIgnoringModifiers isEqualToString:[sender keyEquivalent]] ) {
		int key = [WinCocoa keyWithKeyEvent:event];
		if ( key )
			[[NhEventQueue instance] addKey:key];
		return;
	}
	char initiator = extcmd_initiator();
	if ( !initiator ) {
		NSBeep();
		return;
	}
	[[NhEventQueue instance] addEvents:@[ [NhEvent eventWithKeychar:initiator],
										   [NhTextInputEvent eventWithText:[sender identifier]] ]];
}

// at any other prompt a click would feed '#' to it
- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	if ( item.action == @selector(performMenuAction:) )
		return program_state.input_state == commandInp;
	return YES;
}

- (void)updateWizardMenu
{
	if ( ![NSThread isMainThread] ) {
		[self performSelectorOnMainThread:@selector(updateWizardMenu) withObject:nil waitUntilDone:NO];
		return;
	}
	[NSApp.mainMenu itemWithTitle:@"Wizard Mode"].hidden = !wizard;
}

- (IBAction)enableAsciiMode:(id)sender
{
	NSMenuItem * menuItem = sender;
	bool enable = [menuItem state] == NSControlStateValueOff;
	[menuItem setState:enable ? NSControlStateValueOn : NSControlStateValueOff];
	
	[mainView enableAsciiMode:enable];
}

- (IBAction)zoomIn:(id)sender
{
	[mainView zoomIn];
}

- (IBAction)zoomOut:(id)sender
{
	[mainView zoomOut];
}

- (IBAction)actualSize:(id)sender
{
	[mainView setZoom:1.0];
}

- (IBAction)changeFont:(id)sender
{
	// update font
	NSFont *oldFont = [mainView asciiFont];
	NSFont *newFont = [sender convertFont:oldFont];
	[mainView setAsciiFont:newFont];
	// put us in ascii mode
	[mainView enableAsciiMode:YES];
	[asciiModeMenuItem setState:NSControlStateValueOn];
}


-(NSImage *)imageForTileSetName:(NSString *)tileSetName size:(NSSize)size
{
	NSImage *tilesetImage = [NSImage imageNamed:tileSetName];
	if ( tilesetImage == nil ) {
		tileSetName = [tileSetName stringByExpandingTildeInPath];
		NSURL * url = [NSURL fileURLWithPath:tileSetName isDirectory:NO];
		tilesetImage = [[NSImage alloc] initByReferencingURL:url];
		if ( tilesetImage == nil ) {
			return nil;
		}
	}

	// make sure dimensions work
	NSSize imageSize = [TileSet pixelSizeOfImage:tilesetImage];
	int count = (imageSize.width / size.width) * (imageSize.height / size.height);
	NSLog(@"%@: %ld", tileSetName, (long)count);
	extern int total_tiles_used;
	if ( count < total_tiles_used ) {
		// not enough images
		return nil;
	}
	return tilesetImage;
}

-(BOOL)setTileSet:(NSString *)tileSetName size:(NSSize)size
{
	NSImage *tilesetImage = [self imageForTileSetName:tileSetName size:size];
	if ( tilesetImage == nil )
		return NO;

	TileSet *tileSet = [[TileSet alloc] initWithImage:tilesetImage tileSize:size];
	[TileSet setInstance:tileSet];

	_tileSetName = tileSetName;

	return YES;
}

- (IBAction)addTileSet:(id)sender
{
	NSOpenPanel * panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:YES];
	[panel runModal];
	NSArray * result = [panel URLs];
	for ( NSURL * url in result ) {
		NSString * path = [url path];
		path = [path stringByAbbreviatingWithTildeInPath];
		NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:path action:@selector(selectTileSet:) keyEquivalent:@""];
		[item setTarget:self];
		[tileSetMenu addItem:item];
		if ( userTiles == nil ) {
			userTiles = [[NSMutableArray alloc] initWithCapacity:1];
		}
		[userTiles addObject:path];
	}
}
- (IBAction)selectTileSet:(id)sender
{
	NSMenuItem * item = sender;
	NSString * name = [item title];
	NSSize size = [self tileSetSizeFromName:name];

	BOOL ok = [self setTileSet:name size:size];
	if ( ok ) {

		// put us in tile mode
		[mainView enableAsciiMode:NO];
		[asciiModeMenuItem setState:NSControlStateValueOff];
		[equipmentView updateInventory];
		
	} else {
		NSAlert * alert = [[NSAlert alloc] init];
		alert.messageText = @"The tile set is not valid for this version of NetHack";
		[alert runModal];
	}
}

- (void)createTileSetListInMenu:(NSMenu *)menu 
{
	int count = [[menu itemArray] count];
	if ( count > 3 ) {
		// already initialized
		return;
	}

	NSMutableArray * files = [NSMutableArray array];
	
	// get list of builtin tiles
	NSString * tileFolder = [[NSBundle mainBundle] resourcePath];
	for ( NSString * name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tileFolder error:NULL] ) {
		NSString * ext = [name pathExtension];
		if ( [ext isEqualToString:@"png"] || [ext isEqualToString:@"bmp"] ) {
			// we have an image file, just make sure it is larger than a single image (petmark)
			NSString * path = [tileFolder stringByAppendingPathComponent:name];
			NSDictionary * attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
			if ( attr && [attr fileSize] >= 10000 ) {

				NSSize size = [self tileSetSizeFromName:name];
				NSImage * image = [self imageForTileSetName:name size:size];
				if ( image ) {
					[files addObject:name];
				}
			}				
		}
	}

	// add user defined tile file
	if (iflags.wc_tile_file) {
		[files addObject:[NSString stringWithUTF8String:iflags.wc_tile_file]];
	}
		
	// get user defined tiles
	userTiles = [[[NSUserDefaults standardUserDefaults] objectForKey:@"UserTileSets"] mutableCopy];
	for ( int idx = 0; idx < [userTiles count]; ++idx ) {		
		NSString * path = [userTiles objectAtIndex:idx];
		NSString * fullPath = [path stringByExpandingTildeInPath];
		NSDictionary * attr = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
		if ( attr ) {
			[files addObject:path];
		} else {
			[userTiles removeObjectAtIndex:idx];
			--idx;
		}
	}
	
	// add files
	for ( NSString * name in files ) {
		NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:name action:@selector(selectTileSet:) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
	}
}
- (void)menuWillOpen:(NSMenu *)menu
{
	if ( menu == tileSetMenu ) {
		[self createTileSetListInMenu:menu];
	}
}


- (void)preferenceUpdate:(NSString *)pref
{
	// user changed game options
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(preferenceUpdate:) withObject:pref waitUntilDone:YES];
	} else {
		if ( [pref isEqualToString:@"ascii_map"] ) {
			[asciiModeMenuItem setState:iflags.wc_ascii_map ? NSControlStateValueOn : NSControlStateValueOff];
			[mainView enableAsciiMode:iflags.wc_ascii_map];
		}
	}		
}

- (IBAction)terminateApplication:(id)sender
{
	NetHackCocoaAppDelegate * delegate = (NetHackCocoaAppDelegate *) [[NSApplication sharedApplication] delegate];
	if ( [delegate netHackThreadRunning] ) {
		// map Cmd-Q to Shift-S
		terminatedByUser = YES;
		[[NhEventQueue instance] addKey:'S'];		
	} else {
		// thread already exited, so just exit ourself
		[[NSApplication sharedApplication] terminate:self];
	}
}

#pragma mark window API

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if ( aTableView == messagesView ) {
		return [[NhWindow messageWindow] messageCount];
	}
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ( aTableView == messagesView ) {
		return [[NhWindow messageWindow] messageAtRow:rowIndex];
	}
	return nil;
}

- (void)refreshMessages {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(refreshMessages) withObject:nil waitUntilDone:NO];
	} else {
		// update message window
		[messagesView reloadData];
		NSInteger rows = [messagesView numberOfRows];		
		if (rows > 0) {
			[messagesView scrollRowToVisible:rows-1];
		}
		// update status window
		for ( NSString * text in [[NhWindow statusWindow] messages] ) {
			[statsView setItems:text];
		}
	}
}


- (void)showExtendedCommands
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(showExtendedCommands) withObject:nil waitUntilDone:NO];
	} else {
		NSMutableArray * commands = [NSMutableArray array];
		for ( int i = 0; extcmdlist[i].ef_txt; ++i ) {
			const struct ext_func_tab * ec = &extcmdlist[i];
			if ( (ec->flags & (CMD_NOT_AVAILABLE | INTERNALCMD)) || ((ec->flags & WIZMODECMD) && !wizard) )
				continue;
			[commands addObject:[NhExtCommand commandWithName:@(ec->ef_txt) help:@(ec->ef_desc) autocompletes:(ec->flags & AUTOCOMPLETE) != 0]];
		}
		[ExtCommandWindowController askWithCommands:commands answer:^(NSString * command) {
			[[NhEventQueue instance] addEvent:[NhTextInputEvent eventWithText:command]];
		}];
	}
}

- (void)showPlayerSelection
{
	if (![NSThread isMainThread]) {
		[self.appDelegate unlockNethackCore];
		[self performSelectorOnMainThread:@selector(showPlayerSelection) withObject:nil waitUntilDone:YES];
		[self.appDelegate lockNethackCore];
	} else {
		[showPlayerSelection runModal];
	}	
}

- (void)showDirectionWithPrompt:(NSString *)prompt
{
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(showDirectionWithPrompt:) withObject:prompt waitUntilDone:NO];
	} else {
		[DirectionWindowController askWithPrompt:prompt directions:@(gc.Cmd.dirchars) near:[mainView screenRectForTileX:u.ux y:u.uy]];
	}			
}

- (void)showYnQuestion:(NhYnQuestion *)q {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(showYnQuestion:) withObject:q waitUntilDone:NO];
	} else {
		[YesNoWindowController askQuestion:q];
	}
}

- (void)refreshAllViews {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(refreshAllViews) withObject:nil waitUntilDone:NO];
	} else {
		// hardware keyboard
		[self refreshMessages];
	}
}


- (void)displayMessageWindow:(NSString *)text {
	if ( [text length] == 0 ) {
		// do nothing
	} else if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(displayMessageWindow:) withObject:text waitUntilDone:NO];
	} else {
		[MessageWindowController messageWindowWithText:text];
	}
}

- (void)displayWindow:(NhWindow *)w {
	if (![NSThread isMainThread]) {

		BOOL blocking = w.blocking;
		[self.appDelegate unlockNethackCore];
		[self performSelectorOnMainThread:@selector(displayWindow:) withObject:w waitUntilDone:blocking];
		[self.appDelegate lockNethackCore];

	} else {
		
		if (w == [NhWindow messageWindow]) {
			[self refreshMessages];
		} else if (w.type == NHW_MAP) {
			[mainView setNeedsDisplay:YES];
		} else if ( w.type == NHW_STATUS ) {
			for ( NSString * text in [w messages] ) {
				[statsView setItems:text];
			}
		} else {
			NSString * text = [w text];
			if ( [text length] ) {
				[MessageWindowController messageWindowWithText:text];
			}
		}
	}
}

- (void)showMenuWindow:(NhMenuWindow *)w {
	if (![NSThread isMainThread]) {
		BOOL blocking = w.blocking;
		[self.appDelegate unlockNethackCore];
		[self performSelectorOnMainThread:@selector(showMenuWindow:) withObject:w waitUntilDone:blocking];
		[self.appDelegate lockNethackCore];
	} else {
		[MenuWindowController menuWindowWithMenu:w];
	}
}

- (void)clipAround:(NSValue *)clip {
	NSRange r = [clip rangeValue];
	[mainView cliparoundX:r.location y:r.length];
}

- (void)clipAroundX:(int)x y:(int)y {
	if (![NSThread isMainThread]) {

		[self.appDelegate unlockNethackCore];
		[self performSelectorOnMainThread:@selector(clipAround:)
							   withObject:[NSValue valueWithRange:NSMakeRange(x, y)] waitUntilDone:YES];
		[self.appDelegate lockNethackCore];
	} else {
		[mainView cliparoundX:x y:y];
	}
}

- (void)updateInventory {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(updateInventory) withObject:nil waitUntilDone:NO];
	} else {
		[equipmentView updateInventory];
	}
}

- (void)getLineWithPrompt:(NSString *)prompt {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(getLineWithPrompt:) withObject:prompt waitUntilDone:NO];
	} else {
		[InputWindowController askWithPrompt:prompt parent:self.window answer:^(NSString * text) {
			[[NhEventQueue instance] addEvent:[NhTextInputEvent eventWithText:text]];
		}];
	}
}

#pragma mark touch handling

- (int)keyFromDirection:(e_direction)d {
	static char keys[] = "kulnjbhy\033";
	return keys[d];
}

- (BOOL)isMovementKey:(char)k {
	if (isalpha(k)) {
		return strchr("kulnjbhy",k) != NULL;
	}
	return NO;
}

- (e_direction)directionFromKey:(char)k {
	switch (k) {
		case 'k':
			return kDirectionUp;
		case 'u':
			return kDirectionUpRight;
		case 'l':
			return kDirectionRight;
		case 'n':
			return kDirectionDownRight;
		case 'j':
			return kDirectionDown;
		case 'b':
			return kDirectionDownLeft;
		case 'h':
			return kDirectionLeft;
		case 'y':
			return kDirectionUpLeft;
	}
	return kDirectionMax;
}

- (void)handleMapTapTileX:(int)x y:(int)y forLocation:(CGPoint)p inView:(NSView *)view {
	//NSLog(@"tap on %d,%d (u %d,%d)", x, y, u.ux, u.uy);
	if (isDirectionQuestion) {
		isDirectionQuestion = NO;
		CGPoint delta = CGPointMake(x*32.0f-u.ux*32.0f, y*32.0f-u.uy*32.0f);
		delta.y *= -1;
		//NSLog(@"delta %3.2f,%3.2f", delta.x, delta.y);
		e_direction direction = [ZDirection directionFromEuclideanPointDelta:&delta];
		int key = [self keyFromDirection:direction];
		//NSLog(@"key %c", key);
		[[NhEventQueue instance] addKey:key];
	} else {
		// travel / movement
		[[NhEventQueue instance] addEvent:[NhEvent eventWithX:x y:y]];
	}
}

#pragma mark misc

- (void)speakString:(NSString *)text
{
	if ( !self.useSpeech )
		return;
	
	// add text to queue
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(speakString:) withObject:text waitUntilDone:NO];
	} else {
		if ( [voice isSpeaking] ) {
			// don't be too redundant for messages repeated many times
			int cnt = 0;
			for ( NSString * s in voiceQueue ) {
				if ( [text isEqualToString:s] )
					if ( ++cnt >= 3 )
						return;
			}
			[voiceQueue addObject:text];
		} else {
			// Start speaking
			AVSpeechUtterance * utterance = [AVSpeechUtterance speechUtteranceWithString:text];
			utterance.voice = [AVSpeechSynthesisVoice voiceWithIdentifier:@"com.apple.ttsbundle.Alex-compact"];
			[voice speakUtterance:utterance];
		}
	}
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
	if ( [voiceQueue count] ) {
		NSString * text = [voiceQueue objectAtIndex:0];
		[voiceQueue removeObjectAtIndex:0];
		AVSpeechUtterance * utterance = [AVSpeechUtterance speechUtteranceWithString:text];
		utterance.voice = [AVSpeechSynthesisVoice voiceWithIdentifier:@"com.apple.ttsbundle.Alex-compact"];
		[voice speakUtterance:utterance];
	}
}

@end
