#import <UIKit/UIKit.h>
#import "MITFetchedResultsTableViewController.h"

@class MITNewsCategory;

@interface MITNewsStoriesViewController : MITFetchedResultsTableViewController
@property (nonatomic,strong) MITNewsCategory *category;

@end
