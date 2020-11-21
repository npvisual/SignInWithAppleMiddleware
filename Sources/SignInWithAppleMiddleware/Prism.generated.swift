// Generated using Sourcery 1.0.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

extension SIWAAction {
    public var getStatus: String? {
        get {
            guard case let .getStatus(associatedValue0) = self else { return nil }
            return (associatedValue0)
        }
        set {
            guard case .getStatus = self, let newValue = newValue else { return }
            self = .getStatus(newValue)
        }
    }

    public var isGetStatus: Bool {
        self.getStatus != nil
    }

    public var status: SIWAState? {
        get {
            guard case let .status(associatedValue0) = self else { return nil }
            return (associatedValue0)
        }
        set {
            guard case .status = self, let newValue = newValue else { return }
            self = .status(newValue)
        }
    }

    public var isStatus: Bool {
        self.status != nil
    }

    public var error: Error? {
        get {
            guard case let .error(associatedValue0) = self else { return nil }
            return (associatedValue0)
        }
        set {
            guard case .error = self, let newValue = newValue else { return }
            self = .error(newValue)
        }
    }

    public var isError: Bool {
        self.error != nil
    }

}
