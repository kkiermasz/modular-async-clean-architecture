//  Copyright © 2022 Jakub Kiermasz. All rights reserved.

import Combine
import UIKit

extension UINavigationController {
    // MARK: - Type Aliases

    public typealias ShowEvent = (viewController: UIViewController, animated: Bool)

    // MARK: - Getters

    public var didShow: AnyPublisher<UIViewController, Never> {
        let foo = didShowProxyEvent
            .map { (showedViewController, _) -> Optional<UIViewController> in
                return showedViewController
            }
            .eraseToAnyPublisher() as AnyPublisher<UIViewController?, Error>

        return foo
            .replaceError(with: nil)
            .filter { suspect in suspect != nil }
            .ignoreNil()
            .eraseToAnyPublisher()
    }

    private var delegateProxy: UINavigationControllerDelegateProxy { .createDelegateProxy(for: self) }

    private var didShowProxyEvent: AnyPublisher<ShowEvent, Error> {
        delegateProxy
            .methodInvoked(#selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:)))
            .tryMap { argument in
                let viewController: UIViewController = try castOrThrow(argument[1])
                let animated: Bool = try castOrThrow(argument[2])
                return ShowEvent(viewController: viewController, animated: animated)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Public

    public func didShow(_ viewController: UIViewController) -> AnyPublisher<Void, Never> {
        didShowProxyEvent
            .map { showedViewController, _ in showedViewController === viewController }
            .replaceError(with: false)
            .filter { isCurrent in isCurrent }
            .map { _ in () }
            .eraseToAnyPublisher()
    }


}

private class UINavigationControllerDelegateProxy: DelegateProxy, UINavigationControllerDelegate, DelegateProxyType {
    func setDelegate(to object: UINavigationController) {
        object.delegate = self
    }
}


public protocol OptionalType {
    associatedtype Wrapped

    var optional: Wrapped? { get }
}

extension Optional: OptionalType {
    public var optional: Wrapped? { self }
}

extension Publisher where Output: OptionalType {
    public func ignoreNil() -> AnyPublisher<Output.Wrapped, Failure> {
        flatMap { output -> AnyPublisher<Output.Wrapped, Failure> in
            guard let output = output.optional
            else { return Empty<Output.Wrapped, Failure>(completeImmediately: false).eraseToAnyPublisher() }
            return Just(output).setFailureType(to: Failure.self).eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }
}
