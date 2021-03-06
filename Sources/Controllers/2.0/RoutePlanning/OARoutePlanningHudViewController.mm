//
//  OARoutePlanningHudViewController.m
//  OsmAnd
//
//  Created by Paul on 10/16/20.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import "OARoutePlanningHudViewController.h"
#import "OAAppSettings.h"
#import "OARootViewController.h"
#import "OAMapPanelViewController.h"
#import "OAMapViewController.h"
#import "OAMapActions.h"
#import "OARoutingHelper.h"
#import "OAMapRendererView.h"
#import "OAColors.h"
#import "OANativeUtilities.h"
#import "OAMapViewController.h"
#import "OAMapRendererView.h"
#import "OAMapLayers.h"
#import "OAMeasurementToolLayer.h"
#import "OAMeasurementEditingContext.h"
#import "Localization.h"
#import "OAMeasurementCommandManager.h"
#import "OAAddPointCommand.h"
#import "OAMenuSimpleCellNoIcon.h"
#import "OAGPXDocumentPrimitives.h"
#import "OALocationServices.h"
#import "OAGpxData.h"
#import "OAGPXDocument.h"
#import "OAGPXMutableDocument.h"
#import "OASelectedGPXHelper.h"
#import "OAGPXTrackAnalysis.h"
#import "OAGPXDatabase.h"
#import "OAReorderPointCommand.h"
#import "OARemovePointCommand.h"
#import "OAPointOptionsBottomSheetViewController.h"
#import "OAInfoBottomView.h"
#import "OAMovePointCommand.h"
#import "OAClearPointsCommand.h"
#import "OAReversePointsCommand.h"
#import "OASegmentOptionsBottomSheetViewController.h"
#import "OAPlanningOptionsBottomSheetViewController.h"
#import "OAChangeRouteModeCommand.h"
#import "OATargetPointsHelper.h"
#import "OASaveGpxRouteAsyncTask.h"

#define VIEWPORT_SHIFTED_SCALE 1.5f
#define VIEWPORT_NON_SHIFTED_SCALE 1.0f

#define kDefaultMapRulerMarginBottom -17.0
#define kDefaultMapRulerMarginLeft 120.0

#define PLAN_ROUTE_MODE 0x1
#define DIRECTION_MODE 0x2
#define FOLLOW_TRACK_MODE 0x4
#define UNDO_MODE 0x8

typedef NS_ENUM(NSInteger, EOAFinalSaveAction) {
    SHOW_SNACK_BAR_AND_CLOSE = 0,
    SHOW_TOAST,
    SHOW_IS_SAVED_FRAGMENT
};

typedef NS_ENUM(NSInteger, EOASaveType) {
    ROUTE_POINT = 0,
    LINE
};

typedef NS_ENUM(NSInteger, EOAHudMode) {
    EOAHudModeRoutePlanning = 0,
    EOAHudModeMovePoint,
    EOAHudModeAddPoints
};

@interface OARoutePlanningHudViewController () <UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate,
    OAMeasurementLayerDelegate, OAPointOptionsBottmSheetDelegate, OAInfoBottomViewDelegate, OASegmentOptionsDelegate, OASnapToRoadProgressDelegate, OAPlanningOptionsDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *centerImageView;
@property (weak, nonatomic) IBOutlet UIView *closeButtonContainerView;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet UIView *doneButtonContainerView;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;
@property (weak, nonatomic) IBOutlet UILabel *titleView;
@property (weak, nonatomic) IBOutlet UIButton *optionsButton;
@property (weak, nonatomic) IBOutlet UIButton *undoButton;
@property (weak, nonatomic) IBOutlet UIButton *redoButton;
@property (weak, nonatomic) IBOutlet UIButton *addPointButton;
@property (weak, nonatomic) IBOutlet UIButton *expandButton;
@property (weak, nonatomic) IBOutlet UIImageView *leftImageVIew;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UIView *actionButtonsContainer;
@property (weak, nonatomic) IBOutlet UIButton *modeButton;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@end

@implementation OARoutePlanningHudViewController
{
    OAAppSettings *_settings;
    OsmAndAppInstance _app;
    
    OAMapPanelViewController *_mapPanel;
    OAMeasurementToolLayer *_layer;
    
    OAMeasurementEditingContext *_editingContext;
    
    CGFloat _cachedYViewPort;
    
    EOAHudMode _hudMode;
    
    OAInfoBottomView *_infoView;
    
    int _modes;
}

