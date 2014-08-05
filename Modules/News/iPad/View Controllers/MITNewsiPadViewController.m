#import "MITNewsiPadViewController.h"
#import "MITNewsModelController.h"
#import "MITNewsStory.h"
#import "MITNewsCategory.h"
#import "MITNewsStoryCollectionViewCell.h"
#import "MITNewsConstants.h"
#import "MIT_MobileAppDelegate.h"
#import "MITCoreDataController.h"
#import "MITNewsStoryViewController.h"
#import "MITNewsSearchController.h"

#import "MITNewsListViewController.h"
#import "MITNewsGridViewController.h"
#import "MITMobile.h"
#import "MITCoreData.h"

#import "MITNewsStoriesDataSource.h"
#import "MITAdditions.h"

#import "MITNewsiPadCategoryViewController.h"

@interface MITNewsiPadViewController (NewsDataSource) <MITNewsStoryDataSource>

- (void)reloadItems:(void(^)(NSError *error))block;

- (void)loadDataSources:(void(^)(NSError*))completion;
@end

@interface MITNewsiPadViewController (NewsDelegate) <MITNewsStoryDelegate, MITNewsSearchDelegate, MITNewsStoryViewControllerDelegate>

@end

@interface MITNewsiPadViewController ()
@property (nonatomic, weak) IBOutlet UIView *containerView;
@property (nonatomic, weak) IBOutlet MITNewsGridViewController *gridViewController;
@property (nonatomic, weak) IBOutlet MITNewsListViewController *listViewController;
@property (nonatomic, strong) MITNewsSearchController *searchController;

@property (nonatomic, readonly, weak) UIViewController *activeViewController;
@property (nonatomic, getter=isSearching) BOOL searching;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIView *searchBarWrapper;

@property (nonatomic) NSUInteger currentDataSourceIndex;

#pragma mark Data Source
@property (nonatomic,copy) NSArray *categories;
@property (nonatomic,copy) NSArray *dataSources;
@end

@implementation MITNewsiPadViewController {
    BOOL _isTransitioningToPresentationStyle;
}

