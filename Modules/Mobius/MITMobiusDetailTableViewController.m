#import "MITMobiusDetailTableViewController.h"
#import "MITActionCell.h"
#import "UITableView+DynamicSizing.h"
#import "MITTitleDescriptionCell.h"
#import "MITMobiusSpecificationsHeader.h"
#import "MITMobiusDetailHeader.h"
#import "MITMobiusModel.h"
#import "MITMapModelController.h"
#import "MITMobiusSegmentedHeader.h"
#import "MITMobiusDailyHoursObject.h"
#import "MITMobiusTitleValueObject.h"

static NSString * const MITActionCellIdentifier = @"MITActionCellIdentifier";
static NSString * const MITTitleDescriptionCellIdentifier = @"MITTitleDescriptionCellIdentifier";
static NSString * const MITMobiusDetailCellIdentifier = @"MITMobiusDetailCellIdentifier";
static NSString * const MITMobiusSpecificationsHeaderIdentifier = @"MITMobiusSpecificationsHeaderIdentifier";
static NSString * const MITMobiusSegmentedHeaderIdentifier = @"MITMobiusSegmentedHeaderIdentifier";

typedef NS_ENUM(NSInteger, MITMobiusTableViewSection) {
    MITMobiusTableViewSectionSegmented,
};

typedef NS_ENUM(NSInteger, MITMobiusShopDetailsTableViewRows) {
    MITMobiusTableViewRowHoursLabel,
    MITMobiusTableViewRowHours,
    MITMobiusTableViewRowLocation,
    MITMobiusTableViewRowDetails
};

typedef NS_ENUM(NSInteger, MITMobiusSegmentedSections) {
    MITMobiusTableViewSectionShopDetails,
    MITMobiusTableViewSectionSpecs
};

@interface MITMobiusDetailTableViewController() <UITableViewDataSourceDynamicSizing, MITMobiusSegmentedHeaderDelegate>

@property(nonatomic,strong) NSMutableArray *titleValueObjects;
@property(nonatomic,readonly,strong) NSManagedObjectContext *managedObjectContext;
@property(nonatomic) NSInteger currentSegementedSection;
@property(nonatomic,strong) NSArray *hours;
@property(nonatomic,strong) NSArray *rowTypes;
@property(nonatomic) NSInteger startingHoursRow;

@end

@implementation MITMobiusDetailTableViewController
@synthesize managedObjectContext = _managedObjectContext;

- (instancetype)initWithResource:(MITMobiusResource *)resource
{
    self = [self initWithStyle:UITableViewStylePlain];
    if (self) {
        self.currentSegementedSection = 0;
        self.resource = resource;
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupTableView:self.tableView];
    [self refreshEventRows];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)combineDescriptionsForTitle
{
    self.titleValueObjects = [[NSMutableArray alloc] init];

    for (MITMobiusResourceAttributeValueSet *valueSet in self.resource.attributeValues) {
        NSMutableString *valueString = [[NSMutableString alloc] init];

        for (MITMobiusResourceAttributeValue *value in valueSet.values) {
            if (value.value.length > 0) {
                if (valueString.length > 0) {
                    [valueString appendString:@"\n"];
                }

                [valueString appendString:value.value];
            }
        }

        if (valueString.length > 0) {
            
            MITMobiusTitleValueObject *titleValueObject = [[MITMobiusTitleValueObject alloc] init];
            
            titleValueObject.title = valueSet.label;
            titleValueObject.value = valueString;
            
            [self.titleValueObjects addObject:titleValueObject];
        }
    }
}

