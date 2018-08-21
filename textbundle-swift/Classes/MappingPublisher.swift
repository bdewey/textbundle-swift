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

public final class MappingPublisher<P: Publisher, OutputValue>: Publisher {
  public typealias MappingBlock = (P.Value) -> OutputValue
  
  public init(publisher: P, mapping: @escaping MappingBlock) {
    self.publisher = publisher
    self.mapping = mapping
    self.subscription = publisher.subscribe({ (input) in
      let output = input.flatMap(mapping)
      self.outputPublisherEndpoint(output)
    })
  }
  
  private let publisher: P
  private let mapping: MappingBlock
  private var subscription: AnySubscription?
  private let (outputPublisherEndpoint, outputPublisher) = SimplePublisher<OutputValue>.create()
  
  public func subscribe(_ block: @escaping (Result<OutputValue>) -> Void) -> AnySubscription {
    return outputPublisher.subscribe(block)
  }
  
  public func removeSubscription(_ subscription: AnySubscription) {
    outputPublisher.removeSubscription(subscription)
  }
}

extension Publisher {
  public func map<Output>(_ block: @escaping (Value) -> Output) -> MappingPublisher<Self, Output> {
    return MappingPublisher(publisher: self, mapping: block)
  }
}