@synthesize activeViewController = _activeViewController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }
    return self;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.gridViewController.collectionView reloadData];
}
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.searchBar.frame = CGRectMake(0, 0, self.view.bounds.size.width - 50, 44);
        self.searchBarWrapper.frame = self.searchBar.bounds;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = YES;
    self.edgesForExtendedLayout = UIRectEdgeNone;

    if ([self class] == [MITNewsiPadViewController class]) {
        self.showsFeaturedStories = YES;
        self.containerView.backgroundColor = [UIColor whiteColor];
        self.containerView.autoresizesSubviews = YES;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    
    if (!self.activeViewController) {
        if ([self supportsPresentationStyle:MITNewsPresentationStyleGrid]) {
            [self setPresentationStyle:MITNewsPresentationStyleGrid animated:animated];
        } else {
            [self setPresentationStyle:MITNewsPresentationStyleList animated:animated];
        }
    }
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    if ([self class] == [MITNewsiPadViewController class]) {
        
        [self reloadItems:^(NSError *error) {
            if (error) {
                DDLogWarn(@"update failed; %@",error);
            }
        }];
        [self updateNavigationItem:YES];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Dynamic Properties
- (NSManagedObjectContext*)managedObjectContext
{
    if (!_managedObjectContext) {
        _managedObjectContext = [[MITCoreDataController defaultController] mainQueueContext];
    }

    return _managedObjectContext;
}

- (MITNewsGridViewController*)gridViewController
{
    MITNewsGridViewController *gridViewController = _gridViewController;

    if (![self supportsPresentationStyle:MITNewsPresentationStyleGrid]) {
        return nil;
    } else if (!gridViewController) {
        gridViewController = [[MITNewsGridViewController alloc] init];
        gridViewController.delegate = self;
        gridViewController.dataSource = self;
        gridViewController.automaticallyAdjustsScrollViewInsets = NO;
        gridViewController.edgesForExtendedLayout = UIRectEdgeAll;
        _gridViewController = gridViewController;
    }

    return gridViewController;
}

- (MITNewsListViewController*)listViewController
{
    MITNewsListViewController *listViewController = _listViewController;

    if (![self supportsPresentationStyle:MITNewsPresentationStyleList]) {
        return nil;
    } else if (!listViewController) {
        listViewController = [[MITNewsListViewController alloc] init];
        listViewController.delegate = self;
        listViewController.dataSource = self;

        listViewController.automaticallyAdjustsScrollViewInsets = NO;
        listViewController.edgesForExtendedLayout = UIRectEdgeAll;
        _listViewController = listViewController;
    }
    
    return listViewController;
}

- (MITNewsSearchController *)searchController
{
    if(!_searchController) {
        MITNewsSearchController *searchController = [[MITNewsSearchController alloc] init];
        searchController.view.frame = self.containerView.bounds;
        searchController.delegate = self;
        _searchController = searchController;
    }
    
    return _searchController;
}

- (UISearchBar *)searchBar
{
    if(!_searchBar) {
        UISearchBar *searchBar = [[UISearchBar alloc] init];
        searchBar.delegate = self.searchController;
        self.searchController.searchBar = searchBar;
        searchBar.searchBarStyle = UISearchBarStyleMinimal;
        searchBar.showsCancelButton = YES;
        _searchBar = searchBar;
    }
    return _searchBar;
}

#pragma mark UI Actions
- (void)setPresentationStyle:(MITNewsPresentationStyle)style
{
    [self setPresentationStyle:style animated:NO];
}

- (void)setPresentationStyle:(MITNewsPresentationStyle)style animated:(BOOL)animated
{
    NSAssert([self supportsPresentationStyle:style], @"presentation style %d is not supported on this device", style);

    if (![self supportsPresentationStyle:style]) {
        return;
    } else if ((_presentationStyle != style) || !self.activeViewController) {
        _presentationStyle = style;

        // Figure out which view controllers we are going to be
        // transitioning from/to.
        UIViewController *fromViewController = self.activeViewController;
        UIViewController *toViewController = nil;
        if (_presentationStyle == MITNewsPresentationStyleGrid) {
            toViewController = self.gridViewController;
        } else {
            toViewController = self.listViewController;
        }

        const CGRect viewFrame = self.containerView.bounds;
        fromViewController.view.frame = viewFrame;
        fromViewController.view.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
        toViewController.view.frame = viewFrame;
        toViewController.view.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);

        const NSTimeInterval animationDuration = (animated ? 0.25 : 0);
        _isTransitioningToPresentationStyle = YES;
        _activeViewController = toViewController;
        if (!fromViewController) {
            [self addChildViewController:toViewController];

            [UIView transitionWithView:self.containerView
                              duration:animationDuration
                               options:0
                            animations:^{
                                [self.containerView addSubview:toViewController.view];
                            } completion:^(BOOL finished) {
                                _isTransitioningToPresentationStyle = NO;
                                [toViewController didMoveToParentViewController:self];
                            }];
        } else {
            [fromViewController willMoveToParentViewController:nil];
            [self addChildViewController:toViewController];

            [self transitionFromViewController:fromViewController
                              toViewController:toViewController
                                      duration:animationDuration
                                       options:0
                                    animations:nil
                                    completion:^(BOOL finished) {
                                        _isTransitioningToPresentationStyle = NO;
                                        [toViewController didMoveToParentViewController:self];
                                        [fromViewController removeFromParentViewController];
                                    }];
        }
    }
}

- (IBAction)searchButtonWasTriggered:(UIBarButtonItem *)sender
{
    self.searching = YES;
    [self updateNavigationItem:YES];
    [self addChildViewController:self.searchController];
    [self.containerView addSubview:self.searchController.view];
    [self.searchController didMoveToParentViewController:self];
    [UIView animateWithDuration:(0.33)
                          delay:0.
                        options:UIViewAnimationCurveEaseOut
                     animations:^{
                         self.searchController.view.alpha = .5;
                     } completion:^(BOOL finished) {
                     }];
    [self.searchBar becomeFirstResponder];
}

- (IBAction)showStoriesAsGrid:(UIBarButtonItem *)sender
{
    self.presentationStyle = MITNewsPresentationStyleGrid;
    [self updateNavigationItem:YES];
}

- (IBAction)showStoriesAsList:(UIBarButtonItem *)sender
{
    self.presentationStyle = MITNewsPresentationStyleList;
    [self updateNavigationItem:YES];
}

#pragma mark Utility Methods
- (BOOL)supportsPresentationStyle:(MITNewsPresentationStyle)style
{
    if (style == MITNewsPresentationStyleList) {
        return YES;
    } else if (style == MITNewsPresentationStyleGrid) {
        const CGFloat minimumWidthForGrid = 768.;
        const CGFloat boundsWidth = CGRectGetWidth(self.view.bounds);
        
        return (boundsWidth >= minimumWidthForGrid);
    }
    return NO;
}

- (void)updateNavigationItem:(BOOL)animated
{
    NSMutableArray *rightBarItems = [[NSMutableArray alloc] init];

    if (self.presentationStyle == MITNewsPresentationStyleList) {
        if ([self supportsPresentationStyle:MITNewsPresentationStyleGrid]) {
            UIBarButtonItem *gridItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(showStoriesAsGrid:)];
            if (self.searching) {
                gridItem.enabled = NO;
            }
            [rightBarItems addObject:gridItem];
        }
    } else if (self.presentationStyle == MITNewsPresentationStyleGrid) {
        if ([self supportsPresentationStyle:MITNewsPresentationStyleList]) {
            UIImage *listImage = [UIImage imageNamed:@"map/item_list"];
            UIBarButtonItem *listItem = [[UIBarButtonItem alloc] initWithImage:listImage style:UIBarButtonItemStylePlain target:self action:@selector(showStoriesAsList:)];
            if (self.searching) {
                listItem.enabled = NO;
            }
            [rightBarItems addObject:listItem];
        }
    }
    if (self.searching) {
        UISearchBar *searchBar = self.searchBar;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.searchBar.frame = CGRectMake(0, 0, 400, 44);
        } else {
            self.searchBar.frame = CGRectMake(0, 0, self.view.bounds.size.width - 50, 44);
        }
        
        self.searchBarWrapper = [[UIView alloc]initWithFrame:searchBar.bounds];
        [self.searchBarWrapper addSubview:searchBar];
        UIBarButtonItem *searchBarItem = [[UIBarButtonItem alloc] initWithCustomView:self.searchBarWrapper];
        [rightBarItems addObject:searchBarItem];
        [self.navigationItem setTitle:@""];
        self.navigationController.view.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;

    } else {
        UIBarButtonItem *searchItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonWasTriggered:)];
        [rightBarItems addObject:searchItem];
        [self.navigationItem setTitle:@"MIT News"];
        self.navigationController.view.tintAdjustmentMode = UIViewTintAdjustmentModeAutomatic;
    }
    [self.navigationItem setRightBarButtonItems:rightBarItems animated:animated];
}

