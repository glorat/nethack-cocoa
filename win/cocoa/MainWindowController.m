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
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

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
#import "NhStatus.h"
#import "TileSet.h"
#import "TileSheet.h"
#import "OptionsFile.h"
#import "TextSize.h"
#import "NetHackCocoaAppDelegate.h"
#import "EquipmentView.h"
#import "InventoryView.h"

#import "wincocoa.h" // cocoa_getpos etc.

#include "hack.h" // BUFSZ etc.
#include "func_tab.h"

static MainWindowController* instance;

static const CGFloat kInventoryWidth = 280;
static const CGFloat kMinWindowWidth = 637;
static const CGFloat kMinMessagesWidth = 153;
static const CGFloat kMinInventoryWidth = 180;
static NSString * const kDefaultTileSet = @"tiles128.png";

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
	[self installInventorySidebar];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTextSize)
		name:NhTextSizeDidChangeNotification object:nil];
}

- (void)installInventorySidebar
{
	NSView * content = self.window.contentView;
	NSScrollView * map = mainView.enclosingScrollView;
	NSScrollView * messages = messagesView.enclosingScrollView;
	inventoryView = [[InventoryView alloc] initWithFrame:NSZeroRect];
	inventoryView.translatesAutoresizingMaskIntoConstraints = NO;
	__weak MainWindowController * weakSelf = self;
	inventoryView.chooseItem = ^(char letter) {
		[weakSelf chooseInventoryItem:letter];
	};
	inventoryView.resize = ^(CGFloat width, BOOL done) {
		[weakSelf dragInventoryWidth:width done:done];
	};
	[content addSubview:inventoryView];
	// bigger text widens the stats, which would otherwise squeeze the messages to nothing
	messagesMinWidth = [messages.widthAnchor constraintGreaterThanOrEqualToConstant:kMinMessagesWidth];
	messagesMinWidth.active = YES;

	NSMutableArray * edges = [NSMutableArray array];
	for ( NSLayoutConstraint * c in content.constraints ) {
		if ( c.firstAttribute == NSLayoutAttributeTrailing && c.secondAttribute == NSLayoutAttributeTrailing
			&& (c.firstItem == map || c.secondItem == map || c.firstItem == messages || c.secondItem == messages) )
			[edges addObject:c];
	}
	inventoryHiddenConstraints = edges;
	inventoryShownConstraints = @[
		[map.trailingAnchor constraintEqualToAnchor:inventoryView.leadingAnchor],
		[messages.trailingAnchor constraintEqualToAnchor:inventoryView.leadingAnchor],
		[inventoryView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
		[inventoryView.topAnchor constraintEqualToAnchor:content.topAnchor],
		[inventoryView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
	];
	inventoryWidth = [inventoryView.widthAnchor constraintEqualToConstant:kInventoryWidth];
	inventoryShownConstraints = [inventoryShownConstraints arrayByAddingObject:inventoryWidth];
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"ShowInventory" : @YES, @"InventoryWidth" : @(kInventoryWidth) }];
	inventoryWidth.constant = [self savedInventoryWidth];
	[self showInventory:[[NSUserDefaults standardUserDefaults] boolForKey:@"ShowInventory"]];
}

- (void)showInventory:(BOOL)show
{
	inventoryView.hidden = !show;
	if ( show ) {
		[NSLayoutConstraint deactivateConstraints:inventoryHiddenConstraints];
		[NSLayoutConstraint activateConstraints:inventoryShownConstraints];
	} else {
		[NSLayoutConstraint deactivateConstraints:inventoryShownConstraints];
		[NSLayoutConstraint activateConstraints:inventoryHiddenConstraints];
	}
	[self updateMinWindowWidth];
}

// the map, stats, equipment and messages can't get narrower than this
-(CGFloat)mainAreaMinWidth
{
	CGFloat top = statsView.fittingSize.width + equipmentView.frame.size.width + messagesMinWidth.constant;
	return MAX(kMinWindowWidth, top);
}

// saved as the width at the default text size, so the sidebar keeps its proportion when the text grows
-(CGFloat)savedInventoryWidth
{
	CGFloat saved = [[NSUserDefaults standardUserDefaults] doubleForKey:@"InventoryWidth"];
	return NhScaledFontSize(MAX(saved, kMinInventoryWidth));
}

