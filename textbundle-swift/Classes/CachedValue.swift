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

/// Can persistently store values.
public protocol ValueStorage {
  associatedtype Value
  
  /// Returns a value from persistent storage.
  func readValue() throws -> Value
  
  /// Writes a value to persistent storage.
  func writeValue(_ value: Value) throws
}

/// Maintains an in-memory copy of a value kept in persistent storage.
public struct CachedValue<Value, Storage: ValueStorage> where Storage.Value == Value {
  
  /// Persistent storage for the value.
  private let storage: Storage
  
  /// Flag: `true` if the in-memory copy is modified from the persistent copy.
  private var dirty = false
  
  /// The in-memory copy of the persistent value.
  private var _value: Value?
  
  /// Initialier.
  /// - parameter storage: The persistent storage that contains the value.
  public init(storage: Storage) {
    self.storage = storage
  }
  
  /// Returns the in-memory copy of the value, reading it from persistent storage if necessary.
  public mutating func value() throws -> Value {
    if let value = _value { return value }
    let value = try storage.readValue()
    _value = value
    dirty = false
    return value
  }
  
  /// Sets the in-memory copy of the value. Call `flush()` to write the in-memory copy to
  /// persistent storage.
  ///
  /// - parameter value: The updated value to store in memory.
  public mutating func setValue(_ value: Value) {
    _value = value
    dirty = true
  }
  
  /// Writes the in-memory copy of the value to persistent storage.
  public mutating func flush() throws {
    if dirty, let value = _value {
      try storage.writeValue(value)
      dirty = false
    }
  }
  
  /// Discards the in-memory copy of the value.
  public mutating func clear() {
    dirty = false
    _value = nil
  }
}
