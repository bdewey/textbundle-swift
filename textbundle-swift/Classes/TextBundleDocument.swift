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

/// UIDocument class that can read and edit the text contents and metadata of a
/// textbundle wrapper.
///
/// See http://textbundle.org
public final class TextBundleDocument: UIDocument {
  
  /// Possible errors when reading / writing contents.
  public enum Error: Swift.Error {
    
    /// The text cannot be decoded from UTF-8.
    case cannotDecodeString
    
    /// The text cannot be encoded in UTF-8.
    case cannotEncodeString
  }
  
  /// Stores the in-memory copy of the bundle metadata.
  private lazy var metadataCache = {
    return CachedValue(storage: MetadataStorage(document: self))
  }()
  
  /// The textbundle metadata.
  public func metadata() throws -> Metadata {
    return try metadataCache.value()
  }
  
  /// Updates the textbundle metadata.
  /// - parameter metadata: The updated copy of the textbundle metadata.
  public func setMetadata(_ metadata: Metadata) throws {
    let currentMetadata = try metadataCache.value()
    undoManager.registerUndo(withTarget: self) { (document) in
      document.metadataCache.setValue(currentMetadata)
    }
    metadataCache.setValue(metadata)
  }
  
  /// Stores the in-memory copy of the text.
  private lazy var textCache = {
    CachedValue(storage: StringStorage(document: self))
  }()
  
  /// The textbundle text.
  /// - returns: The in-memory copy of the textbundle text, reading from storage if necessary.
  public func text() throws -> String {
    return try textCache.value()
  }
  
  /// Updates the textbundle text.
  /// - parameter contents: The updated textbundle text.
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
  
  /// The FileWrapper that points to the textbundle on disk.
  private var textBundle = FileWrapper(directoryWithFileWrappers: [:])
  
  /// Write in-memory contents to textBundle and return textBundle for storage.
  override public func contents(forType typeName: String) throws -> Any {
    try metadataCache.flush()
    try textCache.flush()
    return textBundle
  }
  
  /// Loads the textbundle.
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
  
  /// Textbundle metadata. See http://textbundle.org/spec/
  public struct Metadata: Codable, Equatable {
    
    /// Textbundle version
    public var version = 2
    
    /// The UTI of the text contents in the bundle.
    public var type: String? = "net.daringfireball.markdown"
    
    /// Flag indicating if the bundle is a temporary container solely for exchanging data between
    /// applications.
    public var transient: Bool?
    
    /// The URL of the application that originally created the textbundle.
    public var creatorURL: String?
    
    /// The bundle identifier of the application that created the file.
    public var creatorIdentifier: String?
    
    /// The URL of the file used to generate the bundle.
    public var sourceURL: String?
    
    public init() {
      // NOTHING
    }
    
    /// Creates a Metadata instance from JSON-encoded data.
    /// - throws: An error if any metadata field throws an error during decoding.
    fileprivate init(from data: Data) throws {
      let decoder = JSONDecoder()
      self = try decoder.decode(Metadata.self, from: data)
    }
    
    /// Returns a JSON-encoded representation of the metadata.
    /// - throws: An error if any metadata field throws an error during encoding.
    /// - returns: A new Data value containing the JSON-encoded representation of the metadata.
    fileprivate func makeData() throws -> Data {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      return try encoder.encode(self)
    }
  }
}

extension TextBundleDocument {
  
  /// Reads and writes data to text.*
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
  
  /// Reads and writes metadata to info.json
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

extension FileWrapper {
  
  /// Stores a file wrapper into a directory, replacing any existing file wrapper at `key`.
  /// - precondition: The receiver is a directory file wrapper.
  /// - parameter wrapper: The file wrapper to store in the directory.
  /// - parameter key: The identifier key to use for `wrapper` as a child of the receiver.
  fileprivate func replaceFileWrapper(_ wrapper: FileWrapper, key: String) {
    precondition(isDirectory)
    wrapper.preferredFilename = key
    if let existingWrapper = fileWrappers?[key] {
      removeFileWrapper(existingWrapper)
    }
    addFileWrapper(wrapper)
  }
}
