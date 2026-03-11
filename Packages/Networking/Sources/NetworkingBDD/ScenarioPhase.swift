import NetworkingRuntime
import NetworkingTesting
import Foundation

// MARK: - Scenario Phase (Phantom Types)

/// Phantom types representing the phases of scenario construction.
///
/// These types enforce at compile time that scenarios follow the
/// correct Given-When-Then ordering. You cannot call `.when()` before
/// `.given()`, or `.then()` before `.when()`.
///
/// ## Type Safety
///
/// ```swift
/// // This compiles - correct order
/// scenario("Test")
///   .given { MockResponse(...) }
///   .when { Request(...) }
///   .then { StatusIs(.ok) }
///
/// // This won't compile - wrong order
/// scenario("Test")
///   .when { Request(...) }  // Error: 'when' is not available on Initial phase
///   .given { ... }
/// ```
///
/// ## Implementation
///
/// The phantom types are uninhabited (cannot be instantiated).
/// They exist only at the type level to constrain method availability.
public enum ScenarioPhase {
  /// Initial phase before any steps are defined.
  ///
  /// In this phase, only `.given()` is available.
  public enum Initial: ScenarioPhaseProtocol {
    public static var phaseName: BDDPhaseName { .initial }
    public static var phaseDescription: BDDDescriptionText {
      "Define Given steps to set up preconditions"
    }
  }

  /// Phase after Given steps are defined.
  ///
  /// In this phase, only `.when()` is available.
  public enum GivenDefined: ScenarioPhaseProtocol {
    public static var phaseName: BDDPhaseName { .givenDefined }
    public static var phaseDescription: BDDDescriptionText {
      "Define When steps to perform actions"
    }
  }

  /// Phase after When steps are defined.
  ///
  /// In this phase, only `.then()` is available.
  public enum WhenDefined: ScenarioPhaseProtocol {
    public static var phaseName: BDDPhaseName { .whenDefined }
    public static var phaseDescription: BDDDescriptionText {
      "Define Then steps to verify outcomes"
    }
  }

  /// Final phase after Then steps are defined.
  ///
  /// In this phase, the scenario is complete and can be run.
  public enum Complete: ScenarioPhaseProtocol {
    public static var phaseName: BDDPhaseName { .complete }
    public static var phaseDescription: BDDDescriptionText {
      "Scenario is complete and ready to run"
    }
  }
}

// MARK: - Scenario Phase Protocol

/// Protocol for scenario phase phantom types.
///
/// This protocol allows generic constraints on scenario phases
/// and provides debugging information.
public protocol ScenarioPhaseProtocol {
  /// Human-readable name of this phase.
  static var phaseName: BDDPhaseName { get }
  /// Human-readable description of this phase.
  static var phaseDescription: BDDDescriptionText { get }
}

// MARK: - Phase Transition Types

/// Marker protocol for phases that can transition to GivenDefined.
///
/// Only `Initial` conforms to this, ensuring `.given()` is only
/// available at the start.
public protocol CanDefineGiven: ScenarioPhaseProtocol {}

extension ScenarioPhase.Initial: CanDefineGiven {}

/// Marker protocol for phases that can transition to WhenDefined.
///
/// Only `GivenDefined` conforms to this, ensuring `.when()` is only
/// available after `.given()`.
public protocol CanDefineWhen: ScenarioPhaseProtocol {}

extension ScenarioPhase.GivenDefined: CanDefineWhen {}

/// Marker protocol for phases that can transition to Complete.
///
/// Only `WhenDefined` conforms to this, ensuring `.then()` is only
/// available after `.when()`.
public protocol CanDefineThen: ScenarioPhaseProtocol {}

extension ScenarioPhase.WhenDefined: CanDefineThen {}

/// Marker protocol for phases that represent a runnable scenario.
///
/// Only `Complete` conforms to this, ensuring `.run()` is only
/// available after all steps are defined.
public protocol CanRun: ScenarioPhaseProtocol {}

extension ScenarioPhase.Complete: CanRun {}

// MARK: - Step Type Markers

/// Marker type for Given steps in type-safe builders.
public enum GivenStepType: StepTypeMarker {
  public static var stepName: BDDStepKeywordName { .given }
}

/// Marker type for When steps in type-safe builders.
public enum WhenStepType: StepTypeMarker {
  public static var stepName: BDDStepKeywordName { .when }
}

/// Marker type for Then steps in type-safe builders.
public enum ThenStepType: StepTypeMarker {
  public static var stepName: BDDStepKeywordName { .then }
}

/// Protocol for step type markers.
public protocol StepTypeMarker {
  /// Human-readable name of this step type.
  static var stepName: BDDStepKeywordName { get }
}

public extension BDDPhaseName {
  static let initial = Self(rawValue: "Initial")
  static let givenDefined = Self(rawValue: "GivenDefined")
  static let whenDefined = Self(rawValue: "WhenDefined")
  static let complete = Self(rawValue: "Complete")
}

public extension BDDStepKeywordName {
  static let given = Self(rawValue: "Given")
  static let when = Self(rawValue: "When")
  static let then = Self(rawValue: "Then")
}
