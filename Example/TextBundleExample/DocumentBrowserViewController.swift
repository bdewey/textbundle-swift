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

import textbundle_swift

final class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    delegate = self
    
    allowsDocumentCreation = true
    allowsPickingMultipleItems = false
    
    // Update the style of the UIDocumentBrowserViewController
    // browserUserInterfaceStyle = .dark
    // view.tintColor = .white
    
    // Specify the allowed content types of your application via the Info.plist.
    
    // Do any additional setup after loading the view, typically from a nib.
  }
  
  
  // MARK: UIDocumentBrowserViewControllerDelegate
  
  func documentBrowser(
    _ controller: UIDocumentBrowserViewController,
    didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void
  ) {
    let newDocumentURL: URL? = Bundle.main.url(forResource: "Textbundle Example", withExtension: "textbundle")
    
    // Set the URL for the new document here. Optionally, you can present a template chooser before calling the importHandler.
    // Make sure the importHandler is always called, even if the user cancels the creation request.
    if newDocumentURL != nil {
      importHandler(newDocumentURL, .copy)
    } else {
      importHandler(nil, .none)
    }
  }
  
  func documentBrowser(
    _ controller: UIDocumentBrowserViewController,
    didPickDocumentURLs documentURLs: [URL]
  ) {
    guard let sourceURL = documentURLs.first else { return }
    
    // Present the Document View Controller for the first document that was picked.
    // If you support picking multiple items, make sure you handle them all.
    presentDocument(at: sourceURL)
  }
  
  func documentBrowser(
    _ controller: UIDocumentBrowserViewController,
    didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL
  ) {
    // Present the Document View Controller for the new newly created document
    presentDocument(at: destinationURL)
  }
  
  func documentBrowser(
    _ controller: UIDocumentBrowserViewController,
    failedToImportDocumentAt documentURL: URL, error: Error?
  ) {
    // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
  }
  
  // MARK: Document Presentation
  
  func presentDocument(at documentURL: URL) {
    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
    let navigationController = storyBoard.instantiateViewController(withIdentifier: "DocumentViewController") as! UINavigationController
    let documentViewController = navigationController.viewControllers[0] as! DocumentViewController
    documentViewController.document = TextBundleDocument(fileURL: documentURL)
    
    present(navigationController, animated: true, completion: nil)
  }
}

