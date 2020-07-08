//
//  OACreateProfileViewController.m
//  OsmAnd
//
//  Created by Paul on 8/29/18.
//  Copyright © 2018 OsmAnd. All rights reserved.
//

#import "OACreateProfileViewController.h"
#import "Localization.h"
#import "OAColors.h"
#import "OAApplicationMode.h"
#import "OAMultiIconTextDescCell.h"
#import "OATableViewCustomHeaderView.h"
#import "OAProfileAppearanceViewController.h"
#import "OAUtilities.h"

#include <generalRouter.h>

#define kHeaderId @"TableViewSectionHeader"
#define kSidePadding 16
#define kTopPadding 6
#define kHeaderViewFont [UIFont systemFontOfSize:34.0 weight:UIFontWeightBold]

@interface OACreateProfileViewController () <UITableViewDelegate, UITableViewDataSource>

@end

@implementation OACreateProfileViewController
{
    NSMutableArray<OAApplicationMode *> * _profileList;
    CGFloat _heightForHeader;
}

- (instancetype) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [super initWithNibName:@"OACreateProfileViewController" bundle:nil];
}

- (instancetype) init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit
{
    [self generateData];
}

- (void) generateData
{
    _profileList = [[NSMutableArray alloc] initWithArray:OAApplicationMode.allPossibleValues];
    [_profileList removeObjectAtIndex:0];
}

-(void) applyLocalization
{
    [_backButton setTitle:OALocalizedString(@"shared_string_cancel") forState:UIControlStateNormal];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 60.;
    [self.tableView registerClass:OATableViewCustomHeaderView.class forHeaderFooterViewReuseIdentifier:kHeaderId];
    _tableView.tableHeaderView = [OAUtilities setupTableHeaderViewWithText:OALocalizedString(@"create_profile") font:kHeaderViewFont textColor:UIColor.blackColor lineSpacing:0.0 isTitle:YES];
    [self setupView];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setupView];
}

- (void) setupView
{
}

- (void) backButtonClicked:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (UIStatusBarStyle) preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        _tableView.tableHeaderView = [OAUtilities setupTableHeaderViewWithText:OALocalizedString(@"create_profile") font:kHeaderViewFont textColor:UIColor.blackColor lineSpacing:0.0 isTitle:NO];
        [_tableView reloadData];
    } completion:nil];
}

#pragma mark - Table View

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *vw = [[UIView alloc] initWithFrame:CGRectMake(0, 0.0, tableView.bounds.size.width - OAUtilities.getLeftMargin * 2, _heightForHeader)];
    CGFloat textWidth = _tableView.bounds.size.width - (kSidePadding + OAUtilities.getLeftMargin) * 2;
    UILabel *description = [[UILabel alloc] initWithFrame:CGRectMake(kSidePadding + OAUtilities.getLeftMargin, 6.0, textWidth, _heightForHeader)];
    UIFont *labelFont = [UIFont systemFontOfSize:15.0];
    description.font = labelFont;
    [description setTextColor: UIColorFromRGB(color_text_footer)];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setLineSpacing:6];
    description.attributedText = [[NSAttributedString alloc] initWithString:OALocalizedString(@"create_profile_descr") attributes:@{NSParagraphStyleAttributeName : style}];
    description.numberOfLines = 0;
    [vw addSubview:description];
    return vw;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    _heightForHeader = [self heightForLabel:OALocalizedString(@"create_profile_descr")];
    return _heightForHeader + kSidePadding + kTopPadding;
}

- (nonnull UITableViewCell *) tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    static NSString* const identifierCell = @"OAMultiIconTextDescCell";
    OAMultiIconTextDescCell* cell;
    cell = (OAMultiIconTextDescCell *)[tableView dequeueReusableCellWithIdentifier:identifierCell];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OAMultiIconTextDescCell" owner:self options:nil];
        cell = (OAMultiIconTextDescCell *)[nib objectAtIndex:0];
        cell.separatorInset = UIEdgeInsetsMake(0.0, 62.0, 0.0, 0.0);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    OAApplicationMode *am = _profileList[indexPath.row];
    UIImage *img = am.getIcon;
    cell.iconView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.iconView.tintColor = UIColorFromRGB(am.getIconColor);
    cell.textView.text = _profileList[indexPath.row].name;
    cell.descView.text = _profileList[indexPath.row].getProfileDescription;
    [cell setOverflowVisibility:YES];

    return cell;
}

- (NSInteger) tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _profileList.count;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    OAProfileAppearanceViewController* profileAppearanceViewController = [[OAProfileAppearanceViewController alloc] initWithProfile:_profileList[indexPath.row]];
    [self.navigationController pushViewController:profileAppearanceViewController animated:YES];
}

- (CGFloat) heightForLabel:(NSString *)text
{
    UIFont *labelFont = [UIFont systemFontOfSize:15.0];
    CGFloat textWidth = _tableView.bounds.size.width - (kSidePadding + OAUtilities.getLeftMargin) * 2;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, textWidth, CGFLOAT_MAX)];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.font = labelFont;
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = 6.0;
    style.alignment = NSTextAlignmentCenter;
    label.attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{NSParagraphStyleAttributeName : style}];
    [label sizeToFit];
    return label.frame.size.height;
}

@end