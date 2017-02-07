//
//  OAToolbarViewController.h
//  OsmAnd
//
//  Created by Alexey Kulish on 06/02/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OAMapModeHeaders.h"

@class OAToolbarViewController;

@protocol OAToolbarViewControllerProtocol
@required

- (CGFloat) toolbarTopPosition;
- (void) toolbarLayoutDidChange:(OAToolbarViewController *)toolbarController animated:(BOOL)animated;
- (void) toolbarHide:(OAToolbarViewController *)toolbarController;

@end

@interface OAToolbarViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView *navBarView;
@property (weak, nonatomic) id<OAToolbarViewControllerProtocol> delegate;

- (int)getPriority;

- (void)onViewWillAppear:(EOAMapHudType)mapHudType;
- (void)onViewDidAppear:(EOAMapHudType)mapHudType;
- (void)onViewWillDisappear:(EOAMapHudType)mapHudType;

- (void)onMapAzimuthChanged:(id)observable withKey:(id)key andValue:(id)value;
- (void)onMapChanged:(id)observable withKey:(id)key;

- (void)updateFrame:(BOOL)animated;

- (UIStatusBarStyle)getPreferredStatusBarStyle;
- (UIColor *)getStatusBarColor;

@end