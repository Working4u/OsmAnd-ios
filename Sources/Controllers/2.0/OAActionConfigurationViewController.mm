//
//  OAActionConfigurationViewController.m
//  OsmAnd
//
//  Created by Paul on 8/15/19.
//  Copyright © 2019 OsmAnd. All rights reserved.
//

#import "OAActionConfigurationViewController.h"
#import "Localization.h"
#import "OAQuickActionRegistry.h"
#import "OAQuickActionFactory.h"
#import "OAQuickAction.h"
#import "OrderedDictionary.h"
#import "OATextInputCell.h"
#import "OAQuickActionRegistry.h"
#import "OASizes.h"
#import "OAColors.h"
#import "OASwitchTableViewCell.h"
#import "OATextInputIconCell.h"
#import "OAIconTitleValueCell.h"
#import "OAEditColorViewController.h"
#import "OADefaultFavorite.h"
#import "OAEditGroupViewController.h"
#import "OANativeUtilities.h"
#import "OsmAndApp.h"
#import "OABottomSheetActionCell.h"
#import "OAButtonCell.h"
#import "OAActionAddCategoryViewController.h"
#import "OAQuickSearchListItem.h"
#import "OAPOIUIFilter.h"
#import "OAPOIBaseType.h"
#import "OATitleDescrDraggableCell.h"
#import "OAActionAddMapStyleViewController.h"
#import "OAActionAddMapSourceViewController.h"
#import "OATableViewCustomFooterView.h"
#import "OATextInputFloatingCellWithIcon.h"
#import "OAPoiTypeSelectionViewController.h"
#import "OAMultilineTextViewCell.h"

#import <AudioToolbox/AudioServices.h>

#include <OsmAndCore.h>
#include <OsmAndCore/IFavoriteLocation.h>
#include <OsmAndCore/Utilities.h>

#define kTextInputCell @"OATextInputCell"
#define kCellTypeSwitch @"OASwitchTableViewCell"
#define kTextInputIconCell @"OATextInputIconCell"
#define kIconTitleValueCell @"OAIconTitleValueCell"
#define kBottomSheetActionCell @"OABottomSheetActionCell"
#define kButtonCell @"OAButtonCell"
#define kTitleDescrDraggableCell @"OATitleDescrDraggableCell"
#define kTextInputFloatingCellWithIcon @"OATextInputFloatingCellWithIcon"
#define kMultilineTextViewCell @"OAMultilineTextViewCell"

#define kFooterId @"TableViewSectionFooter"

@interface OAActionConfigurationViewController () <UITableViewDelegate, UITableViewDataSource, OAEditColorViewControllerDelegate, OAEditGroupViewControllerDelegate, OAAddCategoryDelegate, MGSwipeTableCellDelegate, OAAddMapStyleDelegate, OAAddMapSourceDelegate, MDCMultilineTextInputLayoutDelegate, UITextViewDelegate, OAPoiTypeSelectionDelegate>
@property (weak, nonatomic) IBOutlet UIView *navBarView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *titleView;
@property (weak, nonatomic) IBOutlet UIButton *backBtn;
@property (weak, nonatomic) IBOutlet UIView *buttonBackgroundView;
@property (weak, nonatomic) IBOutlet UIButton *btnApply;

@end

@implementation OAActionConfigurationViewController
{
    OAQuickAction *_action;
    MutableOrderedDictionary<NSString *, NSArray<NSDictionary *> *> *_data;
    
    OAQuickActionRegistry *_actionRegistry;
    
    BOOL _isNew;
    
    OAEditColorViewController *_colorController;
    OAEditGroupViewController *_groupController;
    
    UIView *_tableHeaderView;
}

-(instancetype) initWithAction:(OAQuickAction *)action isNew:(BOOL)isNew
{
    self = [super init];
    if (self) {
        _action = action;
        _isNew = isNew;
        _actionRegistry = [OAQuickActionRegistry sharedInstance];
        [self commonInit];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupView];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView setEditing:YES];
    self.tableView.allowsMultipleSelectionDuringEditing = NO;
    self.tableView.allowsSelectionDuringEditing = YES;
    [self.tableView registerClass:OATableViewCustomFooterView.class forHeaderFooterViewReuseIdentifier:kFooterId];
    [self.backBtn setImage:[[UIImage imageNamed:@"ic_navbar_chevron"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [self.backBtn setTintColor:UIColor.whiteColor];
    
    if (_action.getActionText)
        [self setupTableHeaderViewWithText:_action.getActionText];
}

- (void) setupTableHeaderViewWithText:(NSString *)text
{
    CGFloat textWidth = DeviceScreenWidth - 32.0 - OAUtilities.getLeftMargin * 2;
    UIFont *labelFont = [UIFont systemFontOfSize:15.0];
    CGSize labelSize = [OAUtilities calculateTextBounds:text width:textWidth font:labelFont];
    _tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, DeviceScreenWidth, labelSize.height + 30.0)];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16.0 + OAUtilities.getLeftMargin, 20.0, textWidth, labelSize.height)];
    label.text = text;
    label.font = labelFont;
    label.textColor = UIColor.blackColor;
    label.backgroundColor = UIColor.clearColor;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _tableHeaderView.backgroundColor = UIColor.clearColor;
    [_tableHeaderView addSubview:label];
    _tableView.tableHeaderView = _tableHeaderView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self applySafeAreaMargins];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