-(void)dragInventoryWidth:(CGFloat)width done:(BOOL)done
{
	NSWindow * window = self.window;
	width = round(MAX(width, NhScaledFontSize(kMinInventoryWidth)));
	CGFloat room = [window contentRectForFrameRect:window.frame].size.width - [self mainAreaMinWidth];
	if ( width > room ) {
		// widen the window leftward so the edge stays under the mouse, then rightward, within the screen
		NSRect frame = window.frame, screen = window.screen.visibleFrame;
		CGFloat left = MAX(0, MIN(width - room, NSMinX(frame) - NSMinX(screen)));
		CGFloat right = MAX(0, MIN(width - room - left, NSMaxX(screen) - NSMaxX(frame)));
		frame.origin.x -= left;
		frame.size.width += left + right;
		[window setFrame:frame display:YES];
		width = room + left + right;
	}
	inventoryWidth.constant = width;
	if ( done ) {
		[[NSUserDefaults standardUserDefaults] setDouble:inventoryWidth.constant * NhDefaultTextSize / NhTextSize() forKey:@"InventoryWidth"];
		[self updateMinWindowWidth];
	}
}

-(void)updateMinWindowWidth
{
	NSWindow * window = self.window;
	NSSize minSize = window.contentMinSize;
	minSize.width = [self mainAreaMinWidth] + (inventoryView.hidden ? 0 : inventoryWidth.constant);
	window.contentMinSize = minSize;
	NSRect content = [window contentRectForFrameRect:window.frame];
	if ( content.size.width < minSize.width ) {
		NSRect frame = window.frame;
		frame.size.width += minSize.width - content.size.width;
		[window setFrame:frame display:YES];
	}
}

- (IBAction)toggleInventory:(id)sender
{
	BOOL show = inventoryView.hidden;
	[self showInventory:show];
	[[NSUserDefaults standardUserDefaults] setBool:show forKey:@"ShowInventory"];
}

// the core's #inventory command offers the actions for whichever item is picked
- (void)chooseInventoryItem:(char)letter
{
	char inventoryKey = cmd_from_func(ddoinv);
	// with keys still queued, the pick could answer a menu one of them opens
	if ( program_state.input_state != commandInp || !inventoryKey || [[NhEventQueue instance] peek] ) {
		NSBeep();
		return;
	}
	[[NhEventQueue instance] addEvents:@[ [NhEvent eventWithKeychar:inventoryKey],
										   [NhMenuPickEvent eventWithLetter:letter] ]];
}

- (void)setInventoryGroups:(NSArray *)groups
{
	if ( ![NSThread isMainThread] ) {
		[self performSelectorOnMainThread:@selector(setInventoryGroups:) withObject:groups waitUntilDone:NO];
		return;
	}
	[inventoryView setItemGroups:groups];
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
		
		// tile_file overrides the default, as the Guidebook says, so it wins over the menu's choice
		if ( iflags.wc_tile_file ) {
			tileSetName = [self tileSetNameForOption:[NSString stringWithUTF8String:iflags.wc_tile_file]];
		}
		if ( tileSetName == nil ) {
			tileSetName = kDefaultTileSet;
		}
		NSString * problem = [self setTileSet:tileSetName];
		if ( problem ) {
			[self setTileSet:kDefaultTileSet];
			NSString * message = [NSString stringWithFormat:@"The tile set \"%@\" can't be used, so the default tile set is shown instead.", [tileSetName lastPathComponent]];
			[self performSelector:@selector(showTileSetProblem:) withObject:@[message, problem] afterDelay:0];
		}

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

		// font_size_message and font_size_status only choose where the text starts; once the player
		// picks a size in the View menu, that wins
		CGFloat textSize = [[NSUserDefaults standardUserDefaults] doubleForKey:@"TextSize"];
		if ( textSize <= 0 )
			textSize = iflags.wc_fontsiz_message > 0 ? iflags.wc_fontsiz_message : iflags.wc_fontsiz_status;
		NhSetTextSize(textSize > 0 ? textSize : NhDefaultTextSize);
		[self applyTextSize];
		
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
	// the tooltip is its own window, and would keep the app from quitting after this one closes
	[mainView cancelTooltip];
	[self savePreferences];

	// if window closes then application needs to terminate
	[self terminateApplication:nil];
}

- (void)savePreferences
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
	
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"UserTileSets"];
	[[NSUserDefaults standardUserDefaults] synchronize];
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
			[self showGameOver];
		}
	}		
}

- (void)showGameOver
{
	NSAlert * alert = [[NSAlert alloc] init];
	alert.messageText = @"The game is over";
	alert.informativeText = @"Start a new game, or quit NetHack.";
	[alert addButtonWithTitle:@"New Game"];
	[alert addButtonWithTitle:@"Quit"].keyEquivalent = @"\033";
	[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
		if ( response == NSAlertFirstButtonReturn )
			[self relaunch];
		else
			[self.window close];
	}];
}

