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

/// Reads and writes data to text.*
public final class TextStorage: TextBundleDocumentSaveListener {
  
  internal init(document: TextBundleDocument) {
    value = DocumentProperty(initialResult: TextStorage.textResult(from: document))
    changeSubscription = value.subscribe { [weak self](result) in
      guard let value = result.value else { return }
      if value.source == .memory {
        self?.textBundleListenerHasChanges?()
      }
    }
  }
  
  public var textBundleListenerHasChanges: TextBundleDocumentSaveListener.ChangeBlock?
  public let value: DocumentProperty<String>
  public var changeSubscription: AnySubscription?
  
  public func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    if let text = value.clean() {
      guard let data = text.data(using: .utf8) else {
        throw NSError.fileWriteInapplicableStringEncoding
      }
      let wrapper = FileWrapper(regularFileWithContents: data)
      textBundleDocument.bundle.replaceFileWrapper(
        wrapper,
        key: TextStorage.key(for: textBundleDocument)
      )
    }
  }

  public func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    value.setDocumentResult(TextStorage.textResult(from: textBundleDocument))
  }

  private static func key(for document: TextBundleDocument) -> String {
    return document.bundle.fileWrappers?.keys.first(where: { $0.hasPrefix("text.") })
      ?? "text.markdown"
  }

  private static func textResult(from textBundleDocument: TextBundleDocument) -> Result<String> {
    guard let data = try? textBundleDocument.data(for: key(for: textBundleDocument)) else {
      return .success("")
    }
    let result = Result<String> {
      guard let string = String(data: data, encoding: .utf8) else {
        throw NSError(
          domain: NSCocoaErrorDomain,
          code: NSFileReadInapplicableStringEncodingError,
          userInfo: nil
        )
      }
      return string
    }
    return result
  }
}

extension TextBundleDocument {
  public var text: TextStorage {
    guard let textStorage = listener(for: "text", constructor: TextStorage.init) as? TextStorage else {
      fatalError("Wrong type for text storage?")
    }
    return textStorage
  }
}