-(void) commonInit
{
    MutableOrderedDictionary *dataModel = [[MutableOrderedDictionary alloc] init];
    [dataModel setObject:@[@{
                           @"type" : kTextInputCell,
                           @"title" : _action.getName
                           }] forKey:OALocalizedString(@"quick_action_name_str")];
    
    OrderedDictionary *actionSpecific = _action.getUIModel;
    [dataModel addEntriesFromDictionary:actionSpecific];
    _data = [MutableOrderedDictionary dictionaryWithDictionary:dataModel];
}

-(void) setupView
{
    _btnApply.layer.cornerRadius = 9.0;
}

- (void)applyLocalization
{
    _titleView.text = _action.getName;
}

-(UIView *) getTopView
{
    return _navBarView;
}

-(UIView *) getMiddleView
{
    return _tableView;
}

- (UIView *)getBottomView
{
    return _buttonBackgroundView;
}

-(CGFloat) getToolBarHeight
{
    return customSearchToolBarHeight;
}

- (NSDictionary *)getItem:(NSIndexPath *)indexPath
{
    NSString *key = _data.allKeys[indexPath.section];
    return _data[key][indexPath.row];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    if (_tableHeaderView)
    {
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            CGFloat textWidth = DeviceScreenWidth - 32.0 - OAUtilities.getLeftMargin * 2;
            UIFont *labelFont = [UIFont systemFontOfSize:15.0];
            CGSize labelSize = [OAUtilities calculateTextBounds:OALocalizedString(@"quick_action_add_actions_descr") width:textWidth font:labelFont];
            _tableHeaderView.frame = CGRectMake(0.0, 0.0, DeviceScreenWidth, labelSize.height + 30.0);
            _tableHeaderView.subviews.firstObject.frame = CGRectMake(16.0 + OAUtilities.getLeftMargin, 20.0, textWidth, labelSize.height);
        } completion:nil];
    }
}

-(void)onNameChanged:(UITextView *)textView
{
    NSString *nameKey = OALocalizedString(@"quick_action_name_str");
    NSMutableDictionary *actionName = [NSMutableDictionary dictionaryWithDictionary:_data[nameKey].firstObject];
    NSString *newTitle = textView.text;
    [actionName setObject:newTitle forKey:@"title"];
    [_data setObject:@[[NSDictionary dictionaryWithDictionary:actionName]] forKey:nameKey];
    [_action setName:newTitle];
}

-(void)onTextFieldChanged:(UITextView *)textView
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:textView.tag & 0x3FF inSection:textView.tag >> 10];
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:[self getItem:indexPath]];
    NSString *key = _data.allKeys[indexPath.section];
    NSMutableArray *arr = [NSMutableArray arrayWithArray:_data[key]];
    [item setObject:textView.text forKey:@"title"];
    [arr setObject:item atIndexedSubscript:indexPath.row];
    [_data setObject:[NSArray arrayWithArray:arr] forKey:key];
}