// the core can't be restarted in-process, so a new game is a fresh instance
- (void)relaunch
{
	// the new instance reads these at launch, before this one has closed its window
	[self savePreferences];

	// the sandbox drops a configured environment, so NETHACKOPTIONS doesn't carry over
	NSWorkspaceOpenConfiguration * config = [NSWorkspaceOpenConfiguration configuration];
	config.createsNewApplicationInstance = YES;
	[[NSWorkspace sharedWorkspace] openApplicationAtURL:[[NSBundle mainBundle] bundleURL] configuration:config completionHandler:^(NSRunningApplication * app, NSError * error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if ( error ) {
				[self.window presentError:error];
				[self showGameOver];
			} else {
				[self.window close];
			}
		});
	}];
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
	if ( item.action == @selector(toggleInventory:) )
		item.title = inventoryView.hidden ? @"Show Inventory" : @"Hide Inventory";
	if ( item.action == @selector(biggerText:) )
		return NhBiggerTextSize(NhTextSize()) != NhTextSize();
	if ( item.action == @selector(smallerText:) )
		return NhSmallerTextSize(NhTextSize()) != NhTextSize();
	if ( item.action == @selector(defaultTextSize:) )
		return NhTextSize() != NhDefaultTextSize;
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

-(NSFont *)messageFont
{
	return [NSFont systemFontOfSize:NhTextSize()];
}

-(void)applyTextSize
{
	messagesView.rowHeight = NhLineHeight([self messageFont]);
	messagesMinWidth.constant = NhScaledFontSize(kMinMessagesWidth);
	inventoryWidth.constant = [self savedInventoryWidth];
	// after the stats have taken the new size too, since they hear of it from the same notification
	dispatch_async(dispatch_get_main_queue(), ^{
		[self updateMinWindowWidth];
	});
	[self refreshMessages];
}

-(void)chooseTextSize:(CGFloat)size
{
	NhSetTextSize(size);
	[[NSUserDefaults standardUserDefaults] setDouble:NhTextSize() forKey:@"TextSize"];
}

- (IBAction)biggerText:(id)sender
{
	[self chooseTextSize:NhBiggerTextSize(NhTextSize())];
}

- (IBAction)smallerText:(id)sender
{
	[self chooseTextSize:NhSmallerTextSize(NhTextSize())];
}

// forgets the choice, so font_size_message decides again at the next launch
- (IBAction)defaultTextSize:(id)sender
{
	NhSetTextSize(NhDefaultTextSize);
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TextSize"];
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


// Built-in tile sets are named by file name, the player's by path: "~/" is the app's own folder,
// the one that holds .nethackrc
-(NSString *)pathOfTileSet:(NSString *)name
{
	if ( [name hasPrefix:@"~"] || [name isAbsolutePath] )
		return [name stringByExpandingTildeInPath];
	return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:name];
}

-(NSString *)tileSetNameForOption:(NSString *)tileFile
{
	if ( [tileFile hasPrefix:@"~"] || [tileFile isAbsolutePath] )
		return [[tileFile stringByExpandingTildeInPath] stringByAbbreviatingWithTildeInPath];
	NSString * mine = [@"~" stringByAppendingPathComponent:tileFile];
	if ( [[NSFileManager defaultManager] fileExistsAtPath:[mine stringByExpandingTildeInPath]] )
		return mine;
	return tileFile;
}

-(NSString *)problemWithSheetAtPath:(NSString *)path tileSize:(NSSize *)tileSize
{
	extern int total_tiles_used;
	NSSize pixels = NhPixelSizeOfImageFile(path);
	NSSize size = NhTileSizeOfSheet(path, pixels);
	if ( tileSize )
		*tileSize = size;
	return NhTileSheetProblem(pixels, size, total_tiles_used);
}

// returns why the tile set can't be used, or nil once it is in use
-(NSString *)setTileSet:(NSString *)tileSetName
{
	NSString * path = [self pathOfTileSet:tileSetName];
	NSSize size;
	NSString * problem = [self problemWithSheetAtPath:path tileSize:&size];
	if ( problem )
		return problem;
	NSImage * image = [[NSImage alloc] initByReferencingFile:path];
	if ( image == nil || !image.isValid )
		return @"It isn't an image that can be read.";

	TileSet *tileSet = [[TileSet alloc] initWithImage:image tileSize:size];
	[TileSet setInstance:tileSet];

	_tileSetName = tileSetName;

	return nil;
}

