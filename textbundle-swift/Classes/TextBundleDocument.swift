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

/// This class is a hack introduced in Xcode 10 Beta 4
/// With that beta, simply calling the UndoManager methods did not autosave in time
/// for tests to work. This class makes sure that we tell UIDocument that we have unsaved
/// changes right away.
fileprivate class ImmediateUndoManager: UndoManager {
  
  weak var document: UIDocument?
  
  init(document: UIDocument) {
    self.document = document
    super.init()
  }
  
  override func registerUndo(withTarget target: Any, selector: Selector, object anObject: Any?) {
    super.registerUndo(withTarget: target, selector: selector, object: anObject)
    document?.updateChangeCount(.done)
  }
  
  override func __registerUndoWithTarget(_ target: Any, handler undoHandler: @escaping (Any) -> Void) {
    super.__registerUndoWithTarget(target, handler: undoHandler)
    document?.updateChangeCount(.done)
  }
}

public protocol TextBundleDocumentSaveListener: class {
  func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws
}

/// UIDocument class that can read and edit the text contents and metadata of a
/// textbundle wrapper.
///
/// See http://textbundle.org
public final class TextBundleDocument: UIDocument {
  
  /// The FileWrapper that contains all of the TextBundle contents.
  public var bundle: FileWrapper
  
  public override init(fileURL url: URL) {
    self.bundle = FileWrapper(directoryWithFileWrappers: [:])
    super.init(fileURL: url)
    self.undoManager = ImmediateUndoManager(document: self)
  }
  
  /// Listeners are strongly held until the document closes.
  private var listeners: [TextBundleDocumentSaveListener] = []
  
  public func addListener(_ listener: TextBundleDocumentSaveListener) {
    listeners.append(listener)
  }
  
  /// Write in-memory contents to textBundle and return textBundle for storage.
  override public func contents(forType typeName: String) throws -> Any {
    for listener in listeners {
      try listener.textBundleDocumentWillSave(self)
    }
    return bundle
  }
  
  /// Loads the textbundle.
  public override func load(
    fromContents contents: Any,
    ofType typeName: String?
  ) throws {
    guard let directory = contents as? FileWrapper else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError, userInfo: nil)
    }
    bundle = directory
  }
  
  public override func close(completionHandler: ((Bool) -> Void)? = nil) {
    let wrappedHandler = { (success: Bool) in
      completionHandler?(success)
      self.listeners = []
    }
    super.close(completionHandler: wrappedHandler)
  }

  public var previousError: Swift.Error?

  public override func handleError(_ error: Swift.Error, userInteractionPermitted: Bool) {
    self.previousError = error
    finishedHandlingError(error, recovered: false)
  }
}

extension TextBundleDocument {
  
  enum Error: Swift.Error {
    
    /// A bundle key is already in use in the package.
    case keyAlreadyUsed(key: String)
    
    /// The key is not used to identify data in the bundle.
    case noSuchDataKey(key: String)
    
    /// The child directory path cannot be used
    case invalidChildPath(error: Swift.Error)
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
    replaceIfExists: Bool = true,
    childDirectoryPath: [String] = []
  ) throws -> String {
    let container = try containerWrapper(at: childDirectoryPath)
    let child = FileWrapper(regularFileWithContents: data)
    child.preferredFilename = preferredFilename
    if replaceIfExists, let existingWrapper = container.fileWrappers?[preferredFilename] {
      container.removeFileWrapper(existingWrapper)
    }
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
