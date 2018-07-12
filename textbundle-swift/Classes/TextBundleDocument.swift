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

public final class TextBundleDocument: UIDocument {
  
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
  
  public var metadata = Metadata()
  public var contents = ""
  
  override public func contents(forType typeName: String) throws -> Any {
    return FileWrapper(directoryWithFileWrappers: [
      "info.json": FileWrapper(regularFileWithContents: try metadata.makeData()),
      ])
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
    if let metadataWrapper = fileWrappers["info.json"],
      let data = metadataWrapper.regularFileContents {
      metadata = try Metadata(from: data)
    }
    if let textKey = fileWrappers.keys.first(where: { $0.hasPrefix("text.") }),
      let data = fileWrappers[textKey]?.regularFileContents,
      let string = String(data: data, encoding: .utf8) {
      self.contents = string
    }
  }
}