- (instancetype) init
{
    self = [super initWithNibName:@"OARoutePlanningHudViewController"
                           bundle:nil];
    if (self)
    {
        _app = OsmAndApp.instance;
        _settings = [OAAppSettings sharedManager];
        _mapPanel = OARootViewController.instance.mapPanel;
        _layer = _mapPanel.mapViewController.mapLayers.routePlanningLayer;
        // TODO: port later public void openPlanRoute()
        _editingContext = [[OAMeasurementEditingContext alloc] init];
        _editingContext.progressDelegate = self;
        
        _layer.editingCtx = _editingContext;
        
        _modes = 0x0;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _hudMode = EOAHudModeRoutePlanning;
    
    [_optionsButton setTitle:OALocalizedString(@"shared_string_options") forState:UIControlStateNormal];
    [_addPointButton setTitle:OALocalizedString(@"add_point") forState:UIControlStateNormal];
    _expandButton.imageView.tintColor = UIColorFromRGB(color_icon_inactive);
    [_expandButton setImage:[[UIImage imageNamed:@"ic_custom_arrow_up"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    
    [_undoButton setImage:[[UIImage imageNamed:@"ic_custom_undo"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [_redoButton setImage:[[UIImage imageNamed:@"ic_custom_redo"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    
    _undoButton.imageView.tintColor = UIColorFromRGB(color_primary_purple);
    _redoButton.imageView.tintColor = UIColorFromRGB(color_primary_purple);
    
    [self setupModeButton];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView setEditing:YES];
    [self updateDistancePointsText];
    [self show:YES state:EOADraggableMenuStateInitial onComplete:nil];
//    BOOL isNight = [OAAppSettings sharedManager].nightMode;
    [_mapPanel setTopControlsVisible:NO customStatusBarStyle:UIStatusBarStyleLightContent];
    [_mapPanel targetSetBottomControlsVisible:YES menuHeight:self.getViewHeight animated:YES];
    _centerImageView.image = [UIImage imageNamed:@"ic_ruler_center.png"];
    [self changeCenterOffset:[self getViewHeight]];
    
    _closeButtonContainerView.layer.cornerRadius = 12.;
    _doneButtonContainerView.layer.cornerRadius = 12.;
    
    [_closeButton setImage:[[UIImage imageNamed:@"ic_navbar_close"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    _closeButton.imageView.tintColor = UIColor.whiteColor;
    
    [_doneButton setTitle:OALocalizedString(@"shared_string_done") forState:UIControlStateNormal];
    _titleView.text = OALocalizedString(@"plan_route");
    
    _layer.delegate = self;
    
    [self adjustMapViewPort];
    [self changeMapRulerPosition];
    [self adjustActionButtonsPosition:self.getViewHeight];
    
    self.tableView.userInteractionEnabled = YES;
    [self.view bringSubviewToFront:self.tableView];
}

- (BOOL)supportsFullScreen
{
    return NO;
}

- (BOOL) showStatusBarWhenFullScreen
{
    return NO;
}

- (CGFloat)initialMenuHeight
{
    return _hudMode == EOAHudModeRoutePlanning ? 62. + self.toolBarView.frame.size.height : _infoView.getViewHeight;
}

- (CGFloat)expandedMenuHeight
{
    return DeviceScreenHeight / 2;
}

- (BOOL)useGestureRecognizer
{
    return NO;
}

- (CGFloat) additionalLandscapeOffset
{
    return 100.;
}

- (void) adjustActionButtonsPosition:(CGFloat)height
{
    CGRect buttonsFrame = _actionButtonsContainer.frame;
    if (OAUtilities.isLandscapeIpadAware)
        buttonsFrame.origin = CGPointMake(self.scrollableView.frame.size.width, DeviceScreenHeight - buttonsFrame.size.height - 15. - OAUtilities.getBottomMargin);
    else
        buttonsFrame.origin = CGPointMake(0., DeviceScreenHeight - height - buttonsFrame.size.height - 15.);
    _actionButtonsContainer.frame = buttonsFrame;
}

- (void) changeMapRulerPosition
{
    CGFloat bottomMargin = OAUtilities.isLandscapeIpadAware ? kDefaultMapRulerMarginBottom : (-self.getViewHeight + OAUtilities.getBottomMargin - 25.);
    CGFloat leftMargin = OAUtilities.isLandscapeIpadAware ? self.scrollableView.frame.size.width - OAUtilities.getLeftMargin + 16.0 + self.actionButtonsContainer.frame.size.width : kDefaultMapRulerMarginLeft;
    [_mapPanel targetSetMapRulerPosition:bottomMargin left:leftMargin];
}

- (void) changeCenterOffset:(CGFloat)contentHeight
{
    if (OAUtilities.isLandscapeIpadAware)
    {
        _centerImageView.center = CGPointMake(DeviceScreenWidth * 0.75,
                                        self.view.frame.size.height * 0.5);
    }
    else
    {
        _centerImageView.center = CGPointMake(self.view.frame.size.width * 0.5,
                                        self.view.frame.size.height * 0.5 - contentHeight / 2);
    }
}

- (void)adjustMapViewPort
{
    OAMapRendererView *mapView = [OARootViewController instance].mapPanel.mapViewController.mapView;
    if ([OAUtilities isLandscapeIpadAware])
    {
        mapView.viewportXScale = VIEWPORT_SHIFTED_SCALE;
        mapView.viewportYScale = VIEWPORT_NON_SHIFTED_SCALE;
    }
    else
    {
        mapView.viewportXScale = VIEWPORT_NON_SHIFTED_SCALE;
        mapView.viewportYScale = self.getViewHeight / DeviceScreenHeight;
    }
}

- (void) restoreMapViewPort
{
    OAMapRendererView *mapView = [OARootViewController instance].mapPanel.mapViewController.mapView;
    if (mapView.viewportXScale != VIEWPORT_NON_SHIFTED_SCALE)
        mapView.viewportXScale = VIEWPORT_NON_SHIFTED_SCALE;
    if (mapView.viewportYScale != _cachedYViewPort)
        mapView.viewportYScale = _cachedYViewPort;
}

- (void) updateDistancePointsText
{
    if (_layer != nil)
    {
        NSString *distanceStr = [_app getFormattedDistance:_editingContext.getRouteDistance];
        self.titleLabel.text = [NSString stringWithFormat:@"%@, %@ %ld", distanceStr, OALocalizedString(@"points_count"), _editingContext.getPointsCount];
    }
}

- (void)setupModeButton
{
    UIImage *img;
    UIColor *tint;
    if (_editingContext.appMode != OAApplicationMode.DEFAULT)
    {
        img = [_editingContext.appMode.getIcon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        tint = UIColorFromRGB(_editingContext.appMode.getIconColor);
    }
    else
    {
        img = [[UIImage imageNamed:@"ic_custom_straight_line"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        tint = UIColorFromRGB(color_chart_orange);
    }
    [_modeButton setImage:img forState:UIControlStateNormal];
    [_modeButton setTintColor:tint];
}

- (void) cancelModes
{
    _editingContext.selectedPointPosition = -1;
    _editingContext.originalPointToMove = nil;
    _editingContext.addPointMode = EOAAddPointModeUndefined;
    [_editingContext splitSegments:_editingContext.getBeforePoints.count + _editingContext.getAfterPoints.count];
    if (_hudMode == EOAHudModeMovePoint)
        [_layer exitMovingMode];
    [_layer updateLayer];
    _hudMode = EOAHudModeRoutePlanning;
}

- (IBAction)closePressed:(id)sender
{
    [self hide:YES duration:.2 onComplete:^{
        [_mapPanel targetSetMapRulerPosition:kDefaultMapRulerMarginBottom left:kDefaultMapRulerMarginLeft];
        [self restoreMapViewPort];
        [OARootViewController.instance.mapPanel hideScrollableHudViewController];
        _layer.editingCtx = nil;
        [_layer resetLayer];
    }];
}

- (IBAction)donePressed:(id)sender
{
//    if ([self isFollowTrackMode])
//        [self startTrackNavigation];
//    else
    [self saveChanges:SHOW_SNACK_BAR_AND_CLOSE showDialog:NO];
    [self hide:YES duration:.2 onComplete:^{
        [_mapPanel targetSetMapRulerPosition:kDefaultMapRulerMarginBottom left:kDefaultMapRulerMarginLeft];
        [self restoreMapViewPort];
        [OARootViewController.instance.mapPanel hideScrollableHudViewController];
        _layer.editingCtx = nil;
        [_layer resetLayer];
    }];
}

- (IBAction)onExpandButtonPressed:(id)sender
{
    if ([sender isKindOfClass:UIButton.class])
    {
        UIButton *button = (UIButton *) sender;
        if (self.currentState == EOADraggableMenuStateInitial)
        {
            [self goExpanded];
            [button setImage:[[UIImage imageNamed:@"ic_custom_arrow_down"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        }
        else
        {
            [self goMinimized];
            [button setImage:[[UIImage imageNamed:@"ic_custom_arrow_up"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        }
    }
}
- (IBAction)onOptionsButtonPressed:(id)sender
{
    BOOL trackSnappedToRoad = !_editingContext.isApproximationNeeded;
    BOOL addNewSegmentAllowed = _editingContext.isAddNewSegmentAllowed;
    OAPlanningOptionsBottomSheetViewController *bottomSheet = [[OAPlanningOptionsBottomSheetViewController alloc] initWithRouteAppModeKey:_editingContext.appMode.stringKey trackSnappedToRoad:trackSnappedToRoad addNewSegmentAllowed:addNewSegmentAllowed];
    bottomSheet.delegate = self;
    [bottomSheet presentInViewController:self];
}

- (IBAction)onUndoButtonPressed:(id)sender
{
    [_editingContext.commandManager undo];
    [self onPointsListChanged];
    [self setupModeButton];
}

- (IBAction)onRedoButtonPressed:(id)sender
{
    [_editingContext.commandManager redo];
    [self onPointsListChanged];
    [self setupModeButton];
}

- (IBAction)onAddPointPressed:(id)sender
{
    [self addCenterPoint];
}

- (void)showSegmentRouteOptions
{
    OASegmentOptionsBottomSheetViewController *bottomSheet = [[OASegmentOptionsBottomSheetViewController alloc] initWithType:EOADialogTypeWholeRouteCalculation dialogMode:EOARouteBetweenPointsDialogModeAll appMode:_editingContext.appMode];
    bottomSheet.delegate = self;
    [bottomSheet presentInViewController:self];
}

- (IBAction)modeButtonPressed:(id)sender
{
    [self showSegmentRouteOptions];
}

- (void) setMode:(int)mode on:(BOOL)on
{
    int modes = _modes;
    if (on)
        modes |= mode;
    else
        modes &= ~mode;
    _modes = modes;
}

- (BOOL)isPlanRouteMode
{
    return (_modes & PLAN_ROUTE_MODE) == PLAN_ROUTE_MODE;
}

- (BOOL) isDirectionMode
{
    return (_modes & DIRECTION_MODE) == DIRECTION_MODE;
}

- (BOOL) isFollowTrackMode
{
    return (_modes & FOLLOW_TRACK_MODE) == FOLLOW_TRACK_MODE;
}

- (BOOL) isUndoMode
{
    return (_modes & UNDO_MODE) == UNDO_MODE;
}

- (NSString *) getSuggestedFileName
{
    OAGpxData *gpxData = _editingContext.gpxData;
    NSString *displayedName = nil;
//    if (gpxData != nil) {
//        OAGPXDocument *gpxFile = gpxData.gpxFile;
//        if (!Algorithms.isEmpty(gpxFile.path)) {
//            displayedName = Algorithms.getFileNameWithoutExtension(new File(gpxFile.path).getName());
//        } else if (!Algorithms.isEmpty(gpxFile.tracks)) {
//            displayedName = gpxFile.tracks.get(0).name;
//        }
//    }
    if (gpxData == nil || displayedName == nil)
    {
        NSDateFormatter *objDateFormatter = [[NSDateFormatter alloc] init];
        [objDateFormatter setDateFormat:@"EEE dd MMM yyyy"];
        NSString *suggestedName = [objDateFormatter stringFromDate:[NSDate date]];
        displayedName = [self createUniqueFileName:suggestedName];
    }
//    else
//    {
//        displayedName = Algorithms.getFileNameWithoutExtension(new File(gpxData.getGpxFile().path).getName());
//    }
    return displayedName;
}

- (NSString *) createUniqueFileName:(NSString *)fileName
{
    NSString *path = [[_app.gpxPath stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:@"gpx"];
    NSFileManager *fileMan = [NSFileManager defaultManager];
    if ([fileMan fileExistsAtPath:path])
    {
        NSString *ext = [fileName pathExtension];
        NSString *newName;
        for (int i = 2; i < 100000; i++) {
            newName = [[NSString stringWithFormat:@"%@_(%d)", [fileName stringByDeletingPathExtension], i] stringByAppendingPathExtension:ext];
            path = [_app.gpxPath stringByAppendingPathComponent:newName];
            if (![fileMan fileExistsAtPath:path])
                break;
        }
        return [newName stringByDeletingPathExtension];
    }
    return fileName;
}

- (void) saveChanges:(EOAFinalSaveAction)finalSaveAction showDialog:(BOOL)showDialog
{
    
    if (_editingContext.getPointsCount > 0)
    {
//        OAGpxData *gpxData = _editingContext.gpxData;
        if ([_editingContext isNewData] /*|| (isInEditMode() && gpxData.getActionType() == ActionType.EDIT_SEGMENT)*/)
        {
//            if (showDialog) {
//                openSaveAsNewTrackMenu(mapActivity);
//            } else {
            [self saveNewGpx:nil fileName:[self getSuggestedFileName] showOnMap:YES simplifiedTrack:NO finalSaveAction:finalSaveAction];
        }
//        } else {
//            addToGpx(mapActivity, finalSaveAction);
//        }
    }
//    else
//        Toast.makeText(mapActivity, getString(R.string.none_point_error), Toast.LENGTH_SHORT).show();
}

- (void) saveNewGpx:(NSString *)folderName fileName:(NSString *)fileName showOnMap:(BOOL)showOnMap
    simplifiedTrack:(BOOL)simplifiedTrack finalSaveAction:(EOAFinalSaveAction)finalSaveAction
{
    NSString *gpxPath = _app.gpxPath;
    if (folderName != nil && ![gpxPath.lastPathComponent isEqualToString:folderName])
        gpxPath = [gpxPath stringByAppendingPathComponent:folderName];
    fileName = [fileName stringByAppendingPathExtension:@"gpx"];
    [self saveNewGpx:gpxPath fileName:fileName showOnMap:showOnMap simplified:simplifiedTrack finalSaveAction:finalSaveAction];
}

- (void) saveNewGpx:(NSString *)dir fileName:(NSString *)fileName showOnMap:(BOOL)showOnMap simplified:(BOOL)simplified finalSaveAction:(EOAFinalSaveAction)finalSaveAction
{
    [self saveGpx:[dir stringByAppendingPathComponent:fileName] gpxFile:nil simplified:simplified addToTrack:NO finalSaveAction:finalSaveAction showOnMap:showOnMap];
}

- (void) saveGpx:(NSString *)outFile gpxFile:(OAGPXDocument *)gpxFile simplified:(BOOL)simplified addToTrack:(BOOL)addToTrack finalSaveAction:(EOAFinalSaveAction)finalSaveAction showOnMap:(BOOL)showOnMap
{
    OASaveGpxRouteAsyncTask *task = [[OASaveGpxRouteAsyncTask alloc] initWithHudController:self outFile:outFile gpxFile:gpxFile simplified:simplified addToTrack:addToTrack showOnMap:showOnMap];
    [task execute:^(OAGPXDocument * gpx, NSString * outFile) {
        [self onGpxSaved:gpx outFile:outFile finalSaveAction:finalSaveAction showOnMap:showOnMap];
    }];
}

- (void) onGpxSaved:(OAGPXDocument *)savedGpxFile outFile:(NSString *)outFile finalSaveAction:(EOAFinalSaveAction)finalSaveAction showOnMap:(BOOL)showOnMap
{
    OAGPXTrackAnalysis *analysis = [savedGpxFile getAnalysis:0];
    [[OAGPXDatabase sharedDb] addGpxItem:[outFile lastPathComponent] title:savedGpxFile.metadata.name desc:savedGpxFile.metadata.desc bounds:savedGpxFile.bounds analysis:analysis];
    [[OAGPXDatabase sharedDb] save];
    if (showOnMap)
        [_settings showGpx:@[savedGpxFile.fileName]];
}

#pragma mark - OADraggableViewActions

- (void)onViewHeightChanged:(CGFloat)height
{
    [self changeCenterOffset:height];
    [_mapPanel targetSetBottomControlsVisible:YES menuHeight:OAUtilities.isLandscapeIpadAware ? 0. : (height - 30.) animated:YES];
    [self adjustActionButtonsPosition:height];
    [self changeMapRulerPosition];
    [self adjustMapViewPort];
}

- (void) onPointsListChanged
{
    [self.tableView reloadData];
    [self updateDistancePointsText];
}

- (BOOL) addCenterPoint
{
    BOOL added = NO;
    if (_layer != nil) {
        added = [_editingContext.commandManager execute:[[OAAddPointCommand alloc] initWithLayer:_layer center:YES]];
        [self onPointsListChanged];
    }
    return added;
}

#pragma mark - UITableViewDataSource

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.01;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _editingContext.getPointsCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* const identifierCell = @"OAMenuSimpleCellNoIcon";
    OAMenuSimpleCellNoIcon* cell = [tableView dequeueReusableCellWithIdentifier:identifierCell];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:identifierCell owner:self options:nil];
        cell = (OAMenuSimpleCellNoIcon *)[nib objectAtIndex:0];
    }
    cell.textView.text = [NSString stringWithFormat:OALocalizedString(@"point_num"), indexPath.row + 1];
    
    OAGpxTrkPt *point1 = _editingContext.getPoints[indexPath.row];
    CLLocation *location1 = [[CLLocation alloc] initWithLatitude:point1.getLatitude longitude:point1.getLongitude];
    if (indexPath.row == 0)
    {
        CLLocation *currentLocation = _app.locationServices.lastKnownLocation;
        if (currentLocation)
        {
            double azimuth = [location1 bearingTo:currentLocation];
            cell.descriptionView.text = [NSString stringWithFormat:@"%@ • %@ • %@", OALocalizedString(@"gpx_start"), [_app getFormattedDistance:[location1 distanceFromLocation:currentLocation]], [OsmAndApp.instance getFormattedAzimuth:azimuth]];
        }
        else
        {
            cell.descriptionView.text = OALocalizedString(@"gpx_start");
        }
    }
    else
    {
        OAGpxTrkPt *point2 = indexPath.row == 0 && _editingContext.getPointsCount > 1 ? _editingContext.getPoints[indexPath.row + 1] : _editingContext.getPoints[indexPath.row - 1];
        CLLocation *location2 = [[CLLocation alloc] initWithLatitude:point2.getLatitude longitude:point2.getLongitude];
        double azimuth = [location1 bearingTo:location2];
        cell.descriptionView.text = [NSString stringWithFormat:@"%@ • %@", [_app getFormattedDistance:[location1 distanceFromLocation:location2]], [OsmAndApp.instance getFormattedAzimuth:azimuth]];
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        [_editingContext.commandManager execute:[[OARemovePointCommand alloc] initWithLayer:_layer position:indexPath.row]];
        [tableView beginUpdates];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
        [tableView endUpdates];
        [self updateDistancePointsText];
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    return proposedDestinationIndexPath;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    // Deferr the data update until the animation is complete
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        [tableView reloadData];
    }];
    [_editingContext.commandManager execute:[[OAReorderPointCommand alloc] initWithLayer:_layer from:sourceIndexPath.row to:destinationIndexPath.row]];
    [self updateDistancePointsText];
    [CATransaction commit];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    _editingContext.selectedPointPosition = indexPath.row;
    OAPointOptionsBottomSheetViewController *bottomSheet = [[OAPointOptionsBottomSheetViewController alloc] initWithPoint:_editingContext.getPoints[indexPath.row] index:indexPath.row editingContext:_editingContext];
    bottomSheet.delegate = self;
    [bottomSheet presentInViewController:self];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - OAMeasurementLayerDelegate

- (void)onMeasue:(double)distance bearing:(double)bearing
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.descriptionLabel.text = [NSString stringWithFormat:@"%@ • %@", [_app getFormattedDistance:distance], [OsmAndApp.instance getFormattedAzimuth:bearing]];
    });
}

#pragma mark - OAPointOptionsBottmSheetDelegate

- (void)showMovingInfoView
{
    _infoView = [[OAInfoBottomView alloc] initWithType:EOABottomInfoViewTypeMove];
    _infoView.frame = self.scrollableView.bounds;
    _infoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _infoView.leftIconView.image = [UIImage imageNamed:@"ic_custom_change_object_position"];
    _infoView.titleView.text = OALocalizedString(@"move_point");
    _infoView.headerViewText = OALocalizedString(@"move_point_descr");
    [_infoView.leftButton setTitle:OALocalizedString(@"shared_string_cancel") forState:UIControlStateNormal];
    [_infoView.rightButton setTitle:OALocalizedString(@"shared_string_apply") forState:UIControlStateNormal];
    _infoView.layer.cornerRadius = 9.;
    _infoView.clipsToBounds = NO;
    _infoView.layer.masksToBounds = YES;
    
    _infoView.delegate = self;
    [self.scrollableView addSubview:_infoView];
    _hudMode = EOAHudModeMovePoint;
    [self goMinimized];
}

- (void) onMovePoint:(NSInteger)pointPosition
{
    [self showMovingInfoView];
    [self enterMovingMode:pointPosition];
}

- (void) enterMovingMode:(NSInteger)pointPosition
{
    OAGpxTrkPt *pt = _editingContext.getPoints[pointPosition];
    _editingContext.originalPointToMove = pt;
    [_layer enterMovingPointMode];
}

- (void) onClearPoints:(EOAClearPointsMode)mode
{
    [_editingContext.commandManager execute:[[OAClearPointsCommand alloc] initWithMeasurementLayer:_layer mode:mode]];
    [self onPointsListChanged];
    [self goMinimized];
    _editingContext.selectedPointPosition = -1;
    [_editingContext splitSegments:_editingContext.getBeforePoints.count + _editingContext.getAfterPoints.count];
//    updateUndoRedoButton(false, redoBtn);
//    updateUndoRedoButton(true, undoBtn);
    [self updateDistancePointsText];
}

- (void)onAddPoints:(EOAAddPointMode)type
{
    BOOL addBefore = type == EOAAddPointModeBefore;
    EOABottomInfoViewType viewType = type == EOAAddPointModeBefore ? EOABottomInfoViewTypeAddBefore : EOABottomInfoViewTypeAddAfter;
    _infoView = [[OAInfoBottomView alloc] initWithType:viewType];
    _infoView.frame = self.scrollableView.bounds;
    _infoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _infoView.leftIconView.image = addBefore ? [UIImage imageNamed:@"ic_custom_add_point_before"] : [UIImage imageNamed:@"ic_custom_add_point_after"];
    _infoView.titleView.text = addBefore ? OALocalizedString(@"add_before") : OALocalizedString(@"add_after");
    _infoView.headerViewText = OALocalizedString(@"move_point_descr");
    [_infoView.leftButton setTitle:OALocalizedString(@"shared_string_cancel") forState:UIControlStateNormal];
    [_infoView.rightButton setTitle:OALocalizedString(@"shared_string_apply") forState:UIControlStateNormal];
    _infoView.layer.cornerRadius = 9.;
    _infoView.clipsToBounds = NO;
    _infoView.layer.masksToBounds = YES;
    
    //                measurementLayer.moveMapToPoint(editingCtx.getSelectedPointPosition());
    _editingContext.addPointMode = type;
    [_editingContext splitSegments:_editingContext.selectedPointPosition + (type == EOAAddPointModeAfter ? 1 : 0)];
    
    [_layer updateLayer];
    
    _infoView.delegate = self;
    [self.scrollableView addSubview:_infoView];
    _hudMode = EOAHudModeAddPoints;
    [self goMinimized];
}

- (void) onDeletePoint
{
    [_editingContext.commandManager execute:[[OARemovePointCommand alloc] initWithLayer:_layer position:_editingContext.selectedPointPosition]];
    [self.tableView beginUpdates];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
    [self updateDistancePointsText];
    _editingContext.selectedPointPosition = -1;
}

#pragma mark - OAInfoBottomViewDelegate

- (void)onLeftButtonPressed
{
    [self onCloseButtonPressed];
}

- (void)onRightButtonPressed
{
    OAGpxTrkPt *newPoint = [_layer getMovedPointToApply];
    if (_hudMode == EOAHudModeMovePoint)
    {
        [_editingContext.commandManager execute:[[OAMovePointCommand alloc] initWithLayer:_layer
                                                                                 oldPoint:_editingContext.originalPointToMove
                                                                                 newPoint:newPoint
                                                                                 position:_editingContext.selectedPointPosition]];
    }
    else if (_hudMode == EOAHudModeAddPoints)
    {
        [self onAddOneMorePointPressed:_editingContext.addPointMode];
    }
    
    [self onCloseButtonPressed];
}

- (void)onCloseButtonPressed
{
    _editingContext.selectedPointPosition = -1;
    _editingContext.originalPointToMove = nil;
    _editingContext.addPointMode = EOAAddPointModeUndefined;
    [_editingContext splitSegments:_editingContext.getBeforePoints.count + _editingContext.getAfterPoints.count];
    if (_hudMode == EOAHudModeMovePoint)
        [_layer exitMovingMode];
    [_layer updateLayer];
    _hudMode = EOAHudModeRoutePlanning;
    
    [UIView animateWithDuration:.2 animations:^{
        _infoView.alpha = 0.;
        [self goMinimized];
        [self onPointsListChanged];
    } completion:^(BOOL finished) {
        [_infoView removeFromSuperview];
        _infoView = nil;
    }];
}

- (void) onAddOneMorePointPressed:(EOAAddPointMode)mode
{
    NSInteger selectedPoint = _editingContext.selectedPointPosition;
    NSInteger pointsCount = _editingContext.getPointsCount;
    if ([self addCenterPoint])
    {
        if (selectedPoint == pointsCount)
            [_editingContext splitSegments:_editingContext.getPointsCount - 1];
        else
            _editingContext.selectedPointPosition = selectedPoint + 1;
        
        [self onPointsListChanged];
    }
}

- (void)onChangeRouteTypeBefore
{
    OASegmentOptionsBottomSheetViewController *bottomSheet = [[OASegmentOptionsBottomSheetViewController alloc] initWithType:EOADialogTypePrevRouteCalculation dialogMode:EOARouteBetweenPointsDialogModeSingle appMode:_editingContext.getBeforeSelectedPointAppMode];
    bottomSheet.delegate = self;
    [bottomSheet presentInViewController:self];
}

- (void)onChangeRouteTypeAfter
{
    OASegmentOptionsBottomSheetViewController *bottomSheet = [[OASegmentOptionsBottomSheetViewController alloc] initWithType:EOADialogTypeNextRouteCalculation dialogMode:EOARouteBetweenPointsDialogModeSingle appMode:_editingContext.getSelectedPointAppMode];
    bottomSheet.delegate = self;
    [bottomSheet presentInViewController:self];
}

#pragma mark - OASegmentOptionsDelegate

- (void)onApplicationModeChanged:(OAApplicationMode *)mode dialogType:(EOARouteBetweenPointsDialogType)dialogType dialogMode:(EOARouteBetweenPointsDialogMode)dialogMode
{
    if (_layer != nil) {
        EOAChangeRouteType changeRouteType = EOAChangeRouteNextSegment;
        switch (dialogType) {
            case EOADialogTypeWholeRouteCalculation:
            {
                changeRouteType = dialogMode == EOARouteBetweenPointsDialogModeSingle
                ? EOAChangeRouteLastSegment : EOAChangeRouteWhole;
                break;
            }
            case EOADialogTypeNextRouteCalculation:
            {
                changeRouteType = dialogMode == EOARouteBetweenPointsDialogModeSingle
                ? EOAChangeRouteNextSegment : EOAChangeRouteAllNextSegments;
                break;
            }
            case EOADialogTypePrevRouteCalculation:
            {
                changeRouteType = dialogMode == EOARouteBetweenPointsDialogModeSingle
                ? EOAChangeRoutePrevSegment : EOAChangeRouteAllPrevSegments;
                break;
            }
        }
        [_editingContext.commandManager execute:[[OAChangeRouteModeCommand alloc] initWithLayer:_layer appMode:mode changeRouteType:changeRouteType pointIndex:_editingContext.selectedPointPosition]];
//        updateUndoRedoButton(false, redoBtn);
//        updateUndoRedoButton(true, undoBtn);
//        disable(upDownBtn);
//        updateSnapToRoadControls();
        [self updateDistancePointsText];
        [self setupModeButton];
    }
}

#pragma mark - OASnapToRoadProgressDelegate

- (void)hideProgressBar
{
    _progressView.hidden = YES;
}

- (void)refresh
{
    [_layer updateLayer];
    [self updateDistancePointsText];
}

- (void)showProgressBar
{
    _progressView.hidden = NO;
}

- (void)updateProgress:(int)progress
{
    [_progressView setProgress:progress / 100.];
}

#pragma mark - OAPlanningOptionsDelegate

- (void) snapToRoadOptionSelected
{
    [self showSegmentRouteOptions];
}

- (void) addNewSegmentSelected
{
//    [self onSplitPointsAfter];
}

- (void) saveChangesSelected
{
//    if (self.isFollowTrackMode)
//        [self startTrackNavigation];
//    else
        [self saveChanges:SHOW_TOAST showDialog:YES];
}

- (void) saveAsNewTrackSelected
{
//    [self openSaveAsNewTrackMenu];
}

- (void) addToTrackSelected
{
//    if (_editingContext.getPointsCount > 0)
//        [self showAddToTrackDialog];
//    else
//        NSLog(@"No points to add");
//        Toast.makeText(mapActivity, getString(R.string.none_point_error), Toast.LENGTH_SHORT).show();
}

- (void) directionsSelected
{
    OAMapPanelViewController *mapPanel = [OARootViewController instance].mapPanel;
    OATargetPointsHelper *targetPointsHelper = OATargetPointsHelper.sharedInstance;
    OAApplicationMode *appMode = _editingContext.appMode;
    if (appMode == OAApplicationMode.DEFAULT)
        appMode = nil;
    
    NSArray<OAGpxTrkPt *> *points = _editingContext.getPoints;
    if (points.count > 0)
    {
        if (points.count == 1)
        {
            [targetPointsHelper clearAllPoints:NO];
            [targetPointsHelper navigateToPoint:[[CLLocation alloc] initWithLatitude:points.firstObject.getLatitude longitude:points.firstObject.getLongitude] updateRoute:NO intermediate:-1];
            
            [self onCloseButtonPressed];
            [mapPanel.mapActions enterRoutePlanningModeGivenGpx:nil from:nil fromName:nil useIntermediatePointsByDefault:YES showDialog:YES];
        }
        else
        {
//            NSString *trackName = [self getSuggestedFileName];
//            if (_editingContext.hasRoute)
//            {
//                OAGPX *gpx = [_editingCtx exportGpx:trackName];
//                if (gpx != nil)
//                {
//                    [self onCloseButtonPressed];
//                    [self runNavigation:gpx appMode:appMode];
//                }
//                else
//                {
//                    NSLog(@"Trip planning error occured while saving gpx");
////                    Toast.makeText(mapActivity, getString(R.string.error_occurred_saving_gpx), Toast.LENGTH_SHORT).show();
//                }
//            }
//            else
//            {
//                if (_editingCtx.isApproximationNeeded)
//                {
//                    self setMode:(DIRECTION_MODE, true);
//                    self enterApproximationMode(mapActivity);
//                }
//                else
//                {
//                    OAGPX *gpx = [[OAGPX alloc] init];
//                    gpx.poi
//                    GPXFile gpx = new GPXFile(Version.getFullVersion(requireMyApplication()));
//                    gpx.addRoutePoints(points, true);
//                    dismiss(mapActivity);
//                    targetPointsHelper.clearAllPoints(false);
//                    mapActions.enterRoutePlanningModeGivenGpx(gpx, appMode, null, null, true, true, MenuState.HEADER_ONLY);
//                }
//            }
        }
    }
    else
    {
        // TODO: notify about the error
//        Toast.makeText(mapActivity, getString(R.string.none_point_error), Toast.LENGTH_SHORT).show();
    }
}

- (void) reverseRouteSelected
{
    NSArray<OAGpxTrkPt *> *points = _editingContext.getPoints;
    if (points.count > 1)
    {
        [_editingContext.commandManager execute:[[OAReversePointsCommand alloc] initWithLayer:_layer]];
        [self goMinimized];
//        updateUndoRedoButton(false, redoBtn);
//        updateUndoRedoButton(true, undoBtn);
        [self.tableView reloadData];
        [self updateDistancePointsText];
    }
    else
    {
        NSLog(@"Can't reverse one point");
    }
}

- (void) clearAllSelected
{
    [_editingContext.commandManager execute:[[OAClearPointsCommand alloc] initWithMeasurementLayer:_layer mode:EOAClearPointsModeAll]];
    [_editingContext cancelSnapToRoad];
    [self goMinimized];
//    updateUndoRedoButton(false, redoBtn);
    [self.tableView reloadData];
    [self updateDistancePointsText];
}

- (void) runNavigation:(OAGPX *)gpx appMode:(OAApplicationMode *)appMode
{
    OAMapPanelViewController *mapPanel = OARootViewController.instance.mapPanel;
    OARoutingHelper *routingHelper = OARoutingHelper.sharedInstance;
    if (routingHelper.isFollowingMode)
    {
        if ([self isFollowTrackMode])
        {
            [mapPanel.mapActions setGPXRouteParams:gpx];
            [OATargetPointsHelper.sharedInstance updateRouteAndRefresh:YES];
            [routingHelper recalculateRouteDueToSettingsChange];
        }
        else
        {
            
            [mapPanel.mapActions stopNavigationActionConfirm];
            // TODO
//            mapActivity.getMapActions().stopNavigationActionConfirm(null , new Runnable() {
//                @Override
//                public void run() {
//                    MapActivity mapActivity = getMapActivity();
//                    if (mapActivity != null) {
//                        mapActivity.getMapActions().enterRoutePlanningModeGivenGpx(gpx, appMode, null, null, true, true, MenuState.HEADER_ONLY);
//                    }
//                }
//            });
        }
    }
    else
    {
        [mapPanel.mapActions stopNavigationWithoutConfirm];
        [mapPanel.mapActions enterRoutePlanningModeGivenGpx:gpx from:nil fromName:nil useIntermediatePointsByDefault:YES showDialog:YES];
    }
}

@end
