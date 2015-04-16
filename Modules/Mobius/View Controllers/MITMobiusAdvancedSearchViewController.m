#import "MITMobiusAdvancedSearchViewController.h"
#import "MITMobiusAttributesDataSource.h"
#import "MITMobiusModel.h"

@interface MITMobiusAdvancedSearchViewController ()
@property (nonatomic,strong) MITMobiusAttributesDataSource *dataSource;
@property (nonatomic,strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic,strong) MITMobiusRecentSearchQuery *query;
@end

static NSString* const MITMobiusAdvancedSearchSelectedAttributeCellIdentifier = @"SelectedAttributeCellIdentifier";
static NSString* const MITMobiusAdvancedSearchAttributeCellIdentifier = @"AttributeCellIdentifier";
static NSString* const MITMobiusAdvancedSearchAttributeValueCellIdentifier = @"AttributeValueCellIdentifier";

typedef NS_ENUM(NSInteger, MITMobiusAdvancedSearchSection) {
    MITMobiusAdvancedSearchSelectedAttributes,
    MITMobiusAdvancedSearchAttributes
};

@interface MITMobiusAdvancedSearchViewController ()
@property (nonatomic,strong) NSIndexPath *currentExpandedIndexPath;
@end

@implementation MITMobiusAdvancedSearchViewController
- (instancetype)init
{
    self = [self initWithQuery:nil];

    if (self) {

    }

    return self;
}

- (instancetype)initWithString:(NSString*)queryString
{
    self = [self initWithQuery:nil];

    if (self) {
        if (queryString.length) {
            _query = (MITMobiusRecentSearchQuery*)[self.managedObjectContext insertNewObjectForEntityForName:[MITMobiusRecentSearchQuery entityName]];
            _query.text = queryString;
        }
    }

    return self;
}

- (instancetype)initWithQuery:(MITMobiusRecentSearchQuery *)query
{
    self = [super initWithStyle:UITableViewStyleGrouped];

    if (self) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _managedObjectContext.parentContext = [MITCoreDataController defaultController].mainQueueContext;
        _dataSource = [[MITMobiusAttributesDataSource alloc] initWithManagedObjectContext:_managedObjectContext];

        if (query) {
            _query = (MITMobiusRecentSearchQuery*)[_managedObjectContext existingObjectWithID:query.objectID error:nil];
        }
    }

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:MITMobiusAdvancedSearchAttributeCellIdentifier];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:MITMobiusAdvancedSearchSelectedAttributeCellIdentifier];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:MITMobiusAdvancedSearchAttributeValueCellIdentifier];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (self.navigationController) {
        UIBarButtonItem *cancelBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(_cancelButtonWasTapped:)];
        UIBarButtonItem *doneBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(_doneButtonWasTapped:)];

        [self.navigationItem setLeftBarButtonItem:cancelBarButtonItem animated:animated];
        [self.navigationItem setRightBarButtonItem:doneBarButtonItem animated:animated];
    }

    if (!self.query) {
        self.query = (MITMobiusRecentSearchQuery*)[self.managedObjectContext insertNewObjectForEntityForName:[MITMobiusRecentSearchQuery entityName]];
    }

    [self.dataSource attributes:^(MITMobiusAttributesDataSource *dataSource, NSError *error) {
        [self.tableView reloadData];
    }];

}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.query.isUpdated || self.query.isNew) {
        [self.managedObjectContext saveToPersistentStore:nil];
    }
}

#pragma mark Interface Actions
- (IBAction)_cancelButtonWasTapped:(UIBarButtonItem*)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)_doneButtonWasTapped:(UIBarButtonItem*)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Data Updating
- (void)_collapseItemAtIndexPath:(NSIndexPath*)indexPath
{
    MITMobiusAttribute *attribute = [self attributeForIndexPath:indexPath];

    NSMutableArray *deletionIndexPaths = [[NSMutableArray alloc] init];
    NSRange deletionRange = NSMakeRange(indexPath.row + 1, attribute.values.count);
    NSIndexSet *deletionIndexSet = [NSIndexSet indexSetWithIndexesInRange:deletionRange];
    [deletionIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [deletionIndexPaths addObject:[NSIndexPath indexPathForRow:idx inSection:indexPath.section]];
    }];

    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView deleteRowsAtIndexPaths:deletionIndexPaths withRowAnimation:UITableViewRowAnimationBottom];
}

