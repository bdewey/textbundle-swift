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

public protocol DirtyableValueDelegate: class {
  associatedtype Value
  
  func dirtyableValueInitialValue() throws -> Value
  func dirtyableValueDidChange()
}

public final class DirtyableValue<Delegate: DirtyableValueDelegate> {
  
  public init() { }

  public weak var delegate: Delegate?
  
  // Hold a strong reference to the delegate while we have dirty data to make sure
  // the delegate doesn't go away before writing.
  private(set) var dirty = false
  private var _value: Delegate.Value?
  
  public func value() throws -> Delegate.Value {
    if let value = _value { return value }
    let value = try delegate!.dirtyableValueInitialValue()
    dirty = false
    return value
  }
  
  public func setValue(_ value: Delegate.Value) {
    self._value = value
    dirty = true
    delegate?.dirtyableValueDidChange()
  }
  
  public func clean() -> Delegate.Value? {
    if dirty {
      dirty = false
      return _value
    } else {
      return nil
    }
  }
}

