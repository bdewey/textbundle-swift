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

import XCTest
import textbundle_swift

fileprivate let expectedDocumentContents = """
# Textbundle Example

This is a simple example of a textbundle package. The following paragraph contains an example of a referenced image using the embedding code `![](assets/textbundle.png)`.

![](assets/textbundle.png)

"""

final class TextBundleDocumentTests: XCTestCase {

  func testSerializeMetadata() {
    var metadata = TextBundleDocument.Metadata()
    metadata.creatorIdentifier = "org.brians-brain.TextBundleExample"
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try! encoder.encode(metadata)
    let string = String(data: data, encoding: .utf8)!
    let expectedResults = """
{
  "version" : 2,
  "type" : "net.daringfireball.markdown",
  "creatorIdentifier" : "org.brians-brain.TextBundleExample"
}
"""
    XCTAssertEqual(string, expectedResults)
  }
  
  func testCanDeserializeExample() {
    // This example comes from textbundle.org
    let exampleMetadata = """
{
  "version":              2,
  "type":                 "net.daringfireball.markdown",
  "transient":            true,
  "creatorURL":           "file:///Applications/MyApp",
  "creatorIdentifier":    "com.example.myapp",
  "sourceURL":            "file:///Users/johndoe/Documents/mytext.markdown",
  "com.example.myapp":    {
    "version":    9,
    "customKey":  "aCustomValue"
  }
}
"""
    let decoder = JSONDecoder()
    let result = try! decoder.decode(TextBundleDocument.Metadata.self, from: exampleMetadata.data(using: .utf8)!)
    var expectedResult = TextBundleDocument.Metadata()
    expectedResult.version = 2
    expectedResult.type = "net.daringfireball.markdown"
    expectedResult.transient = true
    expectedResult.creatorURL = "file:///Applications/MyApp"
    expectedResult.creatorIdentifier = "com.example.myapp"
    expectedResult.sourceURL = "file:///Users/johndoe/Documents/mytext.markdown"
    XCTAssertEqual(result, expectedResult)
  }
  
  func testCanLoadContents() {
    let document = try! makeDocument("testCanLoadContents")
    defer { try? FileManager.default.removeItem(at: document.fileURL )}
    let didOpen = expectation(description: "did open")
    document.open { (success) in
      XCTAssertTrue(success)
      XCTAssertEqual(document.contents, expectedDocumentContents)
      didOpen.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }
  
  func testCanEditContents() {
    let editedText = "This is edited text!\n"
    let document = try! makeDocument("testCanEditContents")
    defer { try? FileManager.default.removeItem(at: document.fileURL) }
    let didEdit = expectation(description: "did edit")
    document.open { (success) in
      XCTAssertTrue(success)
      document.contents = editedText
      document.close(completionHandler: { (closeSuccess) in
        XCTAssertTrue(closeSuccess)
        didEdit.fulfill()
      })
    }
    
    waitForExpectations(timeout: 3, handler: nil)
    
    let roundTripDocument = TextBundleDocument(fileURL: document.fileURL)
    let didOpen = expectation(description: "did open")
    roundTripDocument.open { (success) in
      XCTAssertTrue(success)
      XCTAssertEqual(roundTripDocument.contents, editedText)
      XCTAssertEqual(roundTripDocument.assetNames, ["textbundle.png"])
      didOpen.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }
  
  func testCanLoadAssets() {
    let document = try! makeDocument("testCanLoadAssets")
    defer { try? FileManager.default.removeItem(at: document.fileURL) }
    let didOpen = expectation(description: "did open")
    document.open { (success) in
      XCTAssertTrue(success)
      XCTAssertEqual(document.assetNames, ["textbundle.png"])
      didOpen.fulfill()
    }
    waitForExpectations(timeout: 3, handler: nil)
  }
}

// MARK: - Helpers

extension TextBundleDocumentTests {
  
  func makeDocument(_ identifier: String) throws -> TextBundleDocument {
    let url = testResources.url(forResource: "Textbundle Example", withExtension: "textbundle")!
    let pathComponent = identifier + "-" + UUID().uuidString + ".textbundle"
    let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(pathComponent)
    try FileManager.default.copyItem(at: url, to: temporaryURL)
    return TextBundleDocument(fileURL: temporaryURL)
  }
  
  var testResources: Bundle {
    let resourceURL = Bundle(for: TextBundleDocumentTests.self).url(
      forResource: "TestContent",
      withExtension: "bundle"
    )
    return Bundle(url: resourceURL!)!
  }
}
