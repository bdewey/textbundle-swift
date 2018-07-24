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

/// UIDocument class that can read and edit the text contents and metadata of a
/// textbundle wrapper.
///
/// See http://textbundle.org
public final class TextBundleDocument: UIDocument {
  
  /// The FileWrapper that points to the textbundle on disk.
  private(set) public var textBundle: TextBundle!
  
  public override init(fileURL url: URL) {
    super.init(fileURL: url)
    self.undoManager = ImmediateUndoManager(document: self)
    self.textBundle = TextBundle(
      bundle: FileWrapper(directoryWithFileWrappers: [:]),
      undoManager: undoManager
    )
  }
  
  /// Write in-memory contents to textBundle and return textBundle for storage.
  override public func contents(forType typeName: String) throws -> Any {
    try textBundle.flush()
    return textBundle.bundle
  }
  
  /// Loads the textbundle.
  public override func load(
    fromContents contents: Any,
    ofType typeName: String?
  ) throws {
    guard let directory = contents as? FileWrapper else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError, userInfo: nil)
    }
    textBundle = TextBundle(bundle: directory, undoManager: undoManager)
  }

  public var previousError: Error?

  public override func handleError(_ error: Error, userInteractionPermitted: Bool) {
    self.previousError = error
    finishedHandlingError(error, recovered: false)
  }
}
