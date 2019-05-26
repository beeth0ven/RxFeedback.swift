//
//  DriverSystem.swift
//  RxFeedback
//
//  Created by Beeth0ven on 2019/5/25.
//  Copyright © 2019 Krunoslav Zaher. All rights reserved.
//

import RxCocoa
import RxSwift

public struct DriverSystem<State, Event> {
    public typealias Feedback = Driver<Any>.Feedback<State, Event>
    public typealias System = ([Feedback]) -> Driver<State>
    
    public typealias Raw = ObservableSystem<State, Event>
    private typealias RawFeedback = Raw.Feedback
    private typealias RawSystem = Raw.System
    

    private let raw: Raw
    
    private init(_ raw: Raw) {
        self.raw = raw
    }
}

extension DriverSystem {

    public var system: System {
        return type(of: self).transformToDriverSystem(from: raw.system)
    }
}

extension DriverSystem {
    
    public func apply(_ rawMiddleware: @escaping (Raw) -> Raw) -> DriverSystem<State, Event> {
        let newRaw: Raw = rawMiddleware(self.raw)
        return DriverSystem(newRaw)
    }
    
    public func concat(_ newFeedback: @escaping Feedback) -> DriverSystem<State, Event> {
        let rawFeedback: RawFeedback = { state in
            newFeedback(state.asDriver(onErrorDriveWith: Driver<State>.empty())).asObservable()
        }
        return apply { raw in raw.concat(rawFeedback) }
    }
}

extension DriverSystem {
    
    public static func create(
        initialState: State,
        reduce: @escaping (State, Event) -> State
        ) -> DriverSystem<State, Event> {
        let raw = Raw.create(
            initialState:
            initialState,
            reduce: reduce,
            scheduler: DriverSharingStrategy.scheduler
        )
        return DriverSystem(raw)
    }
    
    public func reacted<Request: Equatable>(
        request: @escaping (State) -> Request?,
        effects: @escaping (Request) -> Signal<Event>
        ) -> DriverSystem<State, Event> {

        let _effects: (Request) -> Observable<Event> = { request in
            effects(request).asObservable()
        }
        
        return apply { raw in raw.reacted(request: request, effects: _effects) }
    }
    
    public func reacted<Request: Equatable>(
        requests: @escaping (State) -> Set<Request>,
        effects: @escaping (Request) -> Signal<Event>
        ) -> DriverSystem<State, Event> {
        
        let _effects: (Request) -> Observable<Event> = { request in
            effects(request).asObservable()
        }
        
        return apply { raw in raw.reacted(requests: requests, effects: _effects) }
    }
    
    public func binded<WeakOwner: AnyObject>(
        _ owner: WeakOwner,
        _ bindings: @escaping (WeakOwner, Driver<State>) -> (Bindings<Event>)
        ) -> DriverSystem<State, Event> {
        
        let _bindings: (WeakOwner, ObservableSchedulerContext<State>) -> (Bindings<Event>) = { me, state in
            bindings(me, state.asDriver(onErrorDriveWith: Driver<State>.empty()))
        }
        
        return apply { raw in raw.binded(owner, _bindings) }
    }
    
//    public func embedSystem<Request: Equatable, InnerState, InnerEvent>(
//        request: @escaping (State) -> Request?,
//        innerSystem: @escaping (Request) -> DriverSystem<InnerState, InnerEvent>,
//        mapOutterStateToInnerEvents: [(Driver<State>) -> Signal<InnerEvent>],
//        mapInnerStateToOutterEvents: [(Driver<InnerState>) -> Signal<Event>]
//        ) -> DriverSystem<State, Event>  {
//
//        let _innerSystem: (Request) -> ObservableSystem<InnerState, InnerEvent> = { request in
//            innerSystem(request).raw
//        }
//
//        let _mapOutterStateToInnerEvents: [(Observable<State>) -> Observable<InnerEvent>] = mapOutterStateToInnerEvents.map { map in  { state in
//            map(state.asDriver(onErrorDriveWith: Driver<State>.empty())).asObservable()
//        }}
//
//        let _mapInnerStateToOutterEvents: [(Observable<InnerState>) -> Observable<Event>] = mapInnerStateToOutterEvents.map { map in { state in
//            map(state.asDriver(onErrorDriveWith: Driver<InnerState>.empty())).asObservable()
//        }}
//
//        return composeRaw { raw in
//            raw.embedSystem(
//                request: request,
//                innerSystem: _innerSystem,
//                mapOutterStateToInnerEvents: _mapOutterStateToInnerEvents,
//                mapInnerStateToOutterEvents: _mapInnerStateToOutterEvents
//            )
//        }
//    }
    
//    public func debuged() -> DriverSystem<State, Event> {
//        return composeRaw { raw in raw.debuged() }
//    }

}

extension DriverSystem {
    
    private static func transformToDriverSystem(from rawSystem: @escaping RawSystem) -> System {
        return { feedback -> Driver<State> in
            let rawFeedback: [RawFeedback] = feedback.map { feedback in { state in
                let driveState = state.source.asDriver(onErrorDriveWith: Driver<State>.empty())
                return feedback(driveState).asObservable()
            }}
            return rawSystem(rawFeedback)
                .asDriver(onErrorDriveWith: Driver<State>.empty())
        }
    }
}
