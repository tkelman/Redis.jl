# Redis.jl

Redis.jl is a fully-featured Redis client for the Julia programming language. The implementation is an attempt at an easy to understand, minimalistic API that mirrors actual Redis commands as closely as possible.

## Basics

The Redis.jl API resides in the `Redis` module.

```
using Redis
```

The main entrypoint into the API is the `RedisConnection`, which represents a stateful TCP connection to a single Redis server instance. A single constructor allows the user to set all parameters while supplying the usual Redis defaults. Once a `RedisConnection` has been created, it can be used to access any of the expected Redis commands.

```
conn = RedisConnection() # host=127.0.0.1, port=6379, db=0, no password
# conn = RedisConnection(host="192.168.0.1", port=6380, db=15, password="supersecure")

set(conn, "foo", "bar")
get(conn, "foo") # Returns "bar"
```

For any Redis command `x`, the Julia function to call that command is `x`. Redis commands with spaces in them have their spaces replaced with underscores (`_`). For those already familiar with available Redis commands, this convention should make the API relatively straightforward to understand. There are two exceptions to this convention due to conflicts with Julia:

* The _type_ key command is `keytype`
* The _eval_ scripting command is `evalscript`

When the user is finished interacting with Redis, the connection should be destroyed to prevent resource leaks:

```
disconnect(conn)
```

The `disconnect` function can be used with any of the connection types detailed below.

### Commands with options

Some Redis commands have a more complex syntax that allows for options to be passed to the command. Redis.jl supports these options through the use of a final varargs parameter to those functions (for example, `scan`). In these cases, the options should be passed as individual strings at the end of the function.

```
scan(conn, 0, "match", "foo*")
```

If users are interested, the API could be improved to provide custom functions for these complex commands.

An exception to this option syntax are the functions `zinterstore` and `zunionstore`, which have specific implementations to allow for ease of use due to their greater complexity.

## Transactions

Redis.jl supports MULTI/EXEC transactions through two methods: using a `RedisConnection` directly or using a specialized `TransactionConnection` derived from a parent connection.

### Transactions using the RedisConnection

If the user wants to build a transaction a single time and execute it on the server, the simplest way to do so is to send the commands as you would at the Redis cli.

```
multi(conn)
set(conn, "foo", "bar")
get(conn, "foo") # Returns "QUEUED"
exec(conn) # Returns ["OK", "bar"]
get(conn, "foo") # Returns "bar"
```

It is important to note that after the final call to `exec`, the RedisConnection is returned to a 'normal' state.

### Transactions using the TransactionConnection

If the user is planning on using multiple transactions on the same connection, it may make sense for the user to keep a separate connection for transactional use. The `TransactionConnection` is almost identical to the `RedisConnection`, except that it is always in a `MULTI` block. The user should never manually call `multi` with a `TransactionConnection`.

```
trans = open_transaction(conn)
set(trans, "foo", "bar")
get(trans, "foo") # Returns "QUEUED"
exec(trans) # Returns ["OK", "bar"]
get(trans, "foo") # Returns "QUEUED"
multi(trans) # Throws a ServerException
```

Notice the subtle difference from the previous example; after calling `exec`, the `TransactionConnection` is placed into another `MULTI` block rather than returning to a 'normal' state as the `RedisConnection` does.

## Pub/sub

Redis.jl provides full support for Redis pub/sub. Publishing is accomplished by using the command as normal:

```
publish(conn, "channel", "hello, world!")
```

Subscriptions are handled using the `SubscriptionConnection`. Similar to the `TransactionConnection`, the `SubscriptionConnection` is constructed from an existing `RedisConnection`. Once created, the `SubscriptionConnection` maintains a simple event loop that will call the user's defined function whenever a message is received on the specified channel.

```
x = Any[]
f(y) = push!(x, y)
sub = open_subscription(conn)
subscribe(sub, "baz", f)
publish(conn, "baz", "foobar")
x # Returns ["foobar"]
```

Multiple channels can be subscribed together by providing a `Dict{String, Function}`.

```
x = Any[]
f(y) = push!(x, y)
sub = open_subscription(conn)
d = Dict{String, Function}({"baz" => f, "bar" => println})
subscribe(sub, d)
publish(conn, "baz", "foobar")
x # Returns ["foobar"]
publish(conn, "bar", "anything") # "anything" written to stdout
```

Pattern subscription works in the same way through use of the `psubscribe` function. Channels can be unsubscribed through `unsubscribe` and `punsubscribe`.

Note that the async event loop currently runs until the `SubscriptionConnection` is disconnected, regardless of how many subscriptions the client has active. Event loop error handling should be improved in an update to the API.

### Subscription error handling

When a `SubscriptionConnection` instance is created via `open_subscription`, it spawns a routine that runs in the background to process events received from the server. In the case that Redis.jl encounters an error within this loops, the default behavior is to disregard the error and continue on. If the user would like finer control over this error handling, `open_subscription` accepts an optional `Function` parameter as its final argument. If this is provided, Redis.jl will call the provided function passing it the caught `Exception` as its only parameter.

## Sentinel

Redis.jl also provides functionality for interacting with Redis Sentinel instances through the `SentinelConnection`. All Sentinel functionality other than `ping` is implemented through the `sentinel_` functions:

```
sentinel = SentinelConnection() # Constructor has the same options as RedisConnection
sentinel_masters(sentinel) # Returns an Array{Dict{String, String}} of master info
```

`SentinelConnection` is also `SubscribableConnection`, allowing the user to build a `SubscriptionConnection` for monitoring cluster health through Sentinel messages. See [the Redis Sentinel documentation](http://redis.io/topics/sentinel) for more information.

## Notes

Actual API usage can be found in test/runtests.jl.


[![Build Status](https://travis-ci.org/jkaye2012/Redis.jl.svg?branch=master)](https://travis-ci.org/jkaye2012/Redis.jl)
