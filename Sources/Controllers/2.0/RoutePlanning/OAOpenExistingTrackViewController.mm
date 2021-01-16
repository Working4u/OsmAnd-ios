//
//  OAOpenExistingTrackViewController.m
//  OsmAnd Maps
//
//  Created by Anna Bibyk on 15.01.2021.
//  Copyright © 2021 OsmAnd. All rights reserved.
//

#import "OAOpenExistingTrackViewController.h"
#import "OsmAndApp.h"
#import "OARootViewController.h"
#import "Localization.h"
#import "OAColors.h"
#import "OAGPXDatabase.h"
#import "OAGPXRouter.h"
#import "OAGPXRouteDocument.h"
#import "OsmAndApp.h"
#import "OAGPXTrackCell.h"
#import "OASegmentTableViewCell.h"
#import "OAUtilities.h"

#define kGPXTrackCell @"OAGPXTrackCell"
#define kCellTypeSegment @"OASegmentTableViewCell"

#define kVerticalMargin 16.
#define kHorizontalMargin 16.

typedef NS_ENUM(NSInteger, EOASortingMode) {
    EOAModifiedDate = 0,
    EOANameAscending,
    EOANameDescending
};

@interface OAOpenExistingTrackViewController() <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate>

@end

@implementation OAOpenExistingTrackViewController
{
    NSArray<NSArray<NSDictionary *> *> *_data;
    EOASortingMode _sortingMode;
    EOAScreenType _screenType;
}

- (instancetype) initWithScreen:(EOAScreenType)screenType
{
    self = [super init];
    if (self)
    {
        _screenType = screenType;
        [self generateData];
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    _sortingMode = EOAModifiedDate;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (_screenType == EOAAddToATrack)
        self.tableView.tableHeaderView = [OAUtilities setupTableHeaderViewWithText:OALocalizedString(@"route_between_points_add_track_desc") font:[UIFont systemFontOfSize:15.] textColor:UIColor.blackColor lineSpacing:0. isTitle:NO];
}

- (void) applyLocalization
{
    [super applyLocalization];
    self.titleLabel.text = OALocalizedString(@"plan_route_open_existing_track");
}

- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    if (_screenType == EOAAddToATrack)
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            self.tableView.tableHeaderView = [OAUtilities setupTableHeaderViewWithText:OALocalizedString(@"route_between_points_add_track_desc") font:[UIFont systemFontOfSize:15.] textColor:UIColor.blackColor lineSpacing:0. isTitle:NO];
            [self.tableView reloadData];
        } completion:nil];
}

- (void) generateData
{
    NSMutableArray *data = [NSMutableArray new];
    NSMutableArray *existingTracksSection = [NSMutableArray new];
    OAGPXDatabase *db = [OAGPXDatabase sharedDb];
    NSArray *gpxList = [NSMutableArray arrayWithArray:[self sortData:db.gpxList]];
    
    [existingTracksSection addObject:@{
        @"type" : kCellTypeSegment,
        @"title0" : OALocalizedString(@"osm_modified"),
        @"title1" : OALocalizedString(@"shared_a_z"),
        @"title2" : OALocalizedString(@"shared_z_a"),
        @"key" : @"segment_control"
    }];
    for (OAGPX *gpx in gpxList)
    {
        // TODO: check these parameters
        double distance = [OAGPXRouter sharedInstance].routeDoc.totalDistance;
        NSTimeInterval duration = [[OAGPXRouter sharedInstance] getRouteDuration];
        NSString *timeMovingStr = [[OsmAndApp instance] getFormattedTimeInterval:duration shortFormat:NO];
        
        [existingTracksSection addObject:@{
                @"type" : kGPXTrackCell,
                @"track" : gpx,
                @"title" : [gpx getNiceTitle],
                @"distance" : [NSString stringWithFormat:@"%f.", distance],
                @"time" : timeMovingStr,
                @"wpt" : [NSString stringWithFormat:@"%d", gpx.wptPoints],
                @"key" : @"gpx_route"
            }];
    }
    [data addObject:existingTracksSection];
    _data = data;
}

