# npqueue
![npqueue](https://github.com/nomasystems/npqueue/actions/workflows/build.yml/badge.svg)

`npqueue` is an OTP library to spawn/manage partitioned queues based on processes.

## Setup

Add `npqueue` to your project dependencies.

```erl
%%% e.g., rebar.config
{deps, [
    {npqueue, {git, "git@github.com:nomasystems/npqueue.git", {tag, "1.0.0"}}}
]}.
```

## Features

`npqueue` exposes utilities via its API that allows you to:

| Function | Description |
| --------  | ------------ |
| `npqueue:start_link/4` | Start a queue without rate limit |
| `npqueue:start_link/5` | Start a queue with a custom rate limit |
| `npqueue:in/2` | Insert a `Item` in a queue using the default partition selector |
| `npqueue:in/3` | Insert a `Item` in a queue using a partition selector fun |
| `npqueue:is_empty/1` | Returns if a queue is empty |
| `npqueue:len/1` | Returns the count of `Items` are in a queue| 
| `npqueue:total_in/1` | Returns the count of `Items` added in a queue |
| `npqueue:total_out/1` | Returns the count of `Items` consumed in a queue |
| `npqueue:rps/1` | Returns the current rate limit in rps (requests per second) |
| `npqueue:rps/2` | Changes the current rate limit |

This set of functionalities provides concurrent and performant production/consumption in several concurrent queues.

## Implementation

Each queue, defined by a name, is sustained by a process tree divided in partitions, each partition has it's own partition server and a number of consumers.
When inserting in the queue you can use the default partition selector (random) or use your own partition selector fun in order to place the item where you want. For example you could use a consistent hashing algorithm to place all related items in the same partition to force them to be consumed in order.
Once the partition is selected the item is sent to the partition server and eventually consumed by the consumers of that partition.

We decided to use partitions in order to minimize the single process bottleneck. It is very important to choose a big enough number of partitions and a proper partition selector fun.


## A simple example

```erl
%%% Start a queue with 2 consumers
1> npqueue:start_link(
1>     QueueName      = my_queue,
1>     PartitionCount = 16,
1>     ConsumersCount = 2,
1>     ConsumersFun   = fun(Element) ->
1>         timer:sleep(1000),
1>         my_consumer_fun(Element)
1>     end
1> ).
{ok,<0.185.0>}

%%% Insert elements in the queue
2> npqueue:in(my_queue, element).
ok
3> npqueue:in(my_queue, element_2).
ok
4> npqueue:in(my_queue, element_3).
ok

%%% Inspect the queue
5> npqueue:len(my_queue).
1
6> [{3, element_3}] = npqueue:to_list(my_queue).
[{3,element_3}]

%%% Inspect the queue after all the consumptions
7> timer:sleep(1000).
ok
8> npqueue:len(my_queue).
0
9> npqueue:total_in(my_queue).
3
10> npqueue:total_out(my_queue).
3

%%% Stop the queue
11> npqueue:stop(my_queue).
true
```

## Support

Any doubt or suggestion? Please, check out [our issue tracker](https://github.com/nomasystems/npqueue/issues).