import Foundation

/// A duration in seconds distinguished by its domain.
public typealias BoundaryDuration<Tag> = Tagged<Tag, TimeInterval>
