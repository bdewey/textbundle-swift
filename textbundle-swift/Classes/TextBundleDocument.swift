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

import UIKit

extension FileWrapper {
  
  func replaceFileWrapper(_ wrapper: FileWrapper, key: String) {
    precondition(isDirectory)
    wrapper.preferredFilename = key
    if let existingWrapper = fileWrappers?[key] {
      removeFileWrapper(existingWrapper)
    }
    addFileWrapper(wrapper)
  }
  
  fileprivate var existingContentsKey: String? {
    return self.fileWrappers?.keys.first(where: { $0.hasPrefix("text.") })
  }
}

protocol ValueStorage {
  associatedtype Value
  
  func readValue() throws -> Value
  func writeValue(_ value: Value) throws
}

fileprivate struct CachedValue<Value, Storage: ValueStorage> where Storage.Value == Value {

  private let storage: Storage
  private var dirty = false
  private var _value: Value?
  
  fileprivate init(storage: Storage) {
    self.storage = storage
  }

  mutating func value() throws -> Value {
    if let value = _value { return value }
    let value = try storage.readValue()
    _value = value
    dirty = false
    return value
  }
  
  mutating func setValue(_ value: Value) {
    _value = value
    dirty = true
  }
  
  mutating func flush() throws {
    if dirty, let value = _value {
      try storage.writeValue(value)
      dirty = false
    }
  }
  
  mutating func clear() {
    dirty = false
    _value = nil
  }
}

public final class TextBundleDocument: UIDocument {
  
  public enum Error: Swift.Error {
    case cannotDecodeString
    case cannotEncodeString
  }
  
  public struct Metadata: Codable, Equatable {
    public var version = 2
    public var type: String? = "net.daringfireball.markdown"
    public var transient: Bool?
    public var creatorURL: String?
    public var creatorIdentifier: String?
    public var sourceURL: String?
    
    public init() {
      // NOTHING
    }
    
    fileprivate init(from data: Data) throws {
      let decoder = JSONDecoder()
      self = try decoder.decode(Metadata.self, from: data)
    }
    
    fileprivate func makeData() throws -> Data {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      return try encoder.encode(self)
    }
  }
  
  private lazy var metadataCache = {
    return CachedValue(storage: MetadataStorage(document: self))
  }()
  
  public func metadata() throws -> Metadata {
    return try metadataCache.value()
  }
  
  public func setMetadata(_ metadata: Metadata) throws {
    let currentMetadata = try metadataCache.value()
    undoManager.registerUndo(withTarget: self) { (document) in
      document.metadataCache.setValue(currentMetadata)
    }
    metadataCache.setValue(metadata)
  }
  
  private lazy var textCache = {
    CachedValue(storage: StringStorage(document: self))
  }()
  
  public func text() throws -> String {
    return try textCache.value()
  }
  
  public func setText(_ contents: String) throws {
    let currentContents = try textCache.value()
    undoManager.registerUndo(withTarget: self) { (document) in
      document.textCache.setValue(currentContents)
    }
    textCache.setValue(contents)
  }
  
  public var assetNames: [String] {
    if let assetNames = textBundle.fileWrappers?["assets"]?.fileWrappers?.keys {
      return Array(assetNames)
    } else {
      return []
    }
  }
  
  private var textBundle = FileWrapper(directoryWithFileWrappers: [:])
  
  override public func contents(forType typeName: String) throws -> Any {
    try metadataCache.flush()
    try textCache.flush()
    return textBundle
  }
  
  public override func load(
    fromContents contents: Any,
    ofType typeName: String?
  ) throws {
    guard
      let directory = contents as? FileWrapper
      else {
        return
    }
    metadataCache.clear()
    textCache.clear()
    textBundle = directory
  }
}

extension TextBundleDocument {
  struct StringStorage: ValueStorage {
    weak var document: TextBundleDocument?

    var key: String {
      return document?.textBundle.fileWrappers?.keys.first(where: { $0.hasPrefix("text.") })
        ?? "text.markdown"
    }
    
    func readValue() throws -> String {
      guard
        let wrapper = document?.textBundle.fileWrappers?[key],
        let data = wrapper.regularFileContents
        else { return "" }
      guard let string = String(data: data, encoding: .utf8)
        else { throw Error.cannotDecodeString }
      return string
    }
    
    func writeValue(_ value: String) throws {
      guard let data = value.data(using: .utf8) else { throw Error.cannotEncodeString }
      let wrapper = FileWrapper(regularFileWithContents: data)
      document?.textBundle.replaceFileWrapper(wrapper, key: key)
    }
  }
}

extension TextBundleDocument {
  struct MetadataStorage: ValueStorage {
    
    private weak var document: TextBundleDocument?
    private let key = "info.json"
    
    init(document: TextBundleDocument) {
      self.document = document
    }
    
    func readValue() throws -> Metadata {
      guard
        let wrapper = document?.textBundle.fileWrappers?[key],
        let data = wrapper.regularFileContents
        else { return Metadata() }
      return try Metadata(from: data)
    }
    
    func writeValue(_ value: Metadata) throws {
      let data = try value.makeData()
      let wrapper = FileWrapper(regularFileWithContents: data)
      document?.textBundle.replaceFileWrapper(wrapper, key: key)
    }
  }
}