@end

@implementation MITNewsiPadViewController (NewsDataSource)

- (void)loadDataSources:(void (^)(NSError*))completion
{
    NSMutableArray *dataSources = [[NSMutableArray alloc] init];

    if (self.showsFeaturedStories) {
        MITNewsDataSource *featuredDataSource = [MITNewsStoriesDataSource featuredStoriesDataSource];
        featuredDataSource.maximumNumberOfItemsPerPage = 5;
        [dataSources addObject:featuredDataSource];
    }

    __weak MITNewsiPadViewController *weakSelf = self;
    [[MITNewsModelController sharedController] categories:^(NSArray *categories, NSError *error) {
        MITNewsiPadViewController *blockSelf = weakSelf;

        if (!blockSelf) {
            return;
        } else {
            NSMutableOrderedSet *categorySet = [[NSMutableOrderedSet alloc] init];

            [categories enumerateObjectsUsingBlock:^(MITNewsCategory *category, NSUInteger idx, BOOL *stop) {
                NSManagedObjectID *objectID = [category objectID];
                NSError *error = nil;
                NSManagedObject *object = [blockSelf.managedObjectContext existingObjectWithID:objectID error:&error];

                if (!object) {
                    DDLogWarn(@"failed to retreive object for ID %@: %@",object,error);
                } else {
                    [categorySet addObject:object];
                }
            }];

            [categories enumerateObjectsUsingBlock:^(MITNewsCategory *category, NSUInteger idx, BOOL *stop) {
                MITNewsDataSource *dataSource = [MITNewsStoriesDataSource dataSourceForCategory:category];
                [dataSources addObject:dataSource];
            }];

            blockSelf.categories = [categorySet array];
            blockSelf.dataSources = dataSources;
            [blockSelf refreshDataSources:completion];
        }
    }];
}

