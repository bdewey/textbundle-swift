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

public protocol DocumentPropertyStorage {
  associatedtype Value

  func read(from document: TextBundleDocument) throws -> Value
  func writeValue(_ value: Value, to document: TextBundleDocument) throws
}

/// Holds an mutable in-memory copy of data that is in stable storage, and tracks whether
/// the in-memory copy has changed since being in stable storage ("dirty").
public final class DocumentProperty<Storage: DocumentPropertyStorage>: TextBundleDocumentSaveListener {

  public var textBundleListenerHasChanges: TextBundleDocumentSaveListener.ChangeBlock?

  public func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    if let value = clean() {
      try storage.writeValue(value, to: textBundleDocument)
    }
  }

  public final func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    let result = Result<Storage.Value> { try self.storage.read(from: textBundleDocument) }
    setDocumentResult(result)
  }


  private let storage: Storage
  public typealias ValueWithSource = DocumentValueWithSource<Storage.Value>

  public init(document: TextBundleDocument, storage: Storage) {
    self.storage = storage
    let initialResult = Result<Storage.Value> { try storage.read(from: document) }
    self.currentValueWithSource = initialResult.flatMap { DocumentValueWithSource(source: .document, value: $0 )}
  }
  
  private let (publishingEndpoint, publisher) = Publisher<ValueWithSource>.create()

  /// Returns the in-memory copy of the value.
  public var currentResult: Result<Storage.Value> {
    return currentValueWithSource.flatMap { $0.value }
  }

  private var currentValueWithSource: Result<ValueWithSource>
  
  /// Changes the in-memory copy of the value.
  public func setValue(_ value: Storage.Value) {
    setResult(.success(value))
  }

  public func changeValue(_ mutation: (Storage.Value) -> Storage.Value) {
    setResult(currentResult.flatMap(mutation))
  }

  internal func setDocumentResult(_ result: Result<Storage.Value>) {
    let newResult = result.flatMap { DocumentValueWithSource(source: .document, value: $0) }
    currentValueWithSource = newResult
    publishingEndpoint(newResult)
  }
  
  private func setResult(_ result: Result<Storage.Value>) {
    let newResult = result.flatMap { DocumentValueWithSource(source: .memory, value: $0) }
    currentValueWithSource = newResult
    publishingEndpoint(newResult)
    textBundleListenerHasChanges?()
  }

  /// If the in-memory copy is dirty, returns that value and sets its state to clean.
  ///
  /// - note: This is intended to only be called by the stable storage when writing the
  ///         in-memory copy.
  public func clean() -> Storage.Value? {
    var returnValue: Storage.Value? = nil
    currentValueWithSource = currentValueWithSource.flatMap({ (valueWithSource) -> ValueWithSource in
      switch valueWithSource.source {
      case .document:
        return valueWithSource
      case .memory:
        returnValue = valueWithSource.value
        return valueWithSource.settingSource(.document)
      }
    })
    return returnValue
  }
}

extension DocumentProperty: CustomReflectable {
  public var customMirror: Mirror {
    return Mirror(
      self,
      children: [
        "currentValueWithSource": String(describing: currentValueWithSource),
        "subscribers": publisher,
      ],
      displayStyle: .class,
      ancestorRepresentation: .suppressed
    )
  }
}

extension DocumentProperty {
  public func subscribe(_ block: @escaping (Result<ValueWithSource>) -> Void) -> AnySubscription {
    block(currentValueWithSource)
    return publisher.subscribe(block)
  }

  public func removeSubscription(_ subscription: AnySubscription) {
    publisher.removeSubscription(subscription)
  }
}
