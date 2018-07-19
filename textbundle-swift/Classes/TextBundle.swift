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

/// Reads and manipulates a TextBundle.
///
/// See http://textbundle.org
public final class TextBundle {
  
  enum Error: Swift.Error {
    
    /// A bundle key is already in use in the package.
    case keyAlreadyUsed(key: String)
    
    /// The key is not used to identify data in the bundle.
    case noSuchDataKey(key: String)
    
    /// The child directory path cannot be used
    case invalidChildPath(error: Swift.Error)
  }
  
  /// The FileWrapper that contains all of the TextBundle contents.
  internal let bundle: FileWrapper
  
  /// An undo manager for undoing changes to the bundle, typically supplied from a UIDocument.
  private let undoManager: UndoManager
  
  public init(bundle: FileWrapper, undoManager: UndoManager) {
    assert(bundle.isDirectory)
    self.bundle = bundle
    self.undoManager = undoManager
  }
  
  /// In-memory copy of the TextBundle text.
  lazy private var textCache = {
    CachedValue(storage: TextStorage(bundle: bundle))
  }()
  
  /// In-memory copy of the TextBundle metadata.
  lazy private var metadataCache = {
    CachedValue(storage: MetadataStorage(bundle: bundle))
  }()
  
  /// Writes cached data to persistent storage.
  public func flush() throws {
    try textCache.flush()
    try metadataCache.flush()
  }
  
  /// The textbundle text.
  /// - returns: The in-memory copy of the textbundle text, reading from storage if necessary.
  public func text() throws -> String {
    return try textCache.value()
  }
  
  /// Updates the textbundle text.
  /// - parameter contents: The updated textbundle text.
  public func setText(_ text: String) throws {
    let currentContents = try textCache.value()
    undoManager.registerUndo(withTarget: self) { (textBundle) in
      textBundle.textCache.setValue(currentContents)
    }
    textCache.setValue(text)
  }

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
  
  /// Convenience: Exposes the names of the assets in the bundle.
  public var assetNames: [String] {
    if let assetNames = bundle.fileWrappers?["assets"]?.fileWrappers?.keys {
      return Array(assetNames)
    } else {
      return []
    }
  }

  // MARK: - Manipulating bundle contents

  /// Adds data to the bundle.
  ///
  /// - parameter data: The data to add.
  /// - parameter preferredFilename: The key to access the data
  /// - parameter childDirectoryPath: The path to a child directory in the bundle. Use an empty
  ///                                 array to add the data to the root of the bundle.
  /// - returns: The actual key used to store the data.
  /// - throws: Error.invalidChildDirectoryPath if childDirectoryPath cannot be used, for example
  ///           if something in the path array is already used by a non-directory file wrapper.
  @discardableResult
  public func addData(
    _ data: Data,
    preferredFilename: String,
    childDirectoryPath: [String] = []
  ) throws -> String {
    let container = try containerWrapper(at: childDirectoryPath)
    let child = FileWrapper(regularFileWithContents: data)
    child.preferredFilename = preferredFilename
    let key = container.addFileWrapper(child)
    undoManager.registerUndo(withTarget: container) { (container) in
      container.removeFileWrapper(child)
    }
    return key
  }
  
  /// Returns the keys used by a container in the bundle.
  /// - parameter childDirectoryPath: The path to a child directory in the bundle. Use an empty
  ///                                 array to add the data to the root of the bundle.
  /// - returns: The keys used in the container.
  /// - throws: Error.invalidChildDirectoryPath if childDirectoryPath cannot be used, for example
  ///           if something in the path array is already used by a non-directory file wrapper.
  public func keys(at childDirectoryPath: [String] = []) throws -> [String] {
    let container = try containerWrapper(at: childDirectoryPath)
    if let fileWrappers = container.fileWrappers {
      return Array(fileWrappers.keys)
    } else {
      return []
    }
  }
  
  /// Returns the data associated with a key in the bundle.
  /// - parameter key: The key identifying the data.
  /// - parameter childDirectoryPath: The path to a child directory in the bundle. Use an empty
  ///                                 array to add the data to the root of the bundle.
  /// - returns: The data associated with the key.
  /// - throws: Error.noSuchDataKey if the key is not used to identify data in the bundle.
  public func data(for key: String, at childDirectoryPath: [String] = []) throws -> Data {
    let container = try containerWrapper(at: childDirectoryPath)
    guard let wrapper = container.fileWrappers?[key], let data = wrapper.regularFileContents else {
      throw Error.noSuchDataKey(key: key)
    }
    return data
  }
  
  /// Finds or creates a container wrapper at a given path.
  /// - parameter childDirectoryPath: The path to a child directory in the bundle. Use an empty
  ///                                 array to add the data to the root of the bundle.
  /// - throws: Error.invalidChildDirectoryPath if childDirectoryPath cannot be used, for example
  ///           if something in the path array is already used by a non-directory file wrapper.
  private func containerWrapper(at childDirectoryPath: [String]) throws -> FileWrapper {
    var containerWrapper = bundle
    for pathComponent in childDirectoryPath {
      do {
        containerWrapper = try directory(with: pathComponent, in: containerWrapper)
      } catch {
        throw Error.invalidChildPath(error: error)
      }
    }
    return containerWrapper
  }
  
  /// Returns a directory FileWrapper.
  /// - parameter key: The key used to access the directory.
  /// - returns: The directory FileWrapper.
  /// - throws: Error.keyAlreadyUsed if the key is already in use in the bundle for a non-directory.
  private func directory(with key: String, in container: FileWrapper) throws -> FileWrapper {
    if let wrapper = container.fileWrappers?[key] {
      if wrapper.isDirectory {
        return wrapper
      } else {
        throw Error.keyAlreadyUsed(key: key)
      }
    } else {
      let wrapper = FileWrapper(directoryWithFileWrappers: [:])
      wrapper.preferredFilename = key
      container.addFileWrapper(wrapper)
      undoManager.registerUndo(withTarget: container) { (bundle) in
        bundle.removeFileWrapper(wrapper)
      }
      return wrapper
    }
  }
}