- (OATextInputFloatingCellWithIcon *)getInputCellWithHint:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    OATextInputFloatingCellWithIcon *resultCell = nil;
    resultCell = [self.tableView dequeueReusableCellWithIdentifier:kTextInputFloatingCellWithIcon];
    if (resultCell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kTextInputFloatingCellWithIcon owner:self options:nil];
        resultCell = (OATextInputFloatingCellWithIcon *)[nib objectAtIndex:0];
    }
    if (item[@"img"] && ![item[@"img"] isEqualToString:@""]) {
        resultCell.buttonView.hidden = NO;
        [resultCell.buttonView setImage:[UIImage imageNamed:item[@"img"]] forState:UIControlStateNormal];
        [resultCell.buttonView addTarget:self action:@selector(deleteTagPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    else
        resultCell.buttonView.hidden = YES;
    
    resultCell.fieldLabel.text = item[@"hint"];
    MDCMultilineTextField *textField = resultCell.textField;
    textField.underline.hidden = YES;
    textField.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.placeholder = @"";
    [textField.textView setText:item[@"title"]];
    textField.textView.delegate = self;
    textField.textView.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.layoutDelegate = self;
    [textField.clearButton addTarget:self action:@selector(clearButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    textField.font = [UIFont systemFontOfSize:17.0];
    textField.clearButton.imageView.tintColor = UIColorFromRGB(color_icon_color);
    [textField.clearButton setImage:[[UIImage imageNamed:@"ic_custom_clear_field"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [textField.clearButton setImage:[[UIImage imageNamed:@"ic_custom_clear_field"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateHighlighted];
    
    return resultCell;
}

- (void) deleteTagPressed:(id)sender
{
    NSIndexPath *indexPath = [self indexPathForCellContainingView:sender inTableView:self.tableView];
    [self.tableView beginUpdates];
    NSDictionary *item = [self getItem:indexPath];
    NSString *key = _data.allKeys[indexPath.section];
    NSMutableArray *items = [NSMutableArray arrayWithArray:_data[key]];
    NSIndexPath *valuePath = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
    [items removeObject:item];
    [items removeObject:[self getItem:valuePath]];
    [_data setObject:[NSArray arrayWithArray:items] forKey:key];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath, valuePath] withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView endUpdates];
}

- (NSIndexPath *)indexPathForCellContainingView:(UIView *)view inTableView:(UITableView *)tableView {
    CGPoint viewCenterRelativeToTableview = [tableView convertPoint:CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds)) fromView:view];
    NSIndexPath *cellIndexPath = [tableView indexPathForRowAtPoint:viewCenterRelativeToTableview];
    return cellIndexPath;
}

-(void) clearButtonPressed:(UIButton *)sender
{
    NSIndexPath *indexPath = [self indexPathForCellContainingView:sender inTableView:self.tableView];
    [self.tableView beginUpdates];
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:[self getItem:indexPath]];
    NSString *key = _data.allKeys[indexPath.section];
    NSMutableArray *items = [NSMutableArray arrayWithArray:_data[key]];
    [item setObject:@"" forKey:@"title"];
    [items setObject:[NSDictionary dictionaryWithDictionary:item] atIndexedSubscript:indexPath.row];
    [_data setObject:[NSArray arrayWithArray:items] forKey:key];
    [self.tableView endUpdates];
}

- (IBAction)backPressed:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)applyPressed:(id)sender
{
    if (![_action fillParams:_data])
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:OALocalizedString(@"quick_action_fill_params_alert") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_ok") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    if ([_actionRegistry isNameUnique:_action])
    {
        if (_isNew)
            [_actionRegistry addQuickAction:_action];
        else
            [_actionRegistry updateQuickAction:_action];
        [_actionRegistry.quickActionListChangedObservable notifyEvent];
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    else
    {
        _action = [_actionRegistry generateUniqueName:_action];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:[NSString stringWithFormat:OALocalizedString(@"quick_action_name_alert"), _action.getName] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_ok") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            if (_isNew)
                [_actionRegistry addQuickAction:_action];
            else
                [_actionRegistry updateQuickAction:_action];
            [_actionRegistry.quickActionListChangedObservable notifyEvent];
            [self.navigationController popToRootViewControllerAnimated:YES];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)applyParameter:(id)sender
{
    if ([sender isKindOfClass:[UISwitch class]])
    {
        UISwitch *sw = (UISwitch *)sender;
        BOOL isChecked = sw.on;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:sw.tag & 0x3FF inSection:sw.tag >> 10];
        NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:[self getItem:indexPath]];
        [item setObject:@(isChecked) forKey:@"value"];
        NSString *key = _data.allKeys[indexPath.section];
        NSMutableArray *arr = [NSMutableArray arrayWithArray:_data[key]];
        [arr setObject:item atIndexedSubscript:indexPath.row];
        [_data setObject:[NSArray arrayWithArray:arr] forKey:key];
    }
}

- (NSArray *)getItemGroups
{
    return [[OANativeUtilities QListOfStringsToNSMutableArray:[OsmAndApp instance].favoritesCollection->getGroups().toList()] copy];
}

- (NSMutableArray *)getItemNames
{
    NSMutableArray *arr = [NSMutableArray new];
    for (NSDictionary *item in _data[_data.allKeys.lastObject])
    {
        if (![item[@"type"] isEqualToString:kButtonCell])
            [arr addObject:item[@"title"]];
    }
    return arr;
}

- (void) addCategory
{
    NSMutableArray * arr = [self getItemNames];
    OAActionAddCategoryViewController *categorySelection = [[OAActionAddCategoryViewController alloc] initWithNames:arr];
    categorySelection.delegate = self;
    [self.navigationController pushViewController:categorySelection animated:YES];
}

- (void) addMapStyle
{
    NSMutableArray * arr = [self getItemNames];
    OAActionAddMapStyleViewController *mapStyleScreen = [[OAActionAddMapStyleViewController alloc] initWithNames:arr];
    mapStyleScreen.delegate = self;
    [self.navigationController pushViewController:mapStyleScreen animated:YES];
}

- (void) addMapOverlay
{
    NSMutableArray * arr = [self getItemNames];
    OAActionAddMapSourceViewController *mapSourceScreen = [[OAActionAddMapSourceViewController alloc] initWithNames:arr type:EOAMapSourceTypeOverlay];
    mapSourceScreen.delegate = self;
    [self.navigationController pushViewController:mapSourceScreen animated:YES];
}

- (void) addMapUnderlay
{
    NSMutableArray * arr = [self getItemNames];
    OAActionAddMapSourceViewController *mapSourceScreen = [[OAActionAddMapSourceViewController alloc] initWithNames:arr type:EOAMapSourceTypeUnderlay];
    mapSourceScreen.delegate = self;
    [self.navigationController pushViewController:mapSourceScreen animated:YES];
}

- (void) addMapSource
{
    NSMutableArray * arr = [self getItemNames];
    OAActionAddMapSourceViewController *mapSourceScreen = [[OAActionAddMapSourceViewController alloc] initWithNames:arr type:EOAMapSourceTypePrimary];
    mapSourceScreen.delegate = self;
    [self.navigationController pushViewController:mapSourceScreen animated:YES];
}

- (void) addTagValue:(id)sender
{
    if ([sender isKindOfClass:UIButton.class])
    {
        [self.tableView beginUpdates];
        UIButton *btn = (UIButton *) sender;
        NSIndexPath *indexPath = [self indexPathForCellContainingView:btn inTableView:self.tableView];
        NSString *key = _data.allKeys[indexPath.section];
        NSMutableArray *arr = [NSMutableArray arrayWithArray:_data[key]];
        NSDictionary *buttonModel = arr.lastObject;
        [arr removeLastObject];
        [arr addObject:@{
                         @"type" : @"OATextInputFloatingCellWithIcon",
                         @"hint" : OALocalizedString(@"osm_tag"),
                         @"title" : @"",
                         @"img" : @"ic_custom_delete"
                         }];
        [arr addObject:@{
                         @"type" : @"OATextInputFloatingCellWithIcon",
                         @"hint" : OALocalizedString(@"osm_value"),
                         @"title" : @"",
                         @"img" : @""
                         }];
        [arr addObject:buttonModel];
        [_data setObject:[NSArray arrayWithArray:arr] forKey:key];
        NSIndexPath *keyPath = indexPath;
        NSIndexPath *valuePath = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
        NSIndexPath *newBtnPath = [NSIndexPath indexPathForRow:indexPath.row + 2 inSection:indexPath.section];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView insertRowsAtIndexPaths:@[keyPath, valuePath, newBtnPath] withRowAnimation:UITableViewRowAnimationTop];
        [self.tableView endUpdates];
        [self.tableView scrollToRowAtIndexPath:newBtnPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if ([item[@"key"] isEqualToString:@"category_name"])
    {
        _groupController = [[OAEditGroupViewController alloc] initWithGroupName:item[@"value"] groups:[self getItemGroups]];
        _groupController.delegate = self;
        [self.navigationController pushViewController:_groupController animated:YES];
    }
    else if ([item[@"key"] isEqualToString:@"category_color"])
    {
        OAFavoriteColor *favCol = [OADefaultFavorite builtinColors][[item[@"color"] integerValue]];
        _colorController = [[OAEditColorViewController alloc] initWithColor:favCol.color];
        _colorController.delegate = self;
        [self.navigationController pushViewController:_colorController animated:YES];
    }
    else if ([item[@"key"] isEqualToString:@"key_category"])
    {
        OAPoiTypeSelectionViewController *poiTypeSelection = [[OAPoiTypeSelectionViewController alloc] initWithType:POI_TYPE_SCREEN];
        poiTypeSelection.delegate = self;
        [self.navigationController pushViewController:poiTypeSelection animated:YES];
    }
    else if ([item[@"type"] isEqualToString:kTextInputFloatingCellWithIcon])
    {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if ([cell canBecomeFirstResponder])
            [cell becomeFirstResponder];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if ([item[@"type"] isEqualToString:kTextInputCell])
    {
        OATextInputCell* cell = [tableView dequeueReusableCellWithIdentifier:kTextInputCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kTextInputCell owner:self options:nil];
            cell = (OATextInputCell *)[nib objectAtIndex:0];
        }
        
        if (cell)
        {
            if (_action.isActionEditable)
            {
                cell.inputField.text = item[@"title"];
                [cell.inputField addTarget:self action:@selector(onNameChanged:) forControlEvents:UIControlEventEditingChanged];
            }
            else
            {
                cell.inputField.placeholder = item[@"title"];
            }
            cell.userInteractionEnabled = _action.isActionEditable;
        }
        
        return cell;
    }
    else if ([item[@"type"] isEqualToString:kCellTypeSwitch])
    {
        static NSString* const identifierCell = @"OASwitchTableViewCell";
        OASwitchTableViewCell* cell = nil;
        
        cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OASwitchCell" owner:self options:nil];
            cell = (OASwitchTableViewCell *)[nib objectAtIndex:0];
            cell.textView.numberOfLines = 0;
        }
        
        if (cell)
        {
            [cell.textView setText: item[@"title"]];
            cell.switchView.on = [item[@"value"] boolValue];
            cell.switchView.tag = indexPath.section << 10 | indexPath.row;
            [cell.switchView addTarget:self action:@selector(applyParameter:) forControlEvents:UIControlEventValueChanged];
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:kTextInputIconCell])
    {
        OATextInputIconCell* cell = [tableView dequeueReusableCellWithIdentifier:kTextInputIconCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kTextInputIconCell owner:self options:nil];
            cell = (OATextInputIconCell *)[nib objectAtIndex:0];
        }
        
        if (cell)
        {
            cell.inputField.text = item[@"title"];
            cell.inputField.placeholder = item[@"hint"];
            cell.inputField.tag = indexPath.section << 10 | indexPath.row;
            [cell.inputField addTarget:self action:@selector(onTextFieldChanged:) forControlEvents:UIControlEventEditingChanged];
            NSString *imgName = item[@"img"];
            if (imgName && imgName.length > 0)
            {
                [cell.iconView setImage:[[UIImage imageNamed:imgName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
                cell.iconView.tintColor = UIColorFromRGB(color_text_footer);
            }
        }
        
        return cell;
    }
    else if ([item[@"type"] isEqualToString:kIconTitleValueCell])
    {
        static NSString* const identifierCell = kIconTitleValueCell;
        OAIconTitleValueCell* cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kIconTitleValueCell owner:self options:nil];
            cell = (OAIconTitleValueCell *)[nib objectAtIndex:0];
        }
        if (cell)
        {
            cell.textView.text = item[@"title"];
            OAFavoriteColor *color = [OADefaultFavorite builtinColors][[item[@"color"] integerValue]];
            if (item[@"img"])
            {
                cell.leftImageView.layer.cornerRadius = 0.;
                cell.leftImageView.image = [[UIImage imageNamed:item[@"img"]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                cell.leftImageView.tintColor = color.color;
            }
            else if ([item[@"key"] isEqualToString:@"category_color"])
            {
                cell.leftImageView.layer.cornerRadius = cell.leftImageView.frame.size.height / 2;
                cell.leftImageView.backgroundColor = color.color;
            }
            else
            {
                [cell showImage:NO];
            }
            
            cell.descriptionView.text = item[@"value"];
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:kBottomSheetActionCell])
    {
        static NSString* const identifierCell = kBottomSheetActionCell;
        OABottomSheetActionCell* cell = nil;
        
        cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kBottomSheetActionCell owner:self options:nil];
            cell = (OABottomSheetActionCell *)[nib objectAtIndex:0];
        }
        
        if (cell)
        {
            UIImage *img = nil;
            NSString *imgName = item[@"img"];
            if (imgName)
                img = [OAUtilities getMxIcon:imgName];
            
            cell.textView.text = item[@"title"];
            NSString *desc = item[@"descr"];
            cell.descView.text = desc;
            cell.descView.hidden = desc.length == 0;
            [cell.iconView setTintColor:UIColorFromRGB(color_icon_color)];
            cell.iconView.image = img;
            cell.separatorInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:kButtonCell])
    {
        static NSString* const identifierCell = kButtonCell;
        OAButtonCell* cell = nil;
        
        cell = [self.tableView dequeueReusableCellWithIdentifier:identifierCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kButtonCell owner:self options:nil];
            cell = (OAButtonCell *)[nib objectAtIndex:0];
        }
        if (cell)
        {
            [cell.button setTitle:item[@"title"] forState:UIControlStateNormal];
            [cell.button addTarget:self action:NSSelectorFromString(item[@"target"]) forControlEvents:UIControlEventTouchDown];
            [cell.button setTintColor:UIColorFromRGB(color_primary_purple)];
            [cell showImage:NO];
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:kTitleDescrDraggableCell])
    {
        OATitleDescrDraggableCell* cell = (OATitleDescrDraggableCell *)[tableView dequeueReusableCellWithIdentifier:kTitleDescrDraggableCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kTitleDescrDraggableCell owner:self options:nil];
            cell = (OATitleDescrDraggableCell *)[nib objectAtIndex:0];
        }
        
        if (cell)
        {
            [cell.textView setText:item[@"title"]];
            cell.descView.hidden = YES;
            [cell.iconView setImage:[UIImage imageNamed:item[@"img"]]];
            if (cell.iconView.subviews.count > 0)
                [[cell.iconView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
            cell.delegate = self;
            cell.allowsSwipeWhenEditing = NO;
            cell.overflowButton.hidden = YES;
            cell.separatorInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:kTextInputFloatingCellWithIcon])
    {
        return [self getInputCellWithHint:indexPath];
    }
    else if ([item[@"type"] isEqualToString:kMultilineTextViewCell])
    {
        OAMultilineTextViewCell* cell = (OAMultilineTextViewCell *)[tableView dequeueReusableCellWithIdentifier:kMultilineTextViewCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kMultilineTextViewCell owner:self options:nil];
            cell = (OAMultilineTextViewCell *)[nib objectAtIndex:0];
        }
        
        if (cell)
        {
            MDCMultilineTextField *textField = cell.inputField;
            textField.underline.hidden = YES;
            textField.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
            textField.placeholder = item[@"hint"];
            [textField.textView setText:item[@"title"]];
            textField.textView.delegate = self;
            textField.textView.autocorrectionType = UITextAutocorrectionTypeNo;
            textField.layoutDelegate = self;
            [textField.clearButton addTarget:self action:@selector(clearButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            textField.font = [UIFont systemFontOfSize:17.0];
            textField.clearButton.imageView.tintColor = UIColorFromRGB(color_icon_color);
            [textField.clearButton setImage:[[UIImage imageNamed:@"ic_custom_clear_field"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
            [textField.clearButton setImage:[[UIImage imageNamed:@"ic_custom_clear_field"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateHighlighted];
        }
        return cell;
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.allKeys.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *key = _data.allKeys[section];
    NSString *footer = _data[key].lastObject[@"footer"];
    return _data[key].count - (footer != nil ? 1 : 0);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *header = _data.allKeys[section];
    if ([header hasPrefix:kSectionNoName])
        return nil;
    
    return header;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSArray *data = _data[_data.allKeys[section]];
    NSString *text = data.lastObject[@"footer"];
    NSString *url = data.lastObject[@"url"];
    if (!text && !url)
        return nil;
    else if (!text)
        text = @"";
    
    OATableViewCustomFooterView *vw = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kFooterId];
    if (url)
    {
        NSURL *URL = [NSURL URLWithString:url];
        UIFont *textFont = [UIFont systemFontOfSize:13];
        NSMutableAttributedString * str = [[NSMutableAttributedString alloc] initWithString:url attributes:@{NSFontAttributeName : textFont}];
        [str addAttribute:NSLinkAttributeName value:URL range: NSMakeRange(0, str.length)];
        text = [text stringByAppendingString:@"\n"];
        NSMutableAttributedString *textStr = [[NSMutableAttributedString alloc] initWithString:text
                                                                                    attributes:@{NSFontAttributeName : textFont,
                                                                                                 NSForegroundColorAttributeName : UIColorFromRGB(color_text_footer)}];
        [textStr appendAttributedString:str];
        vw.label.attributedText = textStr;
    }
    else
    {
        vw.label.text = text;
    }
    return vw;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    NSArray *data = _data[_data.allKeys[section]];
    NSString *text = data.lastObject[@"footer"];
    NSString *url = data.lastObject[@"url"];
    if (!text && !url)
    {
        return 0.01;
    }
    else
    {
        return [OATableViewCustomFooterView getHeight:url ? [NSString stringWithFormat:@"%@ %@", text, OALocalizedString(@"shared_string_read_more")] : text width:tableView.bounds.size.width];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if ([item[@"type"] isEqualToString:kIconTitleValueCell])
    {
        return [OAIconTitleValueCell getHeight:item[@"title"] value:item[@"value"] cellWidth:tableView.bounds.size.width];
    }
    else if ([item[@"type"] isEqualToString:kBottomSheetActionCell])
    {
        return [OABottomSheetActionCell getHeight:item[@"title"] value:nil cellWidth:tableView.bounds.size.width];
    }
    else if ([item[@"type"] isEqualToString:kTitleDescrDraggableCell])
    {
        [OATitleDescrDraggableCell getHeight:item[@"title"] value:@"" cellWidth:DeviceScreenWidth];
    }
    else if ([item[@"type"] isEqualToString:kTextInputFloatingCellWithIcon])
    {
        return [OATextInputFloatingCellWithIcon getHeight:item[@"title"] desc:item[@"hint"] cellWidth:DeviceScreenWidth];
    }
    else if ([item[@"type"] isEqualToString:kMultilineTextViewCell])
    {
        return [OAMultilineTextViewCell getHeight:item[@"title"] cellWidth:DeviceScreenWidth];
    }
    return 44.0;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if ([item[@"type"] isEqualToString:kBottomSheetActionCell] || [item[@"type"] isEqualToString:kTitleDescrDraggableCell])
        return YES;
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        NSDictionary *item = [self getItem:indexPath];
        NSString *key = _data.allKeys.lastObject;
        NSMutableArray *arr = [NSMutableArray arrayWithArray:_data[key]];
        [arr removeObject:item];
        [_data setObject:arr forKey:key];
        [_tableView beginUpdates];
        [_tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [_tableView endUpdates];
    }
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    NSString *key = _data.allKeys[sourceIndexPath.section];
    NSMutableArray *items = [NSMutableArray arrayWithArray:_data[key]];
    NSDictionary *source = [self getItem:sourceIndexPath];
    NSDictionary *dest = [self getItem:destinationIndexPath];
    [items setObject:source atIndexedSubscript:destinationIndexPath.row];
    [items setObject:dest atIndexedSubscript:sourceIndexPath.row];
    [_data setObject:[NSArray arrayWithArray:items] forKey:key];
    
    [_tableView reloadData];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    return [item[@"type"] isEqualToString:kTitleDescrDraggableCell];;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    NSInteger lastItem = [tableView numberOfRowsInSection:sourceIndexPath.section] - 1;
    if (proposedDestinationIndexPath.section != sourceIndexPath.section || proposedDestinationIndexPath.row >= lastItem)
        return sourceIndexPath;
    else
        return proposedDestinationIndexPath;
}

#pragma mark - Keyboard Notifications

- (void) keyboardWillShow:(NSNotification *)notification;
{
    NSDictionary *userInfo = [notification userInfo];
    NSValue *keyboardBoundsValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGFloat keyboardHeight = [keyboardBoundsValue CGRectValue].size.height;
    
    CGFloat duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    NSInteger animationCurve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0. options:animationCurve animations:^{
        _buttonBackgroundView.frame = CGRectMake(0, DeviceScreenHeight - keyboardHeight - 44.0, _buttonBackgroundView.frame.size.width, 44.0);
        [self applyHeight:32.0 cornerRadius:4.0 toView:_btnApply];
        UIEdgeInsets insets = [self.tableView contentInset];
        [self.tableView setContentInset:UIEdgeInsetsMake(insets.top, insets.left, keyboardHeight, insets.right)];
        [self.tableView setScrollIndicatorInsets:self.tableView.contentInset];
        [[self view] layoutIfNeeded];
    } completion:nil];
}

- (void) keyboardWillHide:(NSNotification *)notification;
{
    NSDictionary *userInfo = [notification userInfo];
    CGFloat duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    NSInteger animationCurve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0. options:animationCurve animations:^{
        [self applySafeAreaMargins];
        [self applyHeight:42.0 cornerRadius:9.0 toView:_btnApply];
        UIEdgeInsets insets = [self.tableView contentInset];
        [self.tableView setContentInset:UIEdgeInsetsMake(insets.top, insets.left, 0.0, insets.right)];
        [self.tableView setScrollIndicatorInsets:self.tableView.contentInset];
        [[self view] layoutIfNeeded];
    } completion:nil];
}

-(void) applyHeight:(CGFloat)height cornerRadius:(CGFloat)radius toView:(UIView *)button
{
    CGRect buttonFrame = button.frame;
    buttonFrame.size.height = height;
    button.frame = buttonFrame;
    button.layer.cornerRadius = radius;
}

#pragma mark - OAEditColorViewControllerDelegate

- (void)colorChanged
{
    NSString *key = _data.allKeys.lastObject;
    NSArray *colorItems = _data[key];
    NSMutableArray *newItems = [NSMutableArray new];
    for (NSDictionary *item in colorItems)
    {
        if (!item[@"footer"])
        {
            NSMutableDictionary *mutableItem = [NSMutableDictionary dictionaryWithDictionary:item];
            [mutableItem setObject:@(_colorController.colorIndex) forKey:@"color"];
            if ([item[@"key"] isEqualToString:@"category_color"])
            {
                OAFavoriteColor *col = [OADefaultFavorite builtinColors][_colorController.colorIndex];
                [mutableItem setObject:col.name forKey:@"value"];
            }
            [newItems addObject:[NSDictionary dictionaryWithDictionary:mutableItem]];
        }
        else
        {
            [newItems addObject:item];
        }
    }
    [_data setObject:[NSArray arrayWithArray:newItems] forKey:key];
    [self.tableView reloadData];
}

#pragma mark - OAEditGroupViewControllerDelegate

- (void) groupChanged
{
    NSString *key = _data.allKeys.lastObject;
    NSArray *items = _data[key];
    NSMutableArray *newItems = [NSMutableArray new];
    for (NSDictionary *item in items)
    {
        if ([item[@"key"] isEqualToString:@"category_name"])
        {
            NSMutableDictionary *mutableItem = [NSMutableDictionary dictionaryWithDictionary:item];
            [mutableItem setObject:_groupController.groupName forKey:@"value"];
            [newItems addObject:[NSDictionary dictionaryWithDictionary:mutableItem]];
        }
        else
        {
            [newItems addObject:item];
        }
    }
    [_data setObject:[NSArray arrayWithArray:newItems] forKey:key];
    [self.tableView reloadData];
}

#pragma mark - OAAddCategoryDelegate

- (void) onCategoriesSelected:(NSArray *)items
{
    NSString *key = _data.allKeys.lastObject;
    NSArray *rows = _data[key];
    NSDictionary *button = rows.lastObject;
    NSMutableArray *newItems = [NSMutableArray new];
    for (id item in items)
    {
        if ([item isKindOfClass:OAPOIUIFilter.class])
        {
            OAPOIUIFilter *filter = (OAPOIUIFilter *)item;
            NSString *iconId = filter.getIconId ? filter.getIconId : @"user_defined";
            [newItems addObject:@{
                                  @"title" : filter.getName,
                                  @"value" : filter.filterId,
                                  @"type" : @"OABottomSheetActionCell",
                                  @"img" : iconId
                                  }];
        }
        else if ([item isKindOfClass:OAPOIBaseType.class])
        {
            OAPOIBaseType *filter = (OAPOIBaseType *)item;
            [newItems addObject:@{
                                  @"title" : filter.nameLocalized,
                                  @"value" : [STD_PREFIX stringByAppendingString:filter.name],
                                  @"type" : @"OABottomSheetActionCell",
                                  @"img" : filter.name
                                  }];
        }
        
    }
    [newItems addObject:button];
    [_data setObject:[NSArray arrayWithArray:newItems] forKey:key];
    [_tableView reloadData];
}

#pragma mark - OAAddMapStyleDelegate

- (void) onMapStylesSelected:(NSArray *)items
{
    NSString *key = _data.allKeys.lastObject;
    NSArray *rows = _data[key];
    NSDictionary *button = rows.lastObject;
    NSMutableArray *newItems = [NSMutableArray new];
    for (NSString *item in items)
    {
        [newItems addObject:@{
                              @"type" : @"OATitleDescrDraggableCell",
                              @"title" : item,
                              @"img" : @"ic_custom_show_on_map"
                              }];
    }
    [newItems addObject:button];
    [_data setObject:[NSArray arrayWithArray:newItems] forKey:key];
    NSMutableDictionary *actionName = [NSMutableDictionary dictionaryWithDictionary:_data[OALocalizedString(@"quick_action_name_str")].firstObject];
    NSString *nameKey = OALocalizedString(@"quick_action_name_str");
    NSString *oldTitle = [_action getTitle:_action.getParams[_action.getListKey]];
    NSString *defaultName = [OAQuickActionFactory getActionName:_action.type];
    
    if ([actionName[@"title"] isEqualToString:defaultName] || [actionName[@"title"] isEqualToString:oldTitle])
    {
        NSString *newTitle = [_action getTitle:items];
        [actionName setObject:newTitle forKey:@"title"];
        [_data setObject:@[[NSDictionary dictionaryWithDictionary:actionName]] forKey:nameKey];
        [_action setName:newTitle];
    }
    [_tableView reloadData];
}

#pragma mark - OAAddMapSourceDelegate

- (void)onMapSourceSelected:(NSArray *)items
{
    NSString *key = _data.allKeys.lastObject;
    NSArray *rows = _data[key];
    NSDictionary *button = rows.lastObject;
    NSMutableArray *newItems = [NSMutableArray new];
    for (NSArray *item in items)
    {
        [newItems addObject:@{
                              @"type" : @"OATitleDescrDraggableCell",
                              @"title" : item.lastObject,
                              @"value" : item.firstObject,
                              @"img" : @"ic_custom_show_on_map"
                              }];
    }
    [newItems addObject:button];
    [_data setObject:[NSArray arrayWithArray:newItems] forKey:key];
    NSString *nameKey = OALocalizedString(@"quick_action_name_str");
    NSMutableDictionary *actionName = [NSMutableDictionary dictionaryWithDictionary:_data[nameKey].firstObject];
    NSString *oldTitle = [_action getTitle:_action.getParams[_action.getListKey]];
    NSString *defaultName = [OAQuickActionFactory getActionName:_action.type];
    
    if ([actionName[@"title"] isEqualToString:defaultName] || [actionName[@"title"] isEqualToString:oldTitle])
    {
        NSString *newTitle = [_action getTitle:items];
        [actionName setObject:newTitle forKey:@"title"];
        [_data setObject:@[[NSDictionary dictionaryWithDictionary:actionName]] forKey:nameKey];
        [_action setName:newTitle];
    }
    [_tableView reloadData];
}

#pragma mark - Swipe Delegate

- (BOOL) swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction;
{
    return _tableView.isEditing;
}

- (void) swipeTableCell:(MGSwipeTableCell *)cell didChangeSwipeState:(MGSwipeState)state gestureIsActive:(BOOL)gestureIsActive
{
    if (state != MGSwipeStateNone)
        cell.showsReorderControl = NO;
    else
        cell.showsReorderControl = YES;
}

#pragma mark - MDCMultilineTextInputLayoutDelegate

- (void)multilineTextField:(id<MDCMultilineTextInput> _Nonnull)multilineTextField
      didChangeContentSize:(CGSize)size
{
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

#pragma mark - UITextViewDelegate

-(void)textViewDidChange:(UITextView *)textView
{
    [self textChanged:textView userInput:YES];
}

- (void) textChanged:(UITextView * _Nonnull)textView userInput:(BOOL)userInput
{
    NSIndexPath *indexPath = [self indexPathForCellContainingView:textView inTableView:self.tableView];
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:[self getItem:indexPath]];
    NSString *key = _data.allKeys[indexPath.section];
    NSMutableArray *items = [NSMutableArray arrayWithArray:_data[key]];
    [item setObject:textView.text forKey:@"title"];
    [items setObject:[NSDictionary dictionaryWithDictionary:item] atIndexedSubscript:indexPath.row];
    [_data setObject:[NSArray arrayWithArray:items] forKey:key];
}

#pragma mark - OAPoiTypeSelectionDelegate

- (void)onPoiTypeSelected:(NSString *)name
{
    NSString *key = OALocalizedString(@"poi_type");
    NSMutableArray *arr = [NSMutableArray arrayWithArray:_data[key]];
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:arr.firstObject];
    [item setObject:name forKey:@"value"];
    [arr setObject:item atIndexedSubscript:0];
    [_data setObject:[NSArray arrayWithArray:arr] forKey:key];
    [self.tableView reloadData];
}

@end