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

/// Type-erasing protocol for subscriptions.
public protocol AnySubscription: class { }

/// Things that know how to publish updated values conform to this protocol.
public protocol Publisher {

  /// The type that's published.
  associatedtype Value

  /// A block that receives updated results.
  ///
  /// - note: The subscription block receives a `Result<Value>`, not a `Value`,
  ///         to allow for the possiblity of errors.
  typealias SubscriptionBlock = (Result<Value>) -> Void

  /// Create a new subscription.
  ///
  /// - parameter block: The block that should receive updates.
  /// - returns: A subscription object.
  /// - note: When the subscription object is deallocated, it will remove itself from this
  ///         publisher.
  func subscribe(_ block: @escaping SubscriptionBlock) -> AnySubscription

  /// Removes a subscription. The block will no longer receive updates.
  ///
  /// - parameter subscription: The subscription object to remove from the publisher.
  func removeSubscription(_ subscription: AnySubscription)
}

/// Publishes changes to values.
public final class SimplePublisher<Value>: Publisher {
  
  /// A publishing endpoint is a function that will send the value to all subscribers.
  public typealias PublishingEndpoint = (Result<Value>) -> Void

  /// Represents a connection to a publisher.
  ///
  /// - note: The subscription maintains a strong connection back to the publisher.
  final private class Subscription: AnySubscription {
    
    /// The publisher that generates
    fileprivate let publisher: SimplePublisher<Value>
    
    /// Index of this block in the publisher.
    fileprivate let blockIndex: Int
    
    /// Designated initializer.
    fileprivate init(publisher: SimplePublisher<Value>, blockIndex: Int) {
      self.publisher = publisher
      self.blockIndex = blockIndex
    }
    
    /// Removes this subscription from the publisher.
    deinit {
      publisher.removeSubscription(self)
    }
  }

  /// Creates a new publisher.
  ///
  /// - returns: A tuple containing the publisher and the endpoint that can be used to
  ///            send results to the publisher.
  public static func create() -> (PublishingEndpoint, SimplePublisher<Value>) {
    let publisher = SimplePublisher<Value>()
    return (publisher.publishResult, publisher)
  }
  
  /// All subscribers.
  private var subscribers = BlockArray<Result<Value>>()
  
  /// Publish a result to all subscribers.
  /// - note: All subscriber blocks are called synchronously on this thread.
  /// - parameter result: The result to publish to subscribers.
  private func publishResult(_ result: Result<Value>) {
    assert(Thread.isMainThread)
    subscribers.invoke(with: result)
  }
  
  /// Adds a subscriber.
  ///
  /// - parameter block: The block to invoke with new values
  public func subscribe(_ block: @escaping (Result<Value>) -> Void) -> AnySubscription {
    assert(Thread.isMainThread)
    return Subscription(publisher: self, blockIndex: subscribers.append(block))
  }
  
  /// Removes this subscription. The associated block will not get called on subsequent
  /// `invoke`
  public func removeSubscription(_ subscription: AnySubscription) {
    assert(Thread.isMainThread)
    let subscription = subscription as! Subscription
    assert(subscription.publisher === self)
    subscribers.remove(at: subscription.blockIndex)
  }
  
  public var hasActiveSubscribers: Bool {
    return !subscribers.isEmpty
  }
}
