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

final class DocumentViewController: UIViewController, UITextViewDelegate {
  
  var document: TextBundleDocument?
  
  @IBOutlet var textView: UITextView!
  
  override func viewDidLoad() {
    textView.delegate = self
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(dismissDocumentViewController)
    )
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Access the document
    if let document = document {
      document.open(completionHandler: { (success) in
        if success {
          // Display the content of the document, e.g.:
          self.textView.text = try? document.text()
          self.title = document.fileURL.lastPathComponent
        } else {
          // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
        }
      })
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    document?.close(completionHandler: nil)
  }
  
  @IBAction func dismissDocumentViewController() {
    dismiss(animated: true) {
      self.document?.close(completionHandler: nil)
    }
  }
  
  func textViewDidChange(_ textView: UITextView) {
    try? self.document?.setText(textView.text)
  }
}
