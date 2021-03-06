#import "MITShuttlePrediction.h"
#import "MITShuttlePredictionList.h"
#import "MITShuttleStop.h"
#import "MITShuttleVehicle.h"


@implementation MITShuttlePrediction

@dynamic seconds;
@dynamic stopId;
@dynamic routeId;
@dynamic timestamp;
@dynamic vehicleId;
@dynamic list;

+ (RKMapping *)objectMapping
{
    RKEntityMapping *mapping = [[RKEntityMapping alloc] initWithEntity:[self entityDescription]];
    [mapping addAttributeMappingsFromDictionary:@{@"vehicle_id": @"vehicleId",
                                                  @"timestamp": @"timestamp",
                                                  @"seconds": @"seconds"}];
    [mapping setIdentificationAttributes:@[@"vehicleId", @"timestamp", @"stopId", @"routeId"]];
    return mapping;
}

+ (RKMapping *)objectMappingFromPredictionList
{
    RKEntityMapping *mapping = (RKEntityMapping *)[self objectMapping];
    [mapping addAttributeMappingsFromDictionary:@{@"@parent.stop_id": @"stopId"}];
    [mapping addAttributeMappingsFromDictionary:@{@"@parent.route_id": @"routeId"}];
    return mapping;
}

@end