- (void)refreshDataSources:(void (^)(NSError*))completion
{
    __block dispatch_group_t refreshGroup = dispatch_group_create();
    __block NSError *updateError = nil;

    [self.dataSources enumerateObjectsUsingBlock:^(MITNewsDataSource *dataSource, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(refreshGroup);

        [dataSource refresh:^(NSError *error) {
            if (error) {
                DDLogWarn(@"failed to refresh data source %@",dataSource);

                if (!updateError) {
                    updateError = error;
                }
            } else {
                DDLogVerbose(@"refreshed data source %@",dataSource);
            }

            dispatch_group_leave(refreshGroup);
        }];
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        dispatch_group_wait(refreshGroup, DISPATCH_TIME_FOREVER);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(updateError);
        });

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (self.activeViewController == self.gridViewController) {
                [self.gridViewController.collectionView reloadData];
            } else if (self.activeViewController == self.listViewController) {
                [self.listViewController.tableView reloadData];
            }
        }];
    });
}

- (MITNewsDataSource*)dataSourceForCategoryInSection:(NSUInteger)section
{
    return self.dataSources[section];
}

- (BOOL)canLoadMoreItemsForCategoryInSection:(NSUInteger)section
{
    MITNewsDataSource *dataSource = [self dataSourceForCategoryInSection:section];
    return [dataSource hasNextPage];
}

- (BOOL)loadMoreItemsForCategoryInSection:(NSUInteger)section completion:(void(^)(NSError *error))block
{
    MITNewsDataSource *dataSource = [self dataSourceForCategoryInSection:section];
    [dataSource nextPage:block];
    
    return YES;
}

- (void)reloadItems:(void(^)(NSError *error))block
{
    if (_dataSources) {
        [self refreshDataSources:block];
    } else {
        [self loadDataSources:block];
    }
}

- (NSUInteger)numberOfCategoriesInViewController:(UIViewController*)viewController
{
    return [self.dataSources count];
}

- (NSString*)viewController:(UIViewController*)viewController titleForCategoryInSection:(NSUInteger)section
{
    if (self.isSearching) {
        return nil;
    } else if (self.showsFeaturedStories && (section == 0)) {
        return @"Featured";
    } else {
        __block NSString *title = nil;
        --section;

        MITNewsCategory *category = self.categories[section];
        [category.managedObjectContext performBlockAndWait:^{
            title = category.name;
        }];

        return title;
    }
}

- (NSUInteger)viewController:(UIViewController*)viewController numberOfStoriesForCategoryInSection:(NSUInteger)section
{
    if ([viewController class] == [MITNewsiPadCategoryViewController class]) {
        MITNewsDataSource *dataSource = [self dataSourceForCategoryInSection:section];
        return [dataSource.objects count];
    }
    if (self.showsFeaturedStories && (section == 0)) {
        return 5;
    } else {
        MITNewsDataSource *dataSource = [self dataSourceForCategoryInSection:section];
        return MIN([dataSource.objects count],10);
    }
}

- (MITNewsStory*)viewController:(UIViewController*)viewController storyAtIndex:(NSUInteger)index forCategoryInSection:(NSUInteger)section
{
    MITNewsDataSource *dataSource = [self dataSourceForCategoryInSection:section];
    return dataSource.objects[index];
}

- (BOOL)viewController:(UIViewController*)viewController isFeaturedCategoryInSection:(NSUInteger)section
{
    if (self.showsFeaturedStories) {
        return (section == 0);
    } else {
        return NO;
    }
}
@end

#pragma mark MITNewsStoryDetailPagingDelegate

@implementation MITNewsiPadViewController (NewsDelegate)