- (void)_expandItemAtIndexPath:(NSIndexPath*)indexPath
{
    MITMobiusAttribute *attribute = [self attributeForIndexPath:indexPath];

    NSMutableArray *insertionIndexPaths = [[NSMutableArray alloc] init];
    NSRange insertionRange = NSMakeRange(indexPath.row + 1, attribute.values.count);
    NSIndexSet *insertionIndexSet = [NSIndexSet indexSetWithIndexesInRange:insertionRange];
    [insertionIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [insertionIndexPaths addObject:[NSIndexPath indexPathForRow:idx inSection:indexPath.section]];
    }];

    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView insertRowsAtIndexPaths:insertionIndexPaths withRowAnimation:UITableViewRowAnimationBottom];
}

#pragma mark table helper methods
- (NSIndexPath*)indexPathForAttribute:(MITMobiusAttribute*)attribute
{
    NSUInteger attributesSection = 1;
    NSUInteger indexOfAttribute = [self.dataSource.attributes indexOfObject:attribute];

    if (self.currentExpandedIndexPath) {
        if (indexOfAttribute > self.currentExpandedIndexPath.row) {
            MITMobiusAttribute *expandedAttribute = [self attributeForIndexPath:self.currentExpandedIndexPath];
            NSUInteger row = indexOfAttribute - expandedAttribute.values.count;
            return [NSIndexPath indexPathForRow:row inSection:attributesSection];
        }

    }

    return [NSIndexPath indexPathForRow:indexOfAttribute inSection:attributesSection];
}

- (MITMobiusAttribute*)attributeForIndexPath:(NSIndexPath*)indexPath
{
    MITMobiusAdvancedSearchSection section = [self _typeForSection:indexPath.section];
    NSAssert(section == MITMobiusAdvancedSearchAttributes, @"attempting to get an attribute for an invalid section");

    NSUInteger targetRow = indexPath.row;

    if (self.currentExpandedIndexPath) {
        MITMobiusAttribute *expandedAttribute = self.dataSource.attributes[self.currentExpandedIndexPath.row];
        NSRange attributeValueRange = NSMakeRange(self.currentExpandedIndexPath.row + 1, expandedAttribute.values.count);

        if (NSLocationInRange(targetRow, attributeValueRange)) {
            targetRow = self.currentExpandedIndexPath.row;
        } else if (targetRow > self.currentExpandedIndexPath.row) {
            targetRow -= expandedAttribute.values.count;
        }
    }

    return self.dataSource.attributes[targetRow];
}

- (BOOL)isAttributeValueAtIndexPath:(NSIndexPath*)indexPath
{
    NSParameterAssert(indexPath);

    if (self.currentExpandedIndexPath) {
        MITMobiusAttributeValue *value = [self valueForIndexPath:indexPath];
        
        if (value) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

- (MITMobiusAttributeValue*)valueForIndexPath:(NSIndexPath*)indexPath
{
    MITMobiusAdvancedSearchSection section = [self _typeForSection:indexPath.section];
    NSAssert(section == MITMobiusAdvancedSearchAttributes, @"attempting to get an attribute for an invalid section");

    MITMobiusAttribute *attribute = [self attributeForIndexPath:indexPath];
    NSIndexPath *attributeIndexPath = [self indexPathForAttribute:attribute];

    // If we are tapping the attribute name (and not one of the values, we are
    // obviously not where we should be and need to bail
    if ([indexPath isEqual:attributeIndexPath]) {
        return nil;
    } else if ([self.currentExpandedIndexPath isEqual:attributeIndexPath]) {
        if (attribute.type == MITMobiusAttributeTypeNumeric) {
            return nil;
        } else if (attribute.type == MITMobiusAttributeTypeString) {
            return nil;
        } else if (attribute.type == MITMobiusAttributeTypeText) {
            return nil;
        } else {
            return attribute.values[indexPath.row - attributeIndexPath.row - 1];
        }
    } else {
        return nil;
    }
}

- (MITMobiusAdvancedSearchSection)_typeForSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return MITMobiusAdvancedSearchSelectedAttributes;

        default:
            return MITMobiusAdvancedSearchAttributes;
    }
}

