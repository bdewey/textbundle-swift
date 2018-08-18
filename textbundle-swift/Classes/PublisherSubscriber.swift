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

/// What it says: Maintains an array of blocks that accept a value, and can invoke all
/// of the blocks with that value.
private struct BlockArray<Value> {
  typealias Block = (Value) -> Void
  private var blocks: [Block?] = []
  private var activeCount = 0

  /// Adds a block to the collection.
  ///
  /// - returns: The index that can be used in a subsequent call to `remove(at:)`
  mutating func append(_ block: @escaping Block) -> Int {
    activeCount += 1
    blocks.append(block)
    return blocks.count - 1
  }
  
  /// Removes the block at a specific index.
  ///
  /// - note: Removing a block does not invalidate other indexes.
  mutating func remove(at index: Int) {
    activeCount -= 1
    blocks[index] = nil
  }
  
  /// Invokes all valid blocks with the parameter `value`
  func invoke(with value: Value) {
    for block in blocks {
      block?(value)
    }
  }
  
  var isEmpty: Bool {
    return activeCount == 0
  }
}

public protocol AnySubscription { }

public protocol Publisher {
  associatedtype Value
  typealias SubscriptionBlock = (Result<Value>) -> Void
  
  func subscribe(_ block: @escaping SubscriptionBlock) -> AnySubscription
  func removeSubscription(_ subscription: AnySubscription)
}

/// Publishes changes to values.
public class SimplePublisher<Value>: Publisher {
  
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
  
  /// All subscribers.
  private var subscribers = BlockArray<Result<Value>>()
  
  /// Publish a value to all subscribers.
  ///
  /// - note: All subscriber blocks are called synchronously on this thread.
  /// - parameter value: The value to publish to subscribers.
  public func publishValue(_ value: Value) {
    subscribers.invoke(with: .success(value))
  }
  
  public func publishResult(_ result: Result<Value>) {
    subscribers.invoke(with: result)
  }
  
  /// Adds a subscriber.
  ///
  /// - parameter block: The block to invoke with new values
  public func subscribe(_ block: @escaping (Result<Value>) -> Void) -> AnySubscription {
    return Subscription(publisher: self, blockIndex: subscribers.append(block))
  }
  
  /// Removes this subscription. The associated block will not get called on subsequent
  /// `invoke`
  public func removeSubscription(_ subscription: AnySubscription)
  {
    let subscription = subscription as! Subscription
    assert(subscription.publisher === self)
    subscribers.remove(at: subscription.blockIndex)
  }
  
  public var hasActiveSubscribers: Bool {
    return !subscribers.isEmpty
  }
}
