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
}
