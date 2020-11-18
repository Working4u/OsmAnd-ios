//
//  OAPointOptionsBottomSheetViewController.h
//  OsmAnd
//
//  Created by Paul on 31.10.2020.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import "OABaseBottomSheetViewController.h"
#import "OAClearPointsCommand.h"
#import "OAInfoBottomView.h"

@class OAGpxTrkPt;

@protocol OAPointOptionsBottmSheetDelegate <NSObject>

- (void) onMovePoint:(NSInteger)point;
- (void) onClearPoints:(EOAClearPointsMode)mode;
- (void) onAddPoints:(EOAAddPointMode)type;
- (void) onDeletePoint;

@end

@interface OAPointOptionsBottomSheetViewController : OABaseBottomSheetViewController

@property (nonatomic, weak) id<OAPointOptionsBottmSheetDelegate> delegate;

- (instancetype) initWithPoint:(OAGpxTrkPt *)point index:(NSInteger)pointIndex;

@end