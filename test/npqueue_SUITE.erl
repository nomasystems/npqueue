%%% Copyright 2022 Nomasystems, S.L. http://www.nomasystems.com
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
-module(npqueue_SUITE).

%%% EXTERNAL EXPORTS
-compile([export_all, nowarn_export_all]).

%%%-----------------------------------------------------------------------------
%%% SUITE EXPORTS
%%%-----------------------------------------------------------------------------
all() ->
    [
        api,
        force_order_using_partitions,
        hooks,
        throttling,
        throttling_updates,
        one_producer,
        one_consumer,
        performance
    ].

%%%-----------------------------------------------------------------------------
%%% INIT SUITE EXPORTS
%%%-----------------------------------------------------------------------------
init_per_suite(Conf) ->
    nct_util:setup_suite(Conf).

%%%-----------------------------------------------------------------------------
%%% END SUITE EXPORTS
%%%-----------------------------------------------------------------------------
end_per_suite(Conf) ->
    nct_util:teardown_suite(Conf).

%%%-----------------------------------------------------------------------------
%%% INIT CASE EXPORTS
%%%-----------------------------------------------------------------------------
init_per_testcase(Case, Conf) ->
    ct:print("Starting test case ~p", [Case]),
    nct_util:init_traces(Case),
    Conf.

%%%-----------------------------------------------------------------------------
%%% END CASE EXPORTS
%%%-----------------------------------------------------------------------------
end_per_testcase(Case, Conf) ->
    nct_util:end_traces(Case),
    ct:print("Test case ~p completed", [Case]),
    Conf.

%%%-----------------------------------------------------------------------------
%%% TEST CASES
%%%-----------------------------------------------------------------------------
api() ->
    [{userdata, [{doc, "Exported functions in npqueue."}]}].

api(_Conf) ->
    Name = test_queue,
    Client = self(),
    ConsumerFun = fun(X) ->
        timer:sleep(rand:uniform(100)),
        io:format("consumer out: ~p~n", [X]),
        Client ! {out, X},
        maybe_die()
    end,
    PartitionCount = 10,
    ConsumerCount = 5,
    CountIn = PartitionCount * 10,
    ProducerIn = fun(X) -> npqueue:in(Name, X) end,
    {ok, _QueuePid} = npqueue:start_link(Name, PartitionCount, ConsumerCount, ConsumerFun),

    true = npqueue:is_empty(Name),
    0 = npqueue:len(Name),
    0 = npqueue:total_in(Name),
    0 = npqueue:total_out(Name),
    Rps = 1000,
    ok = npqueue:rps(Name, Rps),
    lists:foreach(ProducerIn, lists:seq(1, CountIn)),
    CountIn = npqueue:total_in(Name),
    false = npqueue:is_empty(Name),
    {error, {wrong_queue, wrong_queue_name}} = npqueue:in(wrong_queue_name, 1),
    receive_out(CountIn),
    true = npqueue:is_empty(Name),

    {ok, Rps} = npqueue:rps(Name),
    npqueue:stop(Name),
    ok.

hooks() ->
    [{userdata, [{doc, "Tests that hooks are getting called."}]}].

hooks(_Conf) ->
    TestPid = self(),
    Hooks = npqueue:hooks(),
    [nhooks:register_task(npqueue, H, fun(P) -> TestPid ! {hook, H, P} end) || H <- Hooks],
    Name = test_queue_hooks,
    ReceiveQueueHook = fun(Hook) ->
        receive
            {hook, Hook, Name} -> ok
        after 2000 -> throw({not_received, Hook})
        end
    end,
    {ok, _QueuePid} = npqueue:start_link(Name, 1, 1, fun(_) -> ok end),
    ok = ReceiveQueueHook(init_queue),
    npqueue:stop(Name),
    ok = ReceiveQueueHook(terminate_queue).

force_order_using_partitions() ->
    [{userdata, [{doc, "Exported functions in npqueue."}]}].

force_order_using_partitions(_Conf) ->
    Name = test_queue,
    Client = self(),
    ConsumerFun = fun(X) ->
        io:format("consumer out: ~p~n", [X]),
        Client ! {out, X, erlang:timestamp()}
    end,
    PartitionCount = 10,
    ConsumerCount = 1,
    CountIn = 10000,
    PartitionSelector = fun(_PartitionCount, _Item) -> 1 end,
    ProducerIn = fun(X) ->
        npqueue:in(Name, X, PartitionSelector)
    end,
    {ok, _QueuePid} = npqueue:start_link(Name, PartitionCount, ConsumerCount, ConsumerFun),

    true = npqueue:is_empty(Name),
    0 = npqueue:len(Name),
    0 = npqueue:total_in(Name),
    0 = npqueue:total_out(Name),
    Rps = 10000,
    ok = npqueue:rps(Name, Rps),
    lists:foreach(ProducerIn, lists:seq(1, CountIn)),
    CountIn = npqueue:total_in(Name),
    false = npqueue:is_empty(Name),
    {error, {wrong_queue, wrong_queue_name}} = npqueue:in(wrong_queue_name, 1),
    receive_out_checking_order(CountIn, -1),
    true = npqueue:is_empty(Name),
    {ok, Rps} = npqueue:rps(Name),
    npqueue:stop(Name),
    ok.

