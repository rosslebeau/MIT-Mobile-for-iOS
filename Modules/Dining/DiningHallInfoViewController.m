#import "DiningHallInfoViewController.h"
#import "DiningHallDetailHeaderView.h"
#import "VenueLocation.h"
#import "CoreDataManager.h"

#import "UIKit+MITAdditions.h"
#import "Foundation+MITAdditions.h"
#import "UIImageView+WebCache.h"
#import "DiningDay.h"
#import "DiningMeal.h"
#import "DiningHallInfoScheduleCell.h"

static NSInteger const kPaymentSectionIndex = 0;
static NSInteger const kScheduleSectionIndex = 1;
static NSInteger const kLocationSectionIndex = 2;

@interface DiningHallInfoViewController ()

@property (nonatomic, strong) NSArray * scheduleInfo;

@end

@implementation DiningHallInfoViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

- (BOOL) shouldAutorotate
{
    return NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView applyStandardColors];
    self.tableView.backgroundColor = [UIColor whiteColor];
    [self fetchScheduleInfo];
    
    self.title = self.venue.shortName;
    
    DiningHallDetailHeaderView *headerView = [[DiningHallDetailHeaderView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), 87)];
    headerView.titleLabel.text = self.venue.name;
    
    __weak DiningHallDetailHeaderView *weakHeaderView = headerView;
    [headerView.iconView setImageWithURL:[NSURL URLWithString:self.venue.iconURL]
                               completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType) {
        [weakHeaderView setNeedsLayout];
    }];
    
    if ([self.venue isOpenNow]) {
        headerView.timeLabel.textColor = [UIColor colorWithHexString:@"#009900"];
    } else {
        headerView.timeLabel.textColor = [UIColor colorWithHexString:@"#d20000"];
    }
    DiningDay *currentDay = [self.venue dayForDate:[NSDate date]];
    headerView.timeLabel.text = [currentDay statusStringRelativeToDate:[NSDate date]];
    self.tableView.tableHeaderView = headerView;

    self.tableView.separatorColor = [UIColor clearColor];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Querying for Schedule Info

- (void) fetchScheduleInfo
{
    NSArray *daysInWeek = [DiningDay daysInWeekOfDate:[NSDate date] forVenue:self.venue]; 
    NSMutableArray *schedules = [NSMutableArray array];
    
    NSTimeInterval oneDay = 60*60*24;
    DiningDay *previousDay = nil;
    for (DiningDay *day in daysInWeek) {
        
        NSArray *daySchedule = [self scheduleInfoForDiningDay:day];
        if (![daySchedule count]) {
            daySchedule = @[@{@"mealName": @"Closed", @"mealSpan" : @""}];
        }
        
        if (!previousDay) {
            // first run through
            // set span start and end to the same thing, add daySchedule
            NSDictionary *scheduleDict = @{@"dayStart": day.date,
                                           @"dayEnd": day.date,
                                           @"meals":daySchedule};
            [schedules addObject:scheduleDict];
        } else {
            if ([previousDay.date timeIntervalSinceDate:day.date] <= oneDay) {
                // if day is adjacent need to compare schedules
                NSArray *previousSchedules = [schedules lastObject][@"meals"];  // lastObject will be previously added scheduleDict
                if ([previousSchedules isEqualToArray:daySchedule]) {
                    // comparison is equal, append day by bumping previous scheduleDict
                    NSMutableDictionary *previousScheduleDict = [[schedules lastObject] mutableCopy];
                    previousScheduleDict[@"dayEnd"] = day.date;
                    schedules[[schedules count]-1] = previousScheduleDict;
                } else {
                    // comparison is not equal add new day
                    NSDictionary *scheduleDict = @{@"dayStart": day.date,
                                                   @"dayEnd": day.date,
                                                   @"meals":daySchedule};
                    [schedules addObject:scheduleDict];
                }
            } else {
                // days are not adjacent, add new day
                NSDictionary *scheduleDict = @{@"dayStart": day.date,
                                               @"dayEnd": day.date,
                                               @"meals":daySchedule};
                [schedules addObject:scheduleDict];
            }
        }
        
        previousDay = day;  // update reference to look behind
    }
    
    self.scheduleInfo = schedules;
}