- (MITNewsStory*)viewController:(UIViewController *)viewController didSelectCategoryInSection:(NSUInteger)index;
{
    [self performSegueWithIdentifier:@"showCategory" sender:[NSIndexPath indexPathForItem:0 inSection:index]];
    return nil;
}

- (MITNewsStory*)viewController:(UIViewController *)viewController didSelectStoryAtIndex:(NSUInteger)index forCategoryInSection:(NSUInteger)section;
{
    self.currentDataSourceIndex = section;
 
    [self performSegueWithIdentifier:@"showStoryDetail" sender:[NSIndexPath indexPathForItem:index inSection:section]];
    return nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UIViewController *destinationViewController = [segue destinationViewController];
    
    DDLogVerbose(@"Performing segue with identifier '%@'",[segue identifier]);
    
    if ([segue.identifier isEqualToString:@"showStoryDetail"]) {
        if ([destinationViewController isKindOfClass:[MITNewsStoryViewController class]]) {

            NSIndexPath *indexPath = sender;

            MITNewsStoryViewController *storyDetailViewController = (MITNewsStoryViewController*)destinationViewController;
            storyDetailViewController.delegate = self;
            MITNewsStory *story = [self viewController:self storyAtIndex:indexPath.row forCategoryInSection:indexPath.section];
            if (story) {
                NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
                managedObjectContext.parentContext = self.managedObjectContext;
                storyDetailViewController.managedObjectContext = managedObjectContext;
                storyDetailViewController.story = (MITNewsStory*)[managedObjectContext existingObjectWithID:[story objectID] error:nil];
                
            }
        } else {
            DDLogWarn(@"unexpected class for segue %@. Expected %@ but got %@",segue.identifier,
                      NSStringFromClass([MITNewsStoryViewController class]),
                      NSStringFromClass([[segue destinationViewController] class]));
        }
    } else if ([segue.identifier isEqualToString:@"showCategory"]) {
        
        NSIndexPath *indexPath = sender;

        MITNewsiPadCategoryViewController *iPadCategoryViewController  = (MITNewsiPadCategoryViewController*)destinationViewController;
        iPadCategoryViewController.dataSource = self.dataSources[indexPath.section];
        iPadCategoryViewController.categoryTitle = [self viewController:self titleForCategoryInSection:indexPath.section];
        
        
    } else {
        DDLogWarn(@"[%@] unknown segue '%@'",self,segue.identifier);
    }
}


#pragma mark MITNewsStoryDetailPagingDelegate

- (void)storyAfterStory:(MITNewsStory *)story return:(void (^)(MITNewsStory *, NSError *))block
{
    
    MITNewsStory *currentStory = (MITNewsStory*)[self.managedObjectContext existingObjectWithID:[story objectID] error:nil];
    
    MITNewsDataSource *dataSource = self.dataSources[self.currentDataSourceIndex];
    
    NSInteger currentIndex = [dataSource.objects indexOfObject:currentStory];
    if (currentIndex != NSNotFound) {
        
        if (currentIndex + 1 < [dataSource.objects count]) {
            if(block) {
                block(dataSource.objects[currentIndex +1], nil);
            }
        } else {
            __block NSError *updateError = nil;
            if ([dataSource hasNextPage]) {
                [dataSource nextPage:^(NSError *error) {
                    if (error) {
                        DDLogWarn(@"failed to refresh data source %@",dataSource);
                        
                        if (!updateError) {
                            updateError = error;
                        }
                    } else {
                        DDLogVerbose(@"refreshed data source %@",dataSource);
                        NSInteger currentIndex = [dataSource.objects indexOfObject:currentStory];
                        
                        if (currentIndex + 1 < [dataSource.objects count]) {
                            if(block) {
                                block(dataSource.objects[currentIndex + 1], nil);
                            }
                        }
                    }
                }];
            }
        }
    }
}

- (void)hideSearchField
{
    self.searchBar = nil;
    [self.searchController.view removeFromSuperview];
    [self.searchController removeFromParentViewController];
    self.searchController = nil;
    self.searching = NO;
    [self updateNavigationItem:YES];
}

@end