- (NSString*)_identifierForRowAtIndexPath:(NSIndexPath*)indexPath
{
    MITMobiusAdvancedSearchSection section = [self _typeForSection:indexPath.section];

    switch (section) {
        case MITMobiusAdvancedSearchAttributes: {
            if ([self isAttributeValueAtIndexPath:indexPath]) {
                return MITMobiusAdvancedSearchAttributeValueCellIdentifier;
            } else {
                return MITMobiusAdvancedSearchAttributeCellIdentifier;
            }
        }

        case MITMobiusAdvancedSearchSelectedAttributes: {
            return MITMobiusAdvancedSearchSelectedAttributeCellIdentifier;
        }
    }
}

#pragma mark UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        if (self.query.text.length) {
            return self.query.options.count + 1;
        } else {
            return self.query.options.count;
        }
    } else if (section == 1) {
        if (self.currentExpandedIndexPath) {
            MITMobiusAttribute *expandedAttribute = [self attributeForIndexPath:self.currentExpandedIndexPath];
            return self.dataSource.attributes.count + expandedAttribute.values.count;
        } else {
            return self.dataSource.attributes.count;
        }
    }

    return 0;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *cellIdentifier = [self _identifierForRowAtIndexPath:indexPath];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];

    [self tableView:tableView configureCell:cell forRowAtIndexPath:indexPath];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.;
}

