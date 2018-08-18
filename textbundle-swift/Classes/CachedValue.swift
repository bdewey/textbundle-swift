//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

import Foundation

/// Coordination protocol with stable storage.
public protocol StableStorage: class {
  associatedtype Value
  
  /// Supplies the stable storage version of the value.
  func dirtyableValueInitialValue() throws -> Value
  
  /// Lets stable storage know that the in-memory copy has changed.
  func dirtyableValueDidChange()
}

/// Holds an mutable in-memory copy of data that is in stable storage, and tracks whether
/// the in-memory copy has changed since being in stable storage ("dirty").
public final class CachedValue<Storage: StableStorage>: Publisher {
  
  public init() { }
  
  /// Weak reference back to stable storage.
  public weak var storage: Storage?
  
  /// Flag indicating if the in-memory copy has changed.
  private(set) var dirty = false
  
  /// In-memory copy of the value.
  private var _value: Result<Storage.Value>?
  
  private let publisher = SimplePublisher<Storage.Value>()
  
  public func subscribe(_ block: @escaping (Result<Storage.Value>) -> Void) -> AnySubscription {
    block(currentValue)
    return publisher.subscribe(block)
  }
  
  public func removeSubscription(_ subscription: AnySubscription) {
    publisher.removeSubscription(subscription)
  }
  
  public func invalidate() {
    assert(!dirty)
    _value = nil
    if publisher.hasActiveSubscribers {
      publisher.publishResult(currentValue)
    }
  }
  
  /// Returns the in-memory copy of the value.
  public var currentValue: Result<Storage.Value> {
    if let value = _value { return value }
    do {
      let value = try storage!.dirtyableValueInitialValue()
      dirty = false
      _value = .success(value)
    } catch {
      _value = .failure(error)
    }
    return _value!
  }
  
  /// Changes the in-memory copy of the value.
  public func setValue(_ value: Storage.Value) {
    self._value = .success(value)
    publisher.publishValue(value)
    dirty = true
    storage?.dirtyableValueDidChange()
  }
  
  /// If the in-memory copy is dirty, returns that value and sets its state to clean.
  ///
  /// - note: This is intended to only be called by the stable storage when writing the
  ///         in-memory copy.
  public func clean() -> Storage.Value? {
    switch (dirty, _value) {
    case (true, .some(.success(let value))):
      dirty = false
      return value
    default:
      return nil
    }
  }
}

