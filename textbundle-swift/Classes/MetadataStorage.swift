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
  public init(document: TextBundleDocument) {
    self.document = document
    document.addListener(self)
    metadata = DirtyableValue<Metadata>(initializer: readValue)
  }
  
  public var metadata: DirtyableValue<Metadata>!

  private let document: TextBundleDocument
  private let key = "info.json"
  
  private func readValue() throws -> Metadata {
    guard let data = try? document.data(for: key) else { return Metadata() }
    return try Metadata(from: data)
  }
  
  public func dirtyableValueDidChange(_ dirtyableValue: DirtyableValue<Metadata>) {
    document.updateChangeCount(.done)
  }
  
  private func writeValue(_ value: Metadata) throws {
    let data = try value.makeData()
    let wrapper = FileWrapper(regularFileWithContents: data)
    document.bundle.replaceFileWrapper(wrapper, key: key)
  }

  public func textBundleDocumentWillSave(_ textBundleDocument: TextBundleDocument) throws {
    if let metadata = metadata.clean() {
      try writeValue(metadata)
    }
  }
}
