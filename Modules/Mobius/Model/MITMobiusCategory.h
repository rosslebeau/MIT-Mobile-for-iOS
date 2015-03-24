#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "MITMobiusObject.h"

@class MITMobiusResource, MITMobiusTemplate, MITMobiusType;

@interface MITMobiusCategory : MITMobiusObject

@property (nonatomic, retain) NSSet *resources;
@property (nonatomic, retain) MITMobiusTemplate *template;
@property (nonatomic, retain) NSSet *types;
@property (nonatomic, retain) NSString *templateIdentifier;
@end

@interface MITMobiusCategory (CoreDataGeneratedAccessors)

- (void)addResourcesObject:(MITMobiusResource *)value;
- (void)removeResourcesObject:(MITMobiusResource *)value;
- (void)addResources:(NSSet *)values;
- (void)removeResources:(NSSet *)values;

- (void)addTypesObject:(MITMobiusType *)value;
- (void)removeTypesObject:(MITMobiusType *)value;
- (void)addTypes:(NSSet *)values;
- (void)removeTypes:(NSSet *)values;

@end