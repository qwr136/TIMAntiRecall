#import <XCTest/XCTest.h>

// External AUT: the generated Xcode target is only a runner host. These actions
// must go through XCTest event synthesis, never app hooks or recognizer calls.
@interface TIMAntiRecallReplayTouchUITests : XCTestCase
@property(nonatomic, strong) XCUIApplication *replayApp;
@end

@implementation TIMAntiRecallReplayTouchUITests

- (XCUIElement *)element:(NSString *)identifier {
    XCUIElementQuery *query = [self.replayApp descendantsMatchingType:XCUIElementTypeAny];
    query = [query matchingIdentifier:identifier];
    XCUIElement *element = query.firstMatch;
    XCTAssertTrue([element waitForExistenceWithTimeout:10.0], @"Missing %@", identifier);
    XCTAssertEqual(query.count, (NSUInteger)1, @"Ambiguous identifier %@", identifier);
    return element;
}

- (NSInteger)count:(XCUIElement *)element {
    NSString *label = element.label;
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    XCTAssertTrue(label.length > 0 && [label rangeOfCharacterFromSet:invalid].location == NSNotFound,
                  @"%@ must expose a nonnegative integer in accessibilityLabel, got %@", element.identifier, label);
    NSScanner *scanner = [NSScanner scannerWithString:label];
    NSInteger result = -1;
    XCTAssertTrue([scanner scanInteger:&result] && scanner.isAtEnd && result >= 0,
                  @"Counter overflow or invalid integer: %@", label);
    return result;
}

- (void)expectCount:(XCUIElement *)element value:(NSInteger)value {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"exists == YES AND label == %@", @(value).stringValue];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:predicate object:element];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:5.0], XCTWaiterResultCompleted,
                   @"%@ did not become %@; actual %@", element.identifier, @(value), element.label);
}

- (void)expectSend:(NSInteger)send native:(NSInteger)native stableFor:(NSTimeInterval)seconds {
    XCUIElement *sendElement = [self element:@"replay-send-count"];
    XCUIElement *nativeElement = [self element:@"replay-native-count"];
    XCTAssertEqual([self count:sendElement], send);
    XCTAssertEqual([self count:nativeElement], native);
    NSPredicate *changed = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        (void)object; (void)bindings;
        return !sendElement.exists || !nativeElement.exists ||
            ![sendElement.label isEqualToString:@(send).stringValue] ||
            ![nativeElement.label isEqualToString:@(native).stringValue];
    }];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:changed object:self.replayApp];
    expectation.inverted = YES;
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:seconds], XCTWaiterResultCompleted,
                   @"Unexpected send/native counter change during %.1fs observation", seconds);
}

- (XCUIElement *)touchArea:(NSString *)identifier {
    XCUIElement *element = [self element:identifier];
    XCTAssertTrue(element.hittable, @"%@ must be visible and hittable", identifier);
    XCTAssertGreaterThanOrEqual(CGRectGetWidth(element.frame), 24.0);
    XCTAssertGreaterThanOrEqual(CGRectGetHeight(element.frame), 24.0);
    return element;
}

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    self.replayApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.minis.timantirecall.inlinetests"];
    [self launchFreshScene];
}

- (void)launchFreshScene {
    [self.replayApp terminate];
    self.replayApp.launchArguments = @[@"--timantirecall-replay-touch-only"];
    [self.replayApp launch];
    XCUIElement *status = [self element:@"replay-status"];
    XCTNSPredicateExpectation *ready = [[XCTNSPredicateExpectation alloc]
        initWithPredicate:[NSPredicate predicateWithFormat:@"label == 'ready'"] object:status];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[ready] timeout:15.0], XCTWaiterResultCompleted,
                   @"Touch-only scene never became ready; actual %@", status.label);
    (void)[self count:[self element:@"replay-send-count"]];
    (void)[self count:[self element:@"replay-native-count"]];
}

- (void)tearDown {
    if (self.replayApp) {
        XCTAttachment *screen = [XCTAttachment attachmentWithScreenshot:self.replayApp.screenshot];
        screen.name = self.name;
        screen.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:screen];
        [self.replayApp terminate];
    }
    [super tearDown];
}

- (void)testSingleTapIncomingDoesNotSend {
    NSInteger send = [self count:[self element:@"replay-send-count"]];
    NSInteger native = [self count:[self element:@"replay-native-count"]];
    [[self touchArea:@"replay-incoming-area"] tap];
    [self expectSend:send native:native stableFor:2.0];
}

- (void)testDoubleTapIncomingSendsExactlyOnce {
    NSInteger send = [self count:[self element:@"replay-send-count"]];
    NSInteger native = [self count:[self element:@"replay-native-count"]];
    [[self touchArea:@"replay-incoming-area"] doubleTap];
    [self expectCount:[self element:@"replay-send-count"] value:send + 1];
    [self expectSend:send + 1 native:native stableFor:2.0];
}

- (void)testDoubleTapOutgoingSendsExactlyOnce {
    NSInteger send = [self count:[self element:@"replay-send-count"]];
    NSInteger native = [self count:[self element:@"replay-native-count"]];
    [[self touchArea:@"replay-outgoing-area"] doubleTap];
    [self expectCount:[self element:@"replay-send-count"] value:send + 1];
    [self expectSend:send + 1 native:native stableFor:2.0];
}

- (void)testDoubleTapNativeTextPreservesNativeGesture {
    NSInteger send = [self count:[self element:@"replay-send-count"]];
    NSInteger native = [self count:[self element:@"replay-native-count"]];
    [[self touchArea:@"replay-native-text"] doubleTap];
    [self expectCount:[self element:@"replay-native-count"] value:native + 1];
    [self expectSend:send native:native + 1 stableFor:2.0];
}

- (void)testLongPressDoesNotSend {
    NSInteger send = [self count:[self element:@"replay-send-count"]];
    NSInteger native = [self count:[self element:@"replay-native-count"]];
    for (NSString *identifier in @[@"replay-incoming-area", @"replay-outgoing-area"]) {
        [[self touchArea:identifier] pressForDuration:1.2];
        [self expectSend:send native:native stableFor:2.0];
    }
}

- (void)testDragDoesNotSend {
    for (NSString *identifier in @[@"replay-incoming-area", @"replay-outgoing-area"]) {
        // Reset scrolling before each direction; do not enlarge the host hit area.
        [self launchFreshScene];
        NSInteger send = [self count:[self element:@"replay-send-count"]];
        NSInteger native = [self count:[self element:@"replay-native-count"]];
        XCUIElement *area = [self touchArea:identifier];
        XCUICoordinate *start = [area coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.5)];
        CGFloat dy = CGRectGetMaxY(self.replayApp.frame) - start.screenPoint.y > 90.0 ? 80.0 : -80.0;
        XCUICoordinate *end = [start coordinateWithOffset:CGVectorMake(0.0, dy)];
        XCTAssertTrue(CGRectContainsPoint(self.replayApp.frame, end.screenPoint), @"Drag endpoint is offscreen");
        [start pressForDuration:0.05 thenDragToCoordinate:end];
        [self expectSend:send native:native stableFor:2.0];
    }
}
@end
