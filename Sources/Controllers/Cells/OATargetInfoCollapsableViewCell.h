//
//  OATargetInfoCollapsableViewCell.h
//  OsmAnd
//
//  Created by Alexey Kulish on 11/12/2016.
//  Copyright © 2016 OsmAnd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OATargetInfoCollapsableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UILabel *textView;
@property (weak, nonatomic) IBOutlet UIImageView *rightIconView;
@property (nonatomic, readonly) BOOL collapsable;
@property (weak, nonatomic) UIView *collapsableView;

- (void)setCollapsed:(BOOL)collapsed rawHeight:(int)rawHeight;

@end