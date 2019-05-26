//
//  ObservableSyatem.swift
//  Example
//
//  Created by Beeth0ven on 2019/5/25.
//  Copyright © 2019 Krunoslav Zaher. All rights reserved.
//

import RxCocoa
import RxSwift

public struct ObservableSystem<State, Event> {
    public typealias Feedback = Observable<Any>.Feedback<State, Event>
    public typealias System = ([Feedback]) -> Observable<State>
    
    public let system: System
    
    private init(_ system: @escaping System) {
        self.system = system
    }
}

extension ObservableSystem {
    
    public typealias Middleware = (@escaping System) -> System
    
    public func apply(_ middleware: @escaping Middleware) -> ObservableSystem<State, Event> {
        let newSystem: System = middleware(self.system)
        return ObservableSystem(newSystem)
    }
    
    public func concat(_ newFeedback: @escaping Feedback) -> ObservableSystem<State, Event> {
        return apply { source in { feedback in source([newFeedback] + feedback) }}
    }
}

extension ObservableSystem {
    
    public static func create(
        initialState: State,
        reduce: @escaping (State, Event) -> State,
        scheduler: ImmediateSchedulerType
        ) -> ObservableSystem<State, Event> {
        return ObservableSystem { feedback in
            return Observable<Any>.system(
                initialState: initialState,
                reduce: reduce,
                scheduler: scheduler,
                feedback: feedback
            )
        }
    }
    
    public func reacted<Request: Equatable>(
        request: @escaping (State) -> Request?,
        effects: @escaping (Request) -> Observable<Event>
        ) -> ObservableSystem<State, Event> {
        let newFeedback: Feedback = react(request: request, effects: effects)
        return concat(newFeedback)
    }
    
    public func reacted<Request: Equatable>(
        requests: @escaping (State) -> Set<Request>,
        effects: @escaping (Request) -> Observable<Event>
        ) -> ObservableSystem<State, Event> {
        let newFeedback: Feedback = react(requests: requests, effects: effects)
        return concat(newFeedback)
    }
    
    
    public func binded<WeakOwner: AnyObject>(
        _ owner: WeakOwner,
        _ bindings: @escaping (WeakOwner, ObservableSchedulerContext<State>) -> (Bindings<Event>)
        ) -> ObservableSystem<State, Event> {
        let newFeedback: Feedback = bind(owner, bindings)
        return concat(newFeedback)
    }
    
//    public func embedSystem<Request: Equatable, InnerState, InnerEvent>(
//        request: @escaping (State) -> Request?,
//        innerSystem: @escaping (Request) -> ObservableSystem<InnerState, InnerEvent>,
//        mapOutterStateToInnerEvents: [(Observable<State>) -> Observable<InnerEvent>],
//        mapInnerStateToOutterEvents: [(Observable<InnerState>) -> Observable<Event>]
//        ) -> ObservableSystem<State, Event>  {
//
//        let newFeedback: Feedback = { state in
//
//            let feedback: Feedback = react(request: request) { request in
//                let innerEvents: [Observable<InnerEvent>] = mapOutterStateToInnerEvents.map { map in map(state.source) }
//                let innerState: Observable<InnerState> = innerSystem(request)
//                    .system([{ _ in Observable.merge(innerEvents) }])
//                let outterEvents: [Observable<Event>] = mapInnerStateToOutterEvents.map { map in map(innerState) }
//                return Observable.merge(outterEvents)
//            }
//
//            return feedback(state)
//        }
//        return concat(newFeedback)
//    }
    
//    public func debuged() -> ObservableSystem<State, Event> {
//        return compose { source in { feedback in
//            let debugedFeedback: [Feedback] = feedback.map { feedback in { state in
//                return feedback(state).debug()
//            }}
//            return source(debugedFeedback).debug()
//        }}
//    }
}


