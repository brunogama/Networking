import Foundation

public enum MockRequestPathTag: Sendable {}
public enum MockJSONResponseFlagTag: Sendable {}

public enum RequestRecordingEnabledFlagTag: Sendable {}
public enum MockVerificationCountTag: Sendable {}
public enum MockUnixTimestampTag: Sendable {}
public enum MockTimeAdjustmentTag: Sendable {}
public enum MockRequestIndexTag: Sendable {}
public enum MockResponseIndexTag: Sendable {}
public enum MockContextIdentifierTag: Sendable {}
public enum MockURLPatternTag: Sendable {}
public enum MockPredicateMatchFlagTag: Sendable {}
public enum MockResponseDelayTag: Sendable {}
public enum ExpectationDescriptionTextTag: Sendable {}
public enum ExpectationFulfillmentFlagTag: Sendable {}
public enum TestingSupportEnabledFlagTag: Sendable {}
public enum TestingToolNameTag: Sendable {}
public enum TestingUtilitiesVersionTag: Sendable {}

public typealias MockRequestPath = BoundaryString<MockRequestPathTag>
public typealias MockJSONResponseFlag = BoundaryBool<MockJSONResponseFlagTag>

public typealias RequestRecordingEnabledFlag = BoundaryBool<RequestRecordingEnabledFlagTag>
public typealias MockVerificationCount = BoundaryInt<MockVerificationCountTag>
public typealias MockUnixTimestamp = BoundaryDuration<MockUnixTimestampTag>
public typealias MockTimeAdjustment = BoundaryDuration<MockTimeAdjustmentTag>
public typealias MockRequestIndex = BoundaryInt<MockRequestIndexTag>
public typealias MockResponseIndex = BoundaryInt<MockResponseIndexTag>
public typealias MockContextIdentifier = BoundaryUUID<MockContextIdentifierTag>
public typealias MockURLPattern = BoundaryString<MockURLPatternTag>
public typealias MockPredicateMatchFlag = BoundaryBool<MockPredicateMatchFlagTag>
public typealias MockResponseDelay = BoundaryDuration<MockResponseDelayTag>
public typealias ExpectationDescriptionText = BoundaryString<ExpectationDescriptionTextTag>
public typealias ExpectationFulfillmentFlag = BoundaryBool<ExpectationFulfillmentFlagTag>
public typealias TestingSupportEnabledFlag = BoundaryBool<TestingSupportEnabledFlagTag>
public typealias TestingToolName = BoundaryString<TestingToolNameTag>
public typealias TestingUtilitiesVersion = BoundaryString<TestingUtilitiesVersionTag>