- (void)tableView:(UITableView *)tableView configureCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];

    if ([cell.reuseIdentifier isEqualToString:MITMobiusAdvancedSearchSelectedAttributeCellIdentifier]) {
        NSUInteger index = indexPath.row;

        if (index == 0 && self.query.text.length) {
            cell.textLabel.text = [NSString stringWithFormat:@"\"%@\"",self.query.text];
            cell.detailTextLabel.text = @"Text";
        } else {
            if (self.query.text.length) {
                --index;
            }

            MITMobiusSearchOption *option = self.query.options[index];
            cell.textLabel.text = option.value;
            cell.detailTextLabel.text = option.attribute.label;
        }
    } else if ([cell.reuseIdentifier isEqualToString:MITMobiusAdvancedSearchAttributeCellIdentifier]) {
        MITMobiusAttribute *attribute = [self attributeForIndexPath:indexPath];
        cell.textLabel.text = attribute.label;

        BOOL isAttributeExpanded = [indexPath isEqual:self.currentExpandedIndexPath];
        UIImage *image = nil;
        if (isAttributeExpanded) {
            image = [UIImage imageNamed:MITImageMobiusAccordionOpened];
        } else {
            image = [UIImage imageNamed:MITImageMobiusAccordionClosed];
        }
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = [[UIImageView alloc] initWithImage:image];
    } else if ([cell.reuseIdentifier isEqualToString:MITMobiusAdvancedSearchAttributeValueCellIdentifier]) {
        MITMobiusAttributeValue *value = [self valueForIndexPath:indexPath];
        cell.textLabel.text = value.text;
        cell.indentationLevel = 2;

        if ([self isAttributeValueSelected:value]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else {
        NSString *reason = [NSString stringWithFormat:@"unknown cell reuse identifier %@",cell.reuseIdentifier];
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:nil];
    }
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MITMobiusAdvancedSearchSection sectionType = [self _typeForSection:indexPath.section];
    if (sectionType == MITMobiusAdvancedSearchAttributes) {
        [tableView beginUpdates];

        if ([self isAttributeValueAtIndexPath:indexPath]) {
            MITMobiusAttributeValue *attributeValue = [self valueForIndexPath:indexPath];

            if (![self isAttributeValueSelected:attributeValue]) {
                [self setAttributeValue:attributeValue];
            } else {
                [self unsetAttributeValue:attributeValue];
            }
        } else {
            // To account for -[NSIndexPath isEqual:] not always returning true, even if it is
            indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section];
            MITMobiusAttribute *newAttribute = [self attributeForIndexPath:indexPath];

            if ([indexPath isEqual:self.currentExpandedIndexPath]) {
                self.currentExpandedIndexPath = nil;
                [self _collapseItemAtIndexPath:indexPath];
            } else {
                if (self.currentExpandedIndexPath) {
                    [self _collapseItemAtIndexPath:self.currentExpandedIndexPath];
                }

                NSIndexPath *newIndexPath = [self indexPathForAttribute:newAttribute];
                self.currentExpandedIndexPath = newIndexPath;
                [self _expandItemAtIndexPath:newIndexPath];
            }
        }

        [tableView endUpdates];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (void)unsetAttributeValue:(MITMobiusAttributeValue*)attributeValue
{
    NSParameterAssert(attributeValue);

    MITMobiusAttributeType type = attributeValue.attribute.type;
    BOOL isAttributeOptionType = (type == MITMobiusAttributeTypeOptionSingle |
                                  type == MITMobiusAttributeTypeAutocompletion |
                                  type == MITMobiusAttributeTypeOptionMultiple);
    NSAssert(isAttributeOptionType, @"attempting to clear attribute value on an attribute which should not have a valueset");

    __block MITMobiusSearchOption *searchOption = nil;
    [self.query.options enumerateObjectsUsingBlock:^(MITMobiusSearchOption *option, NSUInteger idx, BOOL *stop) {
        if ([option.attribute isEqual:attributeValue.attribute]) {
            searchOption = option;
            (*stop) = YES;
        }
    }];

    // Using this method because Apple's generated methods adding items to
    // ordered, to-many relationships are bugged and will crash with an error since the
    // generated methods do not create the proper set objects.
    NSMutableOrderedSet *values = [searchOption mutableOrderedSetValueForKey:@"values"];
    if (values.count <= 1) {
        NSMutableOrderedSet *options = [self.query mutableOrderedSetValueForKey:@"options"];
        [options removeObject:searchOption];
        [self.managedObjectContext deleteObject:searchOption];
    } else {
        [values removeObject:attributeValue];
    }

    NSIndexPath *indexPath = [self indexPathForAttribute:attributeValue.attribute];
    NSInteger index = [attributeValue.attribute.values indexOfObject:attributeValue] + 1; // Add one to account for attribute row
    indexPath = [NSIndexPath indexPathForRow:(index + indexPath.row) inSection:indexPath.section];

    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:MITMobiusAdvancedSearchSelectedAttributes] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)setAttributeValue:(MITMobiusAttributeValue*)attributeValue
{
    NSParameterAssert(attributeValue);

    MITMobiusAttributeType type = attributeValue.attribute.type;
    BOOL isAttributeOptionType = (type == MITMobiusAttributeTypeOptionSingle |
                                  type == MITMobiusAttributeTypeAutocompletion |
                                  type == MITMobiusAttributeTypeOptionMultiple);
    NSAssert(isAttributeOptionType, @"attempting to set attribute value on an attribute which should not have a valueset");

    __block MITMobiusSearchOption *searchOption = nil;
    [self.query.options enumerateObjectsUsingBlock:^(MITMobiusSearchOption *option, NSUInteger idx, BOOL *stop) {
        if ([option.attribute isEqual:attributeValue.attribute]) {
            searchOption = option;
            (*stop) = YES;
        }
    }];

    if (!searchOption) {
        searchOption = (MITMobiusSearchOption*)[self.managedObjectContext insertNewObjectForEntityForName:[MITMobiusSearchOption entityName]];
        searchOption.attribute = attributeValue.attribute;
        searchOption.query = self.query;
    }

    // Using this method because Apple's generated methods adding items to
    // ordered, to-many relationships are bugged and will crash with an err
    NSMutableOrderedSet *values = [searchOption mutableOrderedSetValueForKey:@"values"];
    if (type == MITMobiusAttributeTypeOptionSingle) {
        [values removeAllObjects];
    }

    [values addObject:attributeValue];

    NSInteger index = [self.query.options indexOfObject:searchOption];

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:MITMobiusAdvancedSearchSelectedAttributes];
    if (index >= [self.tableView numberOfRowsInSection:MITMobiusAdvancedSearchSelectedAttributes]) {
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }

    NSIndexPath *attributeIndexPath = [self indexPathForAttribute:attributeValue.attribute];
    if ([self.currentExpandedIndexPath isEqual:attributeIndexPath]) {
        NSMutableArray *updatedIndexPaths = [[NSMutableArray alloc] init];
        for (int idx = 1; idx < attributeValue.attribute.values.count; ++idx) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(attributeIndexPath.row + idx) inSection:attributeIndexPath.section];
            [updatedIndexPaths addObject:indexPath];
        }

        [self.tableView reloadRowsAtIndexPaths:updatedIndexPaths withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (BOOL)isAttributeValueSelected:(MITMobiusAttributeValue*)value
{
    __block BOOL result = NO;

    [self.query.options enumerateObjectsUsingBlock:^(MITMobiusSearchOption *option, NSUInteger idx, BOOL *stop) {
        if ([option.attribute isEqual:value.attribute]) {
            result = [option.values containsObject:value];
            (*stop) = result;
        }
    }];

    return result;
}

@end