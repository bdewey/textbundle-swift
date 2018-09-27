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

/// Reads and writes metadata to info.json
public final class MetadataStorage: TextBundleDocumentSaveListener {
  internal init(document: TextBundleDocument) {
    value = DocumentProperty(initialResult: metadataResult(from: document))
    changeSubscription = value.subscribe { [weak self](result) in
      guard let value = result.value else { return }
      if value.source == .memory {
        self?.textBundleListenerHasChanges?()
      }
    }
  }

  public let value: DocumentProperty<Metadata>
  public var changeSubscription: AnySubscription?

  public var textBundleListenerHasChanges: TextBundleDocumentSaveListener.ChangeBlock?
  fileprivate static let key = "info.json"
  
  public func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    if let metadata = value.clean() {
      let data = try metadata.makeData()
      let wrapper = FileWrapper(regularFileWithContents: data)
      textBundleDocument.bundle.replaceFileWrapper(wrapper, key: MetadataStorage.key)
    }
  }
  
  public func textBundleDocumentDidLoad(_ textBundleDocument: TextBundleDocument) {
    let result = Result<Metadata> {
      guard let data = try? textBundleDocument.data(for: MetadataStorage.key) else { return Metadata() }
      return try Metadata(from: data)
    }
    value.setDocumentResult(result)
  }
}

private func metadataResult(from document: TextBundleDocument) -> Result<MetadataStorage.Metadata> {
  return Result<MetadataStorage.Metadata> {
    guard let data = try? document.data(for: MetadataStorage.key) else { return MetadataStorage.Metadata() }
    return try MetadataStorage.Metadata(from: data)
  }
}

extension TextBundleDocument {
  public var metadata: MetadataStorage {
    guard let metadataStorage = listener(for: MetadataStorage.key, constructor: MetadataStorage.init) as? MetadataStorage else {
      fatalError("Metadata storage is the wrong type?")
    }
    return metadataStorage
  }
}