throttling() ->
    [{userdata, [{doc, "Exported functions in npqueue."}]}].

throttling(_Conf) ->
    Name = test_queue,
    Client = spawn_link(fun() -> client_fun(1) end),
    ConsumerFun = fun(X) ->
        Client ! {out, X}
    end,
    PartitionCount = 100,
    ConsumerCount = 10,
    Rps = 5000,
    CountIn = ConsumerCount * 1000,
    ProducerIn = fun(X) -> npqueue:in(Name, X) end,
    {ok, _QueuePid} = npqueue:start_link(Name, PartitionCount, ConsumerCount, ConsumerFun, Rps),

    true = npqueue:is_empty(Name),
    Start = erlang:timestamp(),
    lists:foreach(ProducerIn, lists:seq(1, CountIn)),
    EstimatedRps = check_rps(Client, Start, CountIn div Rps),
    io:format("Estimated rps (set  to  ~p): ~p~n", [Rps, EstimatedRps]),
    ct:print("Estimated rps (set  to  ~p): ~p~n", [Rps, EstimatedRps]),
    timer:sleep(1000),
    true = npqueue:is_empty(Name),
    npqueue:stop(Name),
    ok.

throttling_updates() ->
    [{userdata, [{doc, "Exported functions in npqueue."}]}].

throttling_updates(_Conf) ->
    io:format("1~n"),
    ct:print("1~n"),
    Name = test_queue,
    Self = self(),
    ConsumerFun = fun(X) ->
        Self ! {out, X}
    end,
    PartitionCount = 10,
    ConsumerCount = 5,
    Rps = 1,
    CountIn = PartitionCount * 10,
    ProducerIn = fun(X) -> npqueue:in(Name, X) end,
    {ok, _QueuePid} = npqueue:start_link(Name, PartitionCount, ConsumerCount, ConsumerFun, Rps),

    true = npqueue:is_empty(Name),
    lists:foreach(ProducerIn, lists:seq(1, CountIn)),
    timer:sleep(1000),
    npqueue:rps(Name, 5),
    timer:sleep(1000),
    npqueue:rps(Name, infinity),
    receive_out(CountIn),
    true = npqueue:is_empty(Name),
    npqueue:stop(Name),
    ok.

client_fun(N) ->
    receive
        {count, From} ->
            From ! {count, N},
            client_fun(N);
        {out, _X} ->
            client_fun(N + 1)
    end.

check_rps(Client, StartTime, Intervals) ->
    Self = self(),
    Checker = spawn_link(fun() -> check_rps(Self, Client, StartTime, Intervals, 1, []) end),
    receive
        {finished, Checker, Stats} ->
            Stats
    end.

check_rps(From, _Client, _StartTime, Intervals, Interval, Acc) when Intervals == (Interval - 1) ->
    From ! {finished, self(), Acc};
check_rps(From, Client, StartTime, Intervals, Interval, _Acc) ->
    wait_next_check(StartTime, Interval),
    Client ! {count, self()},
    receive
        {count, N} ->
            Now = erlang:timestamp(),
            Ellapsed = round(timer:now_diff(Now, StartTime) / 1000),
            Rps = round(N / (Ellapsed / 1000)),
            check_rps(From, Client, StartTime, Intervals, Interval + 1, Rps)
    end.

wait_next_check(StartTime, Interval) ->
    Now = erlang:timestamp(),
    Ellapsed = round(timer:now_diff(Now, StartTime) / 1000),
    timer:sleep(1000 * Interval - Ellapsed).

maybe_die() ->
    N = rand:uniform(100),
    if
        N > 90 ->
            erlang:exit(self(), kill);
        true ->
            ok
    end.

receive_out(Count) ->
    receive_out(Count, lists:seq(1, Count)).

receive_out(0, _LeftItems) ->
    ok;
receive_out(Count, LeftItems) ->
    receive
        {out, X} ->
            T = erlang:system_time(milli_seconds),
            NewLeftItems = lists:sort(lists:delete(X, LeftItems)),
            ct:print("[~p] received out: ~p~n", [T, X]),
            receive_out(Count - 1, NewLeftItems)
    end.

receive_out_checking_order(0, _LastItem) ->
    ok;
receive_out_checking_order(Count, LastItem) ->
    receive
        {out, X, Timestamp} ->
            ct:print("[~p] received out: ~p~n", [Timestamp, X]),
            case X >= LastItem of
                true ->
                    ok;
                false ->
                    ct:fail("Items are not being received in order")
            end,
            receive_out_checking_order(Count - 1, X)
    end.

one_consumer() ->
    [{userdata, [{doc, "Tests with one consumer and many producers."}]}].