- (NSArray *) sortData:(NSArray *)data
{
    NSArray *sortedData = [data sortedArrayUsingComparator:^NSComparisonResult(OAGPX *obj1, OAGPX *obj2) {
        switch (_sortingMode) {
            case EOAModifiedDate:
            {
                NSDate *time1 = [OAUtilities getFileLastModificationDate:obj1.gpxFileName];
                NSDate *time2 = [OAUtilities getFileLastModificationDate:obj2.gpxFileName];
                return [time2 compare:time1];
            }
            case EOANameAscending:
                return [obj1.gpxTitle compare:obj2.gpxTitle options:NSCaseInsensitiveSearch];
            case EOANameDescending:
                return  [obj2.gpxTitle compare:obj1.gpxTitle options:NSCaseInsensitiveSearch];
            default:
                break;
        }
    }];
    return sortedData;
}

#pragma mark - TableView

- (nonnull UITableViewCell *) tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    NSString *type = item[@"type"];
    if ([type isEqualToString:kCellTypeSegment])
    {
        static NSString* const identifierCell = @"OASegmentTableViewCell";
        OASegmentTableViewCell* cell = nil;
        cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"OASegmentTableViewCell" owner:self options:nil];
            cell = (OASegmentTableViewCell *)[nib objectAtIndex:0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell.segmentControl insertSegmentWithTitle:item[@"title2"] atIndex:2 animated:NO];
        }
        if (cell)
        {
            [cell.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
            [cell.segmentControl setTitle:item[@"title0"] forSegmentAtIndex:0];
            [cell.segmentControl setTitle:item[@"title1"] forSegmentAtIndex:1];
        }
        return cell;
    }
    else if ([type isEqualToString:kGPXTrackCell])
    {
        static NSString* const identifierCell = kGPXTrackCell;
        OAGPXTrackCell* cell = nil;
        cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:kGPXTrackCell owner:self options:nil];
            cell = (OAGPXTrackCell *)[nib objectAtIndex:0];
        }
        if (cell)
        {
            cell.titleLabel.text = item[@"title"];
            cell.distanceLabel.text = item[@"distance"];
            cell.timeLabel.text = item[@"time"];
            cell.wptLabel.text = item[@"wpt"];
            cell.separatorView.hidden = indexPath.row == _data[indexPath.section].count - 1;
        }
        return cell;
    }
    return nil;
}

- (NSInteger) tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _data[section].count;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.count;
}

- (NSIndexPath *) tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    return cell.selectionStyle == UITableViewCellSelectionStyleNone ? nil : indexPath;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    
    OAGPX* track = item[@"track"];
    if (_screenType == EOAOpenExistingTrack)
    {
        [self.delegate closeBottomSheet];
        [self dismissViewControllerAnimated:YES completion:nil];
        [[OARootViewController instance].mapPanel openTargetViewWithGPX:track pushed:YES];
    }
    else
    {
        OAGPXTrackCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        cell.checkmarkImageView.hidden = NO;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
        
        //TODO: - uncomment when OASaveTrackBottomSheetViewController is in the current branch
//        OASaveTrackBottomSheetViewController *bottomSheet = [[OASaveTrackBottomSheetViewController alloc] initWithNewTrack:track];
//        [bottomSheet presentInViewController:OARootViewController.instance.mapPanel.mapViewController];
    }
    return;
}

- (void) segmentChanged:(id)sender
{
    UISegmentedControl *segment = (UISegmentedControl*)sender;
    if (segment)
    {
        if (segment.selectedSegmentIndex == 0)
            _sortingMode = EOAModifiedDate;
        else if (segment.selectedSegmentIndex == 1)
            _sortingMode = EOANameAscending;
        else if (segment.selectedSegmentIndex == 2)
            _sortingMode = EOANameDescending;
        [self generateData];
        
        NSMutableArray *pathsToReload = [NSMutableArray arrayWithArray:self.tableView.indexPathsForVisibleRows];
        [pathsToReload removeObjectAtIndex:0];
        [self.tableView reloadRowsAtIndexPaths:pathsToReload withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

@end