import Foundation
import os.log
import AuthenticationServices
import Combine

import SwiftRex

// MARK: - ACTIONS
//sourcery: Prism, imports = ["AuthenticationServices"]
public enum SIWAAction {
    case getStatus(String)
    case authenticated(ASAuthorizationAppleIDCredential, String, String)
    case status(SIWAState.AuthenticationState)
    case error(Error)
}

// MARK: - STATE
public struct SIWAState: Equatable {
    public var authState: AuthenticationState = .undefined
    public var identityToken: Data? = nil
    public var authorizationCode: Data? = nil
    public var state: String? = nil
    public var user: String? = nil
    
    public var fullName: PersonNameComponents? = nil
    public var email: String? = nil
    public var realUserStatus: RealUserStatus? = nil
    
    public enum AuthenticationState: Int, Equatable {
        case authenticated
        case loggedOut
        case undefined
    }
    
    public enum RealUserStatus: Int, Equatable {
        case unsupported = 0, unknown, real
    }
    
    public static let empty: SIWAState = .init()
}

// MARK: - ERROR
public enum SIWAError: Error {
    case UnknownCredentialState
}

// MARK: - PROTOCOL
public protocol SIWAProvider: ASAuthorizationProvider {
    func getCredentialState(userID: String) -> AnyPublisher<SIWAState.AuthenticationState, SIWAError>
}

// MARK: - MIDDLEWARE
public final class SignInWithAppleMiddleware: Middleware {
    public typealias InputActionType = SIWAAction
    public typealias OutputActionType = SIWAAction
    public typealias StateType = SIWAState
    
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "SignInWithAppleMiddleware")

    private let provider: SIWAProvider
    private var getState: GetState<StateType>?
    private var output: AnyActionHandler<SIWAAction>?
    
    private var credentialStatusCancellable: AnyCancellable?
    
    public init(provider: SIWAProvider) {
        self.provider = provider
    }
    
    public func receiveContext(getState: @escaping GetState<SIWAState>, output: AnyActionHandler<SIWAAction>) {
        self.getState = getState
        self.output = output
    }
    
    public func handle(action: SIWAAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        switch action {
            case let .getStatus(userId):
                credentialStatusCancellable = provider
                    .getCredentialState(userID: userId)
                    .sink { (completion: Subscribers.Completion<SIWAError>) in
                        if case Subscribers.Completion.failure = completion {
                            self.output?.dispatch(.error(SIWAError.UnknownCredentialState))
                        }
                    } receiveValue: { status in
                        os_log(
                            "Credential status received : %s...",
                            log: SignInWithAppleMiddleware.logger,
                            type: .debug,
                            String(describing: status)
                        )
                        self.output?.dispatch(.status(status))
                    }
            default: break
        }
    }
}

extension ASAuthorizationAppleIDProvider: SIWAProvider {
    
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "SIWAProviderImpl")

    public func getCredentialState(userID: String) -> AnyPublisher<SIWAState.AuthenticationState, SIWAError> {
        return Future() { promise in
            self.getCredentialState(
                forUserID: userID,
                completion: { state, error in
                    var result: SIWAState.AuthenticationState
                    os_log("Credential state for : %s",
                           log: ASAuthorizationAppleIDProvider.logger,
                           type: .debug,
                           userID)
                    if error != nil {
                        return promise(.failure(.UnknownCredentialState))
                    } else {
                        switch state {
                            case .authorized: result = .authenticated
                            case .notFound, .transferred: result = .undefined
                            case .revoked: result = .loggedOut
                            @unknown default:
                                return promise(.failure(.UnknownCredentialState))
                        }
                        return promise(.success(result))
                    }
                }
            )
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - REDUCER
extension Reducer where ActionType == SIWAAction, StateType == SIWAState {
    public static let swa = Reducer { action, state in
        var state = state
        switch action {
            case let .status(result):
                state.authState = result
            case let .authenticated(cred, _, _):
                state.authState = .authenticated
                state.identityToken = cred.identityToken
                state.authorizationCode = cred.authorizationCode
                state.state = cred.state
                state.user = cred.user
                state.fullName = cred.fullName
                state.email = cred.email
                state.realUserStatus = SIWAState.RealUserStatus.init(rawValue: cred.realUserStatus.rawValue)
            case .getStatus:
                break
            case .error:
                state = .empty
        }
        return state
    }
}
