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

fileprivate class ContainedFileWrapper {
  private weak var container: FileWrapper?
  private var fileWrapper: FileWrapper
  typealias FlushCallback = () -> Void
  var willFlush: FlushCallback?
  
  init(container: FileWrapper, fileWrapper: FileWrapper) {
    precondition(container.isDirectory)
    precondition(container.keyForChildFileWrapper(fileWrapper) != nil)
    self.container = container
    self.fileWrapper = fileWrapper
  }
  
  func replace(with fileWrapper: FileWrapper) {
    guard let container = container else { return }
    fileWrapper.preferredFilename = container.keyForChildFileWrapper(self.fileWrapper)
    container.removeFileWrapper(self.fileWrapper)
    container.addFileWrapper(fileWrapper)
  }
  
  var regularFileContents: Data? {
    return fileWrapper.regularFileContents
  }
  
  func flush() {
    willFlush?()
  }
}

fileprivate class ContainerFileWrapper {
  let container: FileWrapper
  private var containedFileWrappers: [String : ContainedFileWrapper] = [:]
  
  init(container: FileWrapper) {
    precondition(container.isDirectory)
    self.container = container
  }
  
  subscript (key: String) -> ContainedFileWrapper? {
    get {
      if let existingContainedFileWrapper = containedFileWrappers[key] {
        return existingContainedFileWrapper
      }
      if let wrapper = container.fileWrappers?[key] {
        let containedFileWrapper = ContainedFileWrapper(container: container, fileWrapper: wrapper)
        containedFileWrappers[key] = containedFileWrapper
        return containedFileWrapper
      }
      return nil
    }
  }
  
  func addRegularFile(withContents data: Data, preferredFilename: String) -> ContainedFileWrapper {
    let wrapper = FileWrapper(regularFileWithContents: data)
    wrapper.preferredFilename = preferredFilename
    let key = container.addFileWrapper(wrapper)
    let containedFileWrapper = ContainedFileWrapper(container: container, fileWrapper: wrapper)
    containedFileWrappers[key] = containedFileWrapper
    return containedFileWrapper
  }
  
  func flush() {
    for wrapper in containedFileWrappers.values {
      wrapper.flush()
    }
  }
}

fileprivate class FileWrapperStringData {
  private let containedFileWrapper: ContainedFileWrapper
  private var dirty = false
  private var _value: String?
  
  var value: String {
    get {
      if let value = _value { return value }
      guard
        let data = containedFileWrapper.regularFileContents,
        let value = String(data: data, encoding: .utf8)
        else {
          return ""
      }
      _value = value
      dirty = false
      return value
    }
    set {
      _value = newValue
      dirty = true
    }
  }
  
  init(containedFileWrapper: ContainedFileWrapper) {
    self.containedFileWrapper = containedFileWrapper
    containedFileWrapper.willFlush = { [weak self] in
      self?.flush()
    }
  }
  
  private func flush() {
    guard dirty, let data = _value?.data(using: .utf8) else { return }
    let wrapper = FileWrapper(regularFileWithContents: data)
    containedFileWrapper.replace(with: wrapper)
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
  
  private var _textString: FileWrapperStringData?
  private var textString: FileWrapperStringData {
    if let textString = _textString {
      return textString
    }
    let key = textBundle.container.existingContentsKey ?? "text.markdown"
    let wrapper = textBundle[key] ?? textBundle.addRegularFile(withContents: Data(), preferredFilename: key)
    let textString = FileWrapperStringData(containedFileWrapper: wrapper)
    _textString = textString
    return textString
  }
  
  public var contents: String {
    get {
      return textString.value
    }
    set {
      let currentContents = textString.value
      undoManager.registerUndo(withTarget: self) { (document) in
        document.textString.value = currentContents
      }
      textString.value = newValue
    }
  }
  
  public var assetNames: [String] {
    if let assetNames = textBundle.container.fileWrappers?["assets"]?.fileWrappers?.keys {
      return Array(assetNames)
    } else {
      return []
    }
  }
  
  private var textBundle: ContainerFileWrapper
  
  public override init(fileURL url: URL) {
    textBundle = ContainerFileWrapper(container: FileWrapper(directoryWithFileWrappers: [:]))
    super.init(fileURL: url)
  }
  
  override public func contents(forType typeName: String) throws -> Any {
    textBundle.flush()
    return textBundle.container
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
    textBundle = ContainerFileWrapper(container: directory)
    if let metadataWrapper = fileWrappers["info.json"],
      let data = metadataWrapper.regularFileContents {
      metadata = try Metadata(from: data)
    }
  }
}
