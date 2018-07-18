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
struct MetadataStorage: ValueStorage {
  
  weak var bundle: FileWrapper?
  let key = "info.json"
  
  func readValue() throws -> TextBundle.Metadata {
    guard
      let wrapper = bundle?.fileWrappers?[key],
      let data = wrapper.regularFileContents
      else { return TextBundle.Metadata() }
    return try TextBundle.Metadata(from: data)
  }
  
  func writeValue(_ value: TextBundle.Metadata) throws {
    let data = try value.makeData()
    let wrapper = FileWrapper(regularFileWithContents: data)
    bundle?.replaceFileWrapper(wrapper, key: key)
  }
}