-(void)showTileSetProblem:(NSArray<NSString *> *)messageAndDetail
{
	NSAlert * alert = [[NSAlert alloc] init];
	alert.messageText = messageAndDetail[0];
	alert.informativeText = messageAndDetail[1];
	if ( self.window.isVisible && self.window.attachedSheet == nil )
		[alert beginSheetModalForWindow:self.window completionHandler:nil];
	else
		[alert runModal];
}

-(void)useTileSet:(NSString *)name
{
	NSString * problem = [self setTileSet:name];
	if ( problem ) {
		NSString * message = [NSString stringWithFormat:@"\"%@\" can't be used as a tile set.", [name lastPathComponent]];
		[self showTileSetProblem:@[message, problem]];
		return;
	}

	// put us in tile mode
	[mainView enableAsciiMode:NO];
	[asciiModeMenuItem setState:NSControlStateValueOff];
	[equipmentView updateInventory];
}

- (IBAction)importTileSet:(id)sender
{
	NSOpenPanel * panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:YES];
	panel.allowedContentTypes = @[UTTypePNG, UTTypeBMP];
	panel.message = @"Choose tile sets made for NetHack 5.0. They are copied into the folder that holds .nethackrc.";
	if ( [panel runModal] != NSModalResponseOK )
		return;

	NSFileManager * fm = [NSFileManager defaultManager];
	NSString * imported = nil;
	NSMutableArray * problems = [NSMutableArray array];
	for ( NSURL * url in [panel URLs] ) {
		NSString * file = [url lastPathComponent];
		NSString * name = [@"~" stringByAppendingPathComponent:file];
		NSString * destination = [name stringByExpandingTildeInPath];
		NSString * problem = [self problemWithSheetAtPath:url.path tileSize:NULL];
		if ( problem ) {
			[problems addObject:[NSString stringWithFormat:@"%@: %@", file, problem]];
			continue;
		}
		if ( ![[url.path stringByStandardizingPath] isEqualToString:[destination stringByStandardizingPath]] ) {
			if ( [fm fileExistsAtPath:destination] ) {
				NSAlert * alert = [[NSAlert alloc] init];
				alert.messageText = [NSString stringWithFormat:@"A tile set named \"%@\" is already imported. Replace it?", file];
				[alert addButtonWithTitle:@"Replace"];
				[alert addButtonWithTitle:@"Cancel"];
				if ( [alert runModal] != NSAlertFirstButtonReturn )
					continue;
				[fm removeItemAtPath:destination error:NULL];
			}
			NSError * error = nil;
			if ( ![fm copyItemAtPath:url.path toPath:destination error:&error] ) {
				[problems addObject:[NSString stringWithFormat:@"%@: %@", file, error.localizedDescription]];
				continue;
			}
		}
		imported = name;
	}

	if ( imported )
		[self useTileSet:imported];
	if ( problems.count ) {
		NSString * message = problems.count == 1 ? @"A tile set couldn't be imported." : @"Some tile sets couldn't be imported.";
		[self showTileSetProblem:@[message, [problems componentsJoinedByString:@"\n\n"]]];
	}
}

- (IBAction)showTileSetFolder:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES]];
}

// the file the core read, which is ~/.nethackrc unless NETHACKOPTIONS or --nethackrc names another
-(NSString *)optionsFilePath
{
	const char * path = get_configfile();
	if ( path && *path )
		return @(path);
	return [NSHomeDirectory() stringByAppendingPathComponent:@".nethackrc"];
}

-(void)showOptionsFileProblem:(NSString *)message error:(NSError *)error
{
	[self showTileSetProblem:@[message, error.localizedDescription ?: @""]];
}

- (IBAction)editOptionsFile:(id)sender
{
	NSString * path = [self optionsFilePath];
	NSError * error = nil;
	if ( !NhCreateOptionsFile(path, &error) ) {
		[self showOptionsFileProblem:@"The options file couldn't be created." error:error];
		return;
	}
	// it has no extension, so ask for the app that edits plain text rather than whatever claims the file
	NSWorkspace * workspace = [NSWorkspace sharedWorkspace];
	NSURL * editor = [workspace URLForApplicationToOpenContentType:UTTypePlainText];
	if ( editor == nil )
		editor = [workspace URLForApplicationWithBundleIdentifier:@"com.apple.TextEdit"];
	[workspace openURLs:@[[NSURL fileURLWithPath:path]] withApplicationAtURL:editor configuration:[NSWorkspaceOpenConfiguration configuration]
		completionHandler:^(NSRunningApplication * app, NSError * error) {
		if ( error ) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self showOptionsFileProblem:@"The options file couldn't be opened." error:error];
			});
		}
	}];
}

- (IBAction)selectTileSet:(id)sender
{
	[self useTileSet:[sender representedObject]];
}

-(void)addTileSetItem:(NSString *)name title:(NSString *)title toMenu:(NSMenu *)menu
{
	NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:title action:@selector(selectTileSet:) keyEquivalent:@""];
	[item setTarget:self];
	item.representedObject = name;
	item.state = !iflags.wc_ascii_map && [name isEqualToString:_tileSetName] ? NSControlStateValueOn : NSControlStateValueOff;
	[menu addItem:item];
}

// rebuilt each time it opens, so files added to or removed from the folder show up
- (void)createTileSetListInMenu:(NSMenu *)menu
{
	NSInteger fixed = 0;
	while ( fixed < menu.numberOfItems && ![menu itemAtIndex:fixed].isSeparatorItem )
		++fixed;
	++fixed;
	while ( menu.numberOfItems > fixed )
		[menu removeItemAtIndex:fixed];

	// the bundle also holds small images such as petmark.png, so only working sheets are listed
	NSString * bundleFolder = [[NSBundle mainBundle] resourcePath];
	for ( NSString * file in NhTileSheetsInFolder(bundleFolder) ) {
		if ( [self problemWithSheetAtPath:[bundleFolder stringByAppendingPathComponent:file] tileSize:NULL] == nil )
			[self addTileSetItem:file title:file toMenu:menu];
	}

	// the player's are all listed, and choosing one that doesn't work says why
	NSArray * mine = NhTileSheetsInFolder(NSHomeDirectory());
	if ( mine.count )
		[menu addItem:[NSMenuItem separatorItem]];
	for ( NSString * file in mine )
		[self addTileSetItem:[@"~" stringByAppendingPathComponent:file] title:file toMenu:menu];
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
		if ( [pref isEqualToString:@"font_size_message"] && iflags.wc_fontsiz_message > 0 )
			NhSetTextSize(iflags.wc_fontsiz_message);
		if ( [pref isEqualToString:@"font_size_status"] && iflags.wc_fontsiz_status > 0 )
			NhSetTextSize(iflags.wc_fontsiz_status);
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
		return [self inTextSize:[[NhWindow messageWindow] messageAtRow:rowIndex]];
	}
	return nil;
}

// messages carry fonts only where they're bold, made for the default size
-(NSAttributedString *)inTextSize:(id)message
{
	if ( message == nil )
		return nil;
	NSMutableAttributedString * s = [message isKindOfClass:[NSAttributedString class]]
		? [message mutableCopy] : [[NSMutableAttributedString alloc] initWithString:message];
	NSFont * plain = [self messageFont];
	[s enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, s.length) options:0 usingBlock:^(NSFont * font, NSRange range, BOOL * stop) {
		[s addAttribute:NSFontAttributeName value:font ? NhScaledFont(font) : plain range:range];
	}];
	return s;
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
	}
}

- (void)updateStatus:(NhStatus *)status
{
	if ( ![NSThread isMainThread] ) {
		[self performSelectorOnMainThread:@selector(updateStatus:) withObject:status waitUntilDone:NO];
		return;
	}
	[statsView updateWithStatus:status];
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

// counted only around the modal window itself: other blocking hand-offs return at once
static void WhileGameWaits(BOOL gameBlocked, void (^runModal)(void))
{
	if ( gameBlocked )
		[[NhEventQueue instance] gameWaitsOnWindow:YES];
	runModal();
	if ( gameBlocked )
		[[NhEventQueue instance] gameWaitsOnWindow:NO];
}

- (void)showPlayerSelection
{
	if (![NSThread isMainThread]) {
		[self.appDelegate unlockNethackCore];
		[self performSelectorOnMainThread:@selector(showPlayerSelection) withObject:nil waitUntilDone:YES];
		[self.appDelegate lockNethackCore];
	} else {
		WhileGameWaits(YES, ^{ [showPlayerSelection runModal]; });
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
		} else {
			NSString * text = [w text];
			if ( [text length] ) {
				WhileGameWaits(w.blocking, ^{ [MessageWindowController messageWindowWithText:text]; });
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
		WhileGameWaits(w.blocking, ^{ [MenuWindowController menuWindowWithMenu:w]; });
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
