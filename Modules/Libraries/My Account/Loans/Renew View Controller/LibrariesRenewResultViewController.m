#import "LibrariesRenewResultViewController.h"
#import "LibrariesLoanTableViewCell.h"
#import "MobileRequestOperation.h"
#import "MITTabHeaderView.h"
#import "UIKit+MITAdditions.h"

@interface LibrariesRenewResultViewController ()
@property (nonatomic,retain) NSArray *renewItems;
@property (nonatomic,retain) UIView *headerView;
@property (nonatomic,assign) UITableView *tableView;

- (UIView*)tableHeaderViewForWidth:(CGFloat)width;
@end

@implementation LibrariesRenewResultViewController
@synthesize renewItems = _renewItems;
@synthesize tableView = _tableView;
@synthesize headerView = _headerView;

- (id)init
{
    return [self initWithItems:nil];
}

- (id)initWithItems:(NSArray*)renewItems
{
    self = [super initWithNibName:nil bundle:nil];
    
    if (self)
    {
        // filter out NSNulls that might have come through the JSON parser
        NSIndexSet *validItems = [renewItems indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            if ([[obj valueForKey:@"details"] isKindOfClass:[NSDictionary class]]) {
                return YES;
            } else {
                return NO;
            }
        }];
        self.renewItems = [renewItems objectsAtIndexes:validItems];
        self.title = @"Renew";
        self.navigationItem.hidesBackButton = YES;
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                                target:self
                                                                                                action:@selector(done:)] autorelease];
    }
    
    return self;
}

- (void)dealloc
{
    self.renewItems = nil;
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - View lifecycle
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    CGRect mainFrame = [[UIScreen mainScreen] applicationFrame];
    
    if (self.navigationController.toolbarHidden == NO) 
    {
        mainFrame.origin.y += CGRectGetHeight(self.navigationController.toolbar.frame);
    }
    
    {
        UITableView *view = [[[UITableView alloc] initWithFrame:mainFrame
                                                          style:UITableViewStylePlain] autorelease];
        view.delegate = self;
        view.dataSource = self;
        
        UIView *header = [self tableHeaderViewForWidth:CGRectGetWidth(mainFrame)];
        view.tableHeaderView = header;
        
        self.tableView = view;
        [self setView:view];
    }
}

- (UIView*)tableHeaderViewForWidth:(CGFloat)width
{
    NSIndexSet *failureIndexes = [self.renewItems indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return ([obj valueForKey:@"error"] != nil);
    }];
    NSUInteger failureCount = [failureIndexes count];
    NSUInteger successCount = [self.renewItems count] - failureCount; 
    
    // This initial size is arbitrary.
    UIView *headerView = [[MITTabHeaderView alloc] initWithFrame:CGRectMake(0.0, 0.0, 100.0, 100.0)];
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    UIEdgeInsets headerInsets = UIEdgeInsetsMake(8, 10, 9, 10);
    __block CGRect contentFrame = UIEdgeInsetsInsetRect(headerView.frame, headerInsets);

    contentFrame.size.height = 0.0;
    
    void(^addIconAndLabel)(UIImage *, NSString *) = ^(UIImage *image, NSString *text) {
        UIImageView *icon = [[[UIImageView alloc] initWithImage:image] autorelease];
        icon.autoresizingMask = UIViewAutoresizingNone;
        
        CGRect iconFrame = icon.frame;
        iconFrame.origin = CGPointMake(contentFrame.origin.x, contentFrame.origin.y + 1.0);
        icon.frame = iconFrame;
        iconFrame.size.width += 4.0;
        
        UILabel *label = [[[UILabel alloc] init] autorelease];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor colorWithHexString:@"#404649"];
        label.font = [UIFont systemFontOfSize:14.0];
        label.lineBreakMode = UILineBreakModeTailTruncation;
        label.text = text;
        
        CGRect labelFrame = label.frame;
        labelFrame.origin.x = CGRectGetMaxX(iconFrame);
        labelFrame.origin.y = contentFrame.origin.y;
        labelFrame.size.width = contentFrame.size.width - iconFrame.size.width;
        labelFrame.size.height = label.font.lineHeight;
        label.frame = labelFrame;
        
        [headerView addSubview:icon];
        [headerView addSubview:label];
        
        contentFrame.origin.y += CGRectGetHeight(label.frame) + 3.0;
        
        CGFloat height = MAX(CGRectGetMaxY(icon.frame), CGRectGetMaxY(label.frame));
        contentFrame.size.height = MAX(contentFrame.size.height, height);
    };
    
    if (successCount) {
        addIconAndLabel([UIImage imageNamed:@"libraries/status-ok"], 
                        [NSString stringWithFormat:@"%lu renewed successfully!", successCount]);
    }
    
    if (failureCount) {
        addIconAndLabel([UIImage imageNamed:@"libraries/status-error"], 
                        [NSString stringWithFormat:@"%lu could not be renewed.", failureCount]);
    }
    
    contentFrame.origin = CGPointZero;
    contentFrame.size.height += headerInsets.bottom; // top is already accounted for by the use of CGRectGetMaxY()
    
    headerView.frame = contentFrame;
    
    return [headerView autorelease];
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - UITableView Delegate
- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}

#pragma mark - UITableView Data Source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.renewItems count];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* CellIdentifier = @"LibariesHoldsTableViewCell";
    
    LibrariesLoanTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[[LibrariesLoanTableViewCell alloc] initWithReuseIdentifier:CellIdentifier] autorelease];
    }
    
    NSDictionary *bookDetails = [self.renewItems objectAtIndex:indexPath.row];
    cell.itemDetails = [bookDetails objectForKey:@"details"];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static LibrariesLoanTableViewCell *cell = nil;
    if (cell == nil) {
        cell = [[LibrariesLoanTableViewCell alloc] init];
    }
    
    NSDictionary *bookDetails = [self.renewItems objectAtIndex:indexPath.row];
    cell.itemDetails = [bookDetails objectForKey:@"details"];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    return [cell heightForContentWithWidth:CGRectGetWidth(tableView.frame)];
}

#pragma mark - Event Handlers
- (IBAction)done:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}
@end