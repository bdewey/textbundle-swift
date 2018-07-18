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
struct TextStorage: ValueStorage {
  
  /// Possible errors when reading / writing contents.
  public enum Error: Swift.Error {
    
    /// The text cannot be encoded in UTF-8 format.
    case textIsNotUTF8
  }
  
  weak var bundle: FileWrapper?
  
  var key: String {
    return bundle?.fileWrappers?.keys.first(where: { $0.hasPrefix("text.") })
      ?? "text.markdown"
  }
  
  func readValue() throws -> String {
    guard
      let wrapper = bundle?.fileWrappers?[key],
      let data = wrapper.regularFileContents
      else { return "" }
    guard let string = String(data: data, encoding: .utf8)
      else { throw Error.textIsNotUTF8 }
    return string
  }
  
  func writeValue(_ value: String) throws {
    guard let data = value.data(using: .utf8) else { throw Error.textIsNotUTF8 }
    let wrapper = FileWrapper(regularFileWithContents: data)
    bundle?.replaceFileWrapper(wrapper, key: key)
  }
}
