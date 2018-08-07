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

public final class DirtyableValue<Value> {
  
  public typealias InitializeValueBlock = () throws -> Value
  
  public init(initializer: @escaping InitializeValueBlock) {
    self.initializer = initializer
  }
  
  private let initializer: InitializeValueBlock
  private(set) var dirty = false
  private var _value: Value?
  
  public func value() throws -> Value {
    if let value = _value { return value }
    let value = try initializer()
    dirty = false
    return value
  }
  
  public func setValue(_ value: Value) {
    self._value = value
    dirty = true
  }
  
  public func clean() -> Value? {
    if dirty {
      dirty = false
      return _value
    } else {
      return nil
    }
  }
}