- (NSArray *) scheduleInfoForDiningDay:(DiningDay *)day
{
    
    NSSortDescriptor * sortByStartTime = [NSSortDescriptor sortDescriptorWithKey:@"startTime" ascending:YES];       // TODO:: if meal does not have startTime will not be sorted correctly, spec has message as property of DiningDay, not DiningMeal
    NSArray *meals = [[day.meals array] sortedArrayUsingDescriptors:@[sortByStartTime]];
    
    NSMutableArray *mealSchedules = [NSMutableArray array];
    for (DiningMeal *meal in meals) {
        NSDictionary *mealSchedule = [self scheduleDictionaryForMeal:meal];
        [mealSchedules addObject:mealSchedule];
    }

    return mealSchedules;
}

- (NSDictionary *) scheduleDictionaryForMeal:(DiningMeal *) meal
{
    NSString *mealName = [meal.name capitalizedString];
    
    if (meal.message) {
        return @{@"mealName": mealName, @"mealSpan": meal.message};                     // if meal has a message set use that instead
    }
    
    NSString *startString = [self timeFormatForMealTime:meal.startTime];
    NSString *endString = [self timeFormatForMealTime:meal.endTime];
    
    NSString *mealSpan = [NSString stringWithFormat:@"%@ - %@", startString, endString];     
    return @{@"mealName": mealName, @"mealSpan": mealSpan};
}

- (NSString *) timeFormatForMealTime:(NSDate *) date
{
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSHourCalendarUnit|NSMinuteCalendarUnit fromDate:date];
    
    NSString *longFormat = @"h:mma";
    NSString *shortFormat = @"ha";
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setPMSymbol:@"pm"];
    [df setAMSymbol:@"am"];
    
    if (comps.minute == 0) {
        [df setDateFormat:shortFormat];
    } else {
        [df setDateFormat:longFormat];
    }
    return [df stringFromDate:date];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kScheduleSectionIndex) {
        return [self.scheduleInfo count];
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != kScheduleSectionIndex) {
        static NSString *CellIdentifier = @"Cell";
        MITDiningCustomSeparatorCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (!cell) {
            cell = [[MITDiningCustomSeparatorCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.textLabel.textColor = [UIColor mit_tintColor];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:17];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        if (indexPath.section == kLocationSectionIndex) {
            cell.textLabel.text = @"location";
            cell.detailTextLabel.text = self.venue.location.displayDescription;
            cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewMap];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.shouldIncludeSeparator = NO;
        } else if (indexPath.section == kPaymentSectionIndex) {
            cell.textLabel.text = @"payment";
            cell.detailTextLabel.text = [[self.venue.paymentMethods allObjects] componentsJoinedByString:@", "];
            cell.shouldIncludeSeparator = YES;
        }
        
        return cell;
    } else {
        // schedule
        NSDictionary *rowSchedule = self.scheduleInfo[indexPath.row];

        DiningHallInfoScheduleCell *scheduleCell = [tableView dequeueReusableCellWithIdentifier:@"ScheduleCell"];
        if (!scheduleCell) {
            scheduleCell = [[DiningHallInfoScheduleCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ScheduleCell"];
        }
        [scheduleCell setStartDate:rowSchedule[@"dayStart"] andEndDate:rowSchedule[@"dayEnd"]];
        scheduleCell.scheduleInfo = rowSchedule[@"meals"];
        scheduleCell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        if (indexPath.row == self.scheduleInfo.count - 1) {
            scheduleCell.shouldIncludeSeparator = YES;
            scheduleCell.shouldIncludeTopPadding = NO;
        } else {
            scheduleCell.shouldIncludeSeparator = NO;
            scheduleCell.shouldIncludeTopPadding = YES;
        }

        return scheduleCell;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == kLocationSectionIndex && self.venue.location.displayDescription) {
        NSURL *url = [NSURL internalURLWithModuleTag:CampusMapTag path:@"search" query:self.venue.location.displayDescription];
        [[UIApplication sharedApplication] openURL:url];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kScheduleSectionIndex) {
        NSDictionary *rowSchedule = self.scheduleInfo[indexPath.row];
        BOOL shouldHaveTopPadding = NO;
        if (indexPath.row == 0) {
            shouldHaveTopPadding = YES;
        }
        
        return [DiningHallInfoScheduleCell heightForCellWithScheduleInfo:rowSchedule[@"meals"] withTopPadding:shouldHaveTopPadding];
    }
    return 60;
}

@end