one_consumer(_Conf) ->
    Name = test_queue,
    Partitions = 1,
    Consumers = 1,
    Producers = ct:get_config(producers, 1000),
    Items = ct:get_config(items, 1000),
    Counter = counters:new(1, [write_concurrency]),
    Consume = fun(_Item) ->
        counters:add(Counter, 1, 1)
    end,
    ets:new(summary, [public, ordered_set, named_table]),
    ets:new(items, [public, bag, named_table]),
    {ok, _QueuePid} = npqueue:start_link(Name, Partitions, Consumers, Consume),

    ct:print("Queue with 1 consumer ready..."),
    Producer = fun(N) -> spawn(fun() -> producer(Name, N, Items) end) end,
    lists:foreach(Producer, lists:seq(1, Producers)),
    ct:print("~p producers created...", [Producers]),
    Total = Producers * Items,
    IsAllConsumed = fun() ->
        case counters:get(Counter, 1) of
            Total ->
                true;
            Other ->
                ct:print("Current consumed: ~p of ~p", [Other, Total]),
                false
        end
    end,
    wait_true(IsAllConsumed),
    0 = npqueue:len(Name),
    Total = npqueue:total_in(Name),
    Total = npqueue:total_out(Name),
    ct:print("All ~p items processed", [Total]),
    npqueue:stop(Name),
    ok.

one_producer() ->
    [{userdata, [{doc, "Tests with one producer and many consumers."}]}].

one_producer(_Conf) ->
    Name = test_queue,
    Partitions = ct:get_config(partitions, 1000),
    Consumers = ct:get_config(consumers, 10),
    Producers = 1,
    Items = ct:get_config(items, 1000),
    Counter = counters:new(1, [write_concurrency]),
    Consume = fun(_Item) ->
        counters:add(Counter, 1, 1)
    end,
    ets:new(summary, [public, ordered_set, named_table]),
    ets:new(items, [public, bag, named_table]),
    {ok, _QueuePid} = npqueue:start_link(Name, Partitions, Consumers, Consume),

    ct:print("~p consumer ready...", [Consumers]),
    spawn(fun() -> producer(Name, 1, Items) end),
    ct:print("1 producer created..."),
    Total = Producers * Items,
    IsAllConsumed = fun() ->
        case counters:get(Counter, 1) of
            Total ->
                true;
            Other ->
                ct:print("Current consumed: ~p of ~p", [Other, Total]),
                false
        end
    end,
    wait_true(IsAllConsumed),
    0 = npqueue:len(Name),
    Total = npqueue:total_in(Name),
    Total = npqueue:total_out(Name),
    ct:print("No duplicated items"),
    ct:print("All ~p items processed", [Total]),
    npqueue:stop(Name),
    ok.

performance() ->
    [{userdata, [{doc, "Tests the performance."}]}].

performance(_Conf) ->
    Name = test_queue,
    Partitions = ct:get_config(partitions, 1000),
    Consumers = ct:get_config(consumers, 10),
    Producers = ct:get_config(producers, 1000),
    Items = ct:get_config(items, 1000),
    Counter = counters:new(1, [write_concurrency]),
    TotalSum = (lists:sum(lists:seq(1, Producers)) * Items),
    Consume = fun({N, _Count}) ->
        counters:add(Counter, 1, N)
    end,
    {ok, _QueuePid} = npqueue:start_link(Name, Partitions, Consumers, Consume),

    SecondsBefore = calendar:datetime_to_gregorian_seconds(calendar:universal_time()),
    ct:print("~p consumers ready...", [Consumers]),
    Producer = fun(N) -> spawn(fun() -> producer(Name, N, Items) end) end,
    lists:foreach(Producer, lists:seq(1, Producers)),
    ct:print("~p producers created...", [Producers]),
    Total = Producers * Items,
    IsAllConsumed = fun() ->
        case counters:get(Counter, 1) of
            TotalSum ->
                true;
            Other ->
                ct:print("Current num: ~p of ~p", [Other, TotalSum]),
                false
        end
    end,
    wait_true(IsAllConsumed),
    0 = npqueue:len(Name),
    Total = npqueue:total_in(Name),
    Total = npqueue:total_out(Name),
    SecondsAfter = calendar:datetime_to_gregorian_seconds(calendar:universal_time()),
    Seconds = SecondsAfter - SecondsBefore,
    ct:print("All ~p items processed in ~p seconds! (~p items/sec)", [
        Total, Seconds, Total div Seconds
    ]),
    npqueue:stop(Name),
    ok.

producer(_Name, _N, 0) ->
    ok;
producer(Name, N, Count) ->
    npqueue:in(Name, {N, Count}),
    producer(Name, N, Count - 1).

wait_true(Fun) ->
    case Fun() of
        true ->
            ok;
        false ->
            timer:sleep(1000),
            wait_true(Fun)
    end.

times(0, _Fun) ->
    ok;
times(N, Fun) ->
    Fun(),
    times(N - 1, Fun).