- (void)refreshEventRows
{
    NSMutableArray *rowTypes = [NSMutableArray array];
    
    if (self.currentSegementedSection == MITMobiusTableViewSectionShopDetails) {
        if (self.hours.count > 0) {
            [rowTypes addObject:@(MITMobiusTableViewRowHoursLabel)];
        }
        
        self.startingHoursRow = rowTypes.count;
        [self.hours enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [rowTypes addObject:@(MITMobiusTableViewRowHours)];
        }];
        
        if (self.resource.room) {
            [rowTypes addObject:@(MITMobiusTableViewRowLocation)];
        }
    } else if (self.currentSegementedSection == MITMobiusTableViewSectionSpecs) {
        
        [self.titleValueObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [rowTypes addObject:@(MITMobiusTableViewRowDetails)];
        }];
        
    }
    self.rowTypes = rowTypes;
    [self.tableView reloadData];
}

- (void)setupTableView:(UITableView *)tableView;
{
    tableView.dataSource = self;
    tableView.delegate = self;
    
    [tableView registerNib:[MITActionCell actionCellNib] forDynamicCellReuseIdentifier:MITActionCellIdentifier];
    
    [tableView registerNib:[MITTitleDescriptionCell titleDescriptionCellNib] forDynamicCellReuseIdentifier:MITTitleDescriptionCellIdentifier];
    
    [tableView registerNib:[MITMobiusSpecificationsHeader titleHeaderNib] forHeaderFooterViewReuseIdentifier:MITMobiusSpecificationsHeaderIdentifier];

    [tableView registerNib:[MITMobiusSegmentedHeader segmentedHeaderNib] forHeaderFooterViewReuseIdentifier:MITMobiusSegmentedHeaderIdentifier];

    tableView.tableFooterView = [UIView new];
    
    tableView.separatorStyle = UITableViewCellSelectionStyleNone;
    
    MITMobiusDetailHeader *detailHeader = [[[NSBundle mainBundle]
                     loadNibNamed:@"MITMobiusDetailHeader"
                     owner:self options:nil]
                    firstObject];
    detailHeader.resource = self.resource;
    
    tableView.tableHeaderView = detailHeader;
    [detailHeader setNeedsLayout];
    [detailHeader layoutIfNeeded];
    CGFloat height = [detailHeader systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    
    //update the header's frame and set it again
    CGRect tableHeaderViewFrame = detailHeader.frame;
    tableHeaderViewFrame.size.height = height;
    detailHeader.frame = tableHeaderViewFrame;
    tableView.tableHeaderView = detailHeader;
}

- (NSArray *)hours
{
    if (!_hours) {
        NSArray * hours = [self.resource getArrayOfDailyHoursObjects];
        _hours = hours;
    }
    return _hours;
}

- (NSManagedObjectContext*)managedObjectContext
{
    if (!_managedObjectContext) {
        NSManagedObjectContext *managedObjectContext = [[MITCoreDataController defaultController] newManagedObjectContextWithConcurrencyType:NSMainQueueConcurrencyType trackChanges:NO];
        managedObjectContext.retainsRegisteredObjects = YES;
        _managedObjectContext = managedObjectContext;
    }

    return _managedObjectContext;
}

- (void)setResource:(MITMobiusResource *)resource
{
    if (![_resource.objectID isEqual:resource.objectID]) {
        if (resource) {
            _resource = (MITMobiusResource*)[self.managedObjectContext objectWithID:resource.objectID];
            [self combineDescriptionsForTitle];
        } else {
            _resource = nil;
            self.titleValueObjects = nil;
        }
        [self refreshEventRows];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.rowTypes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *identifier = [self reuseIdentifierForRowAtIndexPath:indexPath];
    NSAssert(identifier,@"[%@] missing cell reuse identifier in %@",self,NSStringFromSelector(_cmd));
   
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [self tableView:tableView configureCell:cell forRowAtIndexPath:indexPath];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *reuseIdentifier = [self reuseIdentifierForRowAtIndexPath:indexPath];
    CGFloat cellHeight = [tableView minimumHeightForCellWithReuseIdentifier:reuseIdentifier atIndexPath:indexPath];
    return cellHeight;
}

#pragma mark UITableViewDataSourceDynamicSizing
- (void)tableView:(UITableView*)tableView configureCell:(UITableViewCell*)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
    NSInteger rowType = [self.rowTypes[indexPath.row] integerValue];
    
    if (rowType == MITMobiusTableViewRowLocation ) {
        MITActionCell *actionCell = (MITActionCell*)cell;
        [actionCell setupCellOfType:MITActionRowTypeLocation withDetailText:self.resource.room];
        
    } else if (rowType == MITMobiusTableViewRowDetails ) {
        MITTitleDescriptionCell *titleDescriptionCell = (MITTitleDescriptionCell*)cell;
        
        MITMobiusTitleValueObject *titleValueObject = self.titleValueObjects[indexPath.row];
        
        NSString *title = titleValueObject.title;
        NSString *description = titleValueObject.value;
        [titleDescriptionCell setTitle:title withDescription:description];
        
    } else if (rowType == MITMobiusTableViewRowHours) {
        MITTitleDescriptionCell *titleDescriptionCell = (MITTitleDescriptionCell*)cell;
        
        MITMobiusDailyHoursObject *dailyHoursObject = self.hours[indexPath.row - self.startingHoursRow];
        
        [titleDescriptionCell setTitle:dailyHoursObject.dayName withDescription:dailyHoursObject.hours];
        
    } else if (rowType == MITMobiusTableViewRowHoursLabel) {
        MITActionCell *actionCell = (MITActionCell*)cell;
        [actionCell setupCellOfType:MITActionRowTypeHours withDetailText:@""];
        actionCell.userInteractionEnabled = NO;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger rowType = [self.rowTypes[indexPath.row] integerValue];

    if (rowType == MITMobiusTableViewRowLocation ) {
        [MITMapModelController openMapWithUnsanitizedSearchString:self.resource.room];
    }
}

#pragma mark UITableView Data Source/Delegate Helper Methods
- (NSString*)reuseIdentifierForRowAtIndexPath:(NSIndexPath*)indexPath
{
    NSInteger rowType = [self.rowTypes[indexPath.row] integerValue];

    if (self.currentSegementedSection == MITMobiusTableViewSectionShopDetails) {
        if (rowType == MITMobiusTableViewRowLocation) {
            return MITActionCellIdentifier;
        } else if (rowType == MITMobiusTableViewRowHoursLabel) {
            return MITActionCellIdentifier;
        } else if (rowType == MITMobiusTableViewRowHours) {
            return MITTitleDescriptionCellIdentifier;
        }
    } else if (self.currentSegementedSection == MITMobiusTableViewSectionSpecs) {
        return MITTitleDescriptionCellIdentifier;
    }
    return nil;
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == MITMobiusTableViewSectionSegmented) {
        UIView* const headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:MITMobiusSegmentedHeaderIdentifier];
        
        if ([headerView isKindOfClass:[MITMobiusSegmentedHeader class]]) {
            MITMobiusSegmentedHeader *segmentedHeaderView = (MITMobiusSegmentedHeader*)headerView;
            segmentedHeaderView.delegate = self;
            segmentedHeaderView.segmentedControl.selectedSegmentIndex = self.currentSegementedSection;
        }
        
        return headerView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == MITMobiusTableViewSectionSegmented) {
        UIView* const headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:MITMobiusSegmentedHeaderIdentifier];
        
        if ([headerView isKindOfClass:[MITMobiusSegmentedHeader class]]) {
            MITMobiusSegmentedHeader *segmentedHeaderView = (MITMobiusSegmentedHeader*)headerView;
            CGRect frame = segmentedHeaderView.frame;
            frame.size.width = self.tableView.bounds.size.width;
            segmentedHeaderView.contentView.frame = frame;
            
            CGSize fittingSize = [segmentedHeaderView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
            return fittingSize.height;
        }
    }
    return 0;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark MITMobiusSegmentedHeaderDelegate
- (void)detailSegmentControlAction:(UISegmentedControl *)segmentedControl
{
    self.currentSegementedSection = segmentedControl.selectedSegmentIndex;
    [self refreshEventRows];
}

@end