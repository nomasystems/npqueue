# npqueue

`npqueue` application module.

## Types

Name = atom()
PartitionCount = non_neg_integer()
ConsumerCount = non_neg_integer()
ConsumerFun = fun()
StartLinkResult = {ok, Pid} | {ok, Pid, St} | {error, term()}
Pid = pid()
PartitionSelector = fun()
St = term()
Item = term()
Rps = rps()


## Exports

start_link(Name, PartitionCount, ConsumerCount, ConsumerFun) -> StartLinkResult
> Starts a new queue with rps set to infinity

start_link(Name, PartitionCount, ConsumerCount, ConsumerFun, Rps) -> StartLinkResult
> Starts a new queue

stop(Name) -> ok
> Stops the queue

in(Name, Item) -> ok | {error, term()}
> Inserts a new element at the end of the queue

in(Name, Item, PartitionSelector) -> ok | {error, term()}
> Inserts a new element at the end of the queue using the given `PartitionSelector`

is_empty(Name) -> boolean()
> Returns true if the queue is empty and false if not

len(Name) -> non_neg_integer()
> Returns the length of the queue

total_in(Name) -> non_neg_integer()
> Returns the total number of elements inserted to the queue

total_out(Name) -> non_neg_integer()
> Returns the total number of elements consumed from the queue

rps(Name) -> Rps
> Returns the configured rps for the given queue

rps(Name, Rps) -> Rps
> Configures a new rps for the given queue
