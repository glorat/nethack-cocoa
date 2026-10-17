/*
 *  wincocoa.h
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


#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#endif

#include "hack.h"
#undef yn	// avoid conflict with math.h

extern FILE *cocoa_fopen(const char *filename, const char *mode);

void cocoa_init_nhwindows(int* argc, char** argv);
void cocoa_player_selection(void);
void cocoa_askname(void);
void cocoa_get_nh_event(void);
void cocoa_exit_nhwindows(const char *str);
void cocoa_suspend_nhwindows(const char *str);
void cocoa_resume_nhwindows(void);
winid cocoa_create_nhwindow(int type);
void cocoa_clear_nhwindow(winid wid);
void cocoa_display_nhwindow(winid wid, boolean block);
void cocoa_destroy_nhwindow(winid wid);
void cocoa_curs(winid wid, int x, int y);
void cocoa_putstr(winid wid, int attr, const char *text);
void cocoa_putmixed(winid wid, int attr, const char *text);
void cocoa_display_file(const char *filename, boolean must_exist);
void cocoa_start_menu(winid wid, unsigned long mbehavior);
void cocoa_add_menu(winid wid, const glyph_info *glyphinfo, const ANY_P *identifier,
					char accelerator, char group_accel, int attr, int clr,
					const char *str, unsigned int itemflags);
void cocoa_end_menu(winid wid, const char *prompt);
int cocoa_select_menu(winid wid, int how, menu_item **menu_list);
void cocoa_update_inventory(int arg);
void cocoa_status_init(void);
void cocoa_status_finish(void);
void cocoa_status_enablefield(int fld, const char *nm, const char *fmt, boolean enable);
void cocoa_status_update(int fld, genericptr_t ptr, int chg, int percent, int color, unsigned long *colormasks);
void cocoa_mark_synch(void);
void cocoa_wait_synch(void);
void cocoa_cliparound(int x, int y);
void cocoa_cliparound_window(winid wid, int x, int y);
void cocoa_print_glyph(winid wid, coordxy x, coordxy y, const glyph_info *glyphinfo,
					   const glyph_info *bkglyphinfo);
void cocoa_raw_print(const char *str);
void cocoa_raw_print_bold(const char *str);
int cocoa_nhgetch(void);
int cocoa_nh_poskey(coordxy *x, coordxy *y, int *mod);
void cocoa_nhbell(void);
int cocoa_doprev_message(void);
char cocoa_yn_function(const char *question, const char *choices, char def);
void cocoa_getlin(const char *prompt, char *line);
int cocoa_get_ext_cmd(void);
void cocoa_number_pad(int num);
void cocoa_delay_output(void);
void cocoa_outrip(winid wid, int how, time_t when);
void cocoa_preference_update(const char * pref);
char *cocoa_getmsghistory(boolean);
void cocoa_putmsghistory(const char *, boolean);
boolean win_can_suspend(void);
win_request_info *cocoa_ctrl_nhwindow(winid, int, win_request_info *);

coord CoordMake(coordxy i, coordxy j);
const char *cocoa_resource_dir(void);

#ifdef __OBJC__

@class NhEventQueue;
@class NSEvent;

@interface WinCocoa : NSObject {
}

+ (const char *)baseFilePath;
+ (void)expandFilename:(const char *)filename intoPath:(char *)path;
+ (int)keyWithKeyEvent:(NSEvent *)keyEvent;

@end

#endif
