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
  
  fileprivate var string: String? {
    guard let data = regularFileContents, let string = String(data: data, encoding: .utf8)
      else { return nil }
    return string
  }
  
  fileprivate var existingContentsKey: String? {
    return self.fileWrappers?.keys.first(where: { $0.hasPrefix("text.") })
  }
}

fileprivate class ContentsCache {
  
  private let bundle: FileWrapper
  private let preferredFilename: String
  
  init(bundle: FileWrapper, preferredFilename: String) {
    precondition(bundle.isDirectory)
    self.bundle = bundle
    self.preferredFilename = preferredFilename
    _wrapper = bundle.fileWrappers?[preferredFilename]
  }
  
  private var _contents: String? = nil
  private var _wrapper: FileWrapper? = nil
  
  @discardableResult
  func makeFileWrapper() throws -> FileWrapper {
    guard _wrapper == nil else { return _wrapper! }
    guard let data = _contents?.data(using: .utf8) else {
      throw NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileWriteInapplicableStringEncodingError,
        userInfo: nil
      )
    }
    let wrapper = FileWrapper(regularFileWithContents: data)
    wrapper.preferredFilename = preferredFilename
    bundle.addFileWrapper(wrapper)
    _wrapper = wrapper
    return wrapper
  }
  
  var contents: String {
    get {
      if let contents = _contents { return contents }
      if let wrapperString = _wrapper?.string {
        _contents = wrapperString
        return wrapperString
      }
      return ""
    }
    set {
      if let wrapper = _wrapper {
        bundle.removeFileWrapper(wrapper)
      }
      _wrapper = nil
      _contents = newValue
    }
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
  
  public var metadata = Metadata() {
    didSet {
      undoManager.registerUndo(withTarget: self) { (document) in
        document.metadata = oldValue
      }
    }
  }
  
  public var contents: String {
    get {
      return contentsCache.contents
    }
    set {
      let currentContents = contentsCache.contents
      undoManager.registerUndo(withTarget: self) { (document) in
        document.contentsCache.contents = currentContents
      }
      contentsCache.contents = newValue
    }
  }
  
  public var assetNames: [String] {
    if let assetNames = textBundle.fileWrappers?["assets"]?.fileWrappers?.keys {
      return Array(assetNames)
    } else {
      return []
    }
  }
  
  private var textBundle: FileWrapper
  private var contentsCache: ContentsCache
  
  public override init(fileURL url: URL) {
    textBundle = FileWrapper(directoryWithFileWrappers: [:])
    contentsCache = ContentsCache(bundle: textBundle, preferredFilename: "text.markdown")
    super.init(fileURL: url)
  }
  
  override public func contents(forType typeName: String) throws -> Any {
    _ = try? contentsCache.makeFileWrapper()
    return textBundle
  }
  
  public override func load(
    fromContents contents: Any,
    ofType typeName: String?
  ) throws {
    guard
      let directory = contents as? FileWrapper,
      let fileWrappers = directory.fileWrappers
      else {
        return
    }
    textBundle = directory
    contentsCache = ContentsCache(bundle: textBundle, preferredFilename: textBundle.existingContentsKey ?? "text.markdown")
    if let metadataWrapper = fileWrappers["info.json"],
      let data = metadataWrapper.regularFileContents {
      metadata = try Metadata(from: data)
    }
  }
}
