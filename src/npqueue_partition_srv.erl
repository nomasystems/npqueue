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
-module(npqueue_partition_srv).

-behaviour(gen_server).

%%% INCLUDE FILES

%%% START/STOP EXPORTS
-export([start_link/4, stop/1, stop/2]).

%%% INIT/TERMINATE EXPORTS
-export([init/1, terminate/2]).

%%% EXTERNAL EXPORTS
-export([in/2, consumer_waiting/2]).

%%% HANDLE MESSAGES EXPORTS
-export([handle_call/3, handle_cast/2, handle_info/2]).

%%% CODE UPDATE EXPORTS
-export([code_change/3]).

%%% MACROS
-define(SRV_NAME(Name, PartitionNum),
    list_to_atom(
        atom_to_list(Name) ++ "_npqueue_partition_" ++ integer_to_list(PartitionNum) ++ "srv"
    )
).

%%% RECORDS
-record(st, {
    queue_name :: atom(),
    partition_num :: non_neg_integer(),
    function :: function(),
    consumers = [] :: [{pid(), reference()}],
    consumers_waiting = [] :: [pid()],
    items = queue:new() :: term()
}).

%%%-----------------------------------------------------------------------------
%%% START/STOP EXPORTS
%%%-----------------------------------------------------------------------------
start_link(QueueName, PartitionNum, ConsumerCount, ConsumerFun) ->
    SrvName = ?SRV_NAME(QueueName, PartitionNum),
    gen_server:start_link(
        {local, SrvName}, ?MODULE, [QueueName, PartitionNum, ConsumerCount, ConsumerFun], []
    ).

stop(Name, PartitionNum) when is_atom(Name) ->
    gen_server:stop(?SRV_NAME(Name, PartitionNum)).

stop(SrvPid) when is_pid(SrvPid) ->
    gen_server:stop(SrvPid).

%%%-----------------------------------------------------------------------------
%%% INIT/TERMINATE EXPORTS
%%%-----------------------------------------------------------------------------
init([QueueName, PartitionNum, ConsumerCount, ConsumerFun]) ->
    Consumers = init_consumers(QueueName, ConsumerCount, ConsumerFun),
    {ok, #st{
        queue_name = QueueName,
        partition_num = PartitionNum,
        function = ConsumerFun,
        consumers = Consumers
    }}.

terminate(Reason, #st{consumers = Consumers}) ->
    Terminate = fun({ConsumerPid, ConsumerRef}) ->
        demonitor(ConsumerRef),
        ConsumerPid ! {exit, Reason, self()},
        receive
            {ConsumerPid, exit} ->
                ok
        after 5000 ->
            exit(ConsumerPid, kill)
        end
    end,
    lists:foreach(Terminate, Consumers),
    ok.

%%%-----------------------------------------------------------------------------
%%% EXTERNAL EXPORTS
%%%-----------------------------------------------------------------------------
in(PartitionSrv, Item) ->
    gen_server:cast(PartitionSrv, {in, Item}).

consumer_waiting(PartitionSrv, ConsumerPid) ->
    gen_server:cast(PartitionSrv, {consumer_waiting, ConsumerPid}).

%%%-----------------------------------------------------------------------------
%%% HANDLE MESSAGES EXPORTS
%%%-----------------------------------------------------------------------------
handle_call(Req, From, St) ->
    erlang:error(function_clause, [Req, From, St]).

handle_cast({consumer_waiting, ConsumerPid}, #st{items = Items} = St) ->
    case queue:out(Items) of
        {{value, Item}, NewItems} ->
            send_to_consumer(Item, ConsumerPid),
            {noreply, St#st{items = NewItems}};
        {empty, Items} ->
            ConsumersWaiting = [ConsumerPid | St#st.consumers_waiting],
            {noreply, St#st{consumers_waiting = ConsumersWaiting}}
    end;
handle_cast({in, Item}, #st{items = Items, consumers_waiting = ConsumersWaiting} = St) ->
    case {queue:is_empty(Items), ConsumersWaiting} of
        {true, [ConsumerPid | RestConsumersWaiting]} ->
            send_to_consumer(Item, ConsumerPid),
            {noreply, St#st{consumers_waiting = RestConsumersWaiting}};
        {_, _} ->
            NewItems = queue:in(Item, Items),
            {noreply, St#st{items = NewItems}}
    end;
handle_cast(Req, St) ->
    erlang:error(function_clause, [Req, St]).

handle_info(
    {'DOWN', ConsumerMonRef, process, _Object, _Info},
    #st{consumers = Consumers, queue_name = QueueName, function = Function} = St
) ->
    case lists:keytake(ConsumerMonRef, 2, Consumers) of
        false ->
            {noreply, St};
        {value, {_ConsumerPid, ConsumerMonRef}, RestConsumers} ->
            erlang:demonitor(ConsumerMonRef),
            Consumer = init_consumer(QueueName, Function),
            {noreply, St#st{consumers = [Consumer | RestConsumers]}}
    end;
handle_info(_Info, St) ->
    {noreply, St}.

%%%-----------------------------------------------------------------------------
%%% CODE UPDATE EXPORTS
%%%-----------------------------------------------------------------------------
code_change(_OldVsn, St, _Extra) ->
    {ok, St}.

%%%-----------------------------------------------------------------------------
%%% INTERNAL FUNCTIONS
%%%-----------------------------------------------------------------------------
init_consumers(Name, ConsumerCount, Fun) ->
    init_consumers(Name, ConsumerCount, Fun, []).

init_consumers(_Name, 0, _Fun, Acc) ->
    Acc;
init_consumers(Name, ConsumerCount, Fun, Acc) ->
    Consumer = init_consumer(Name, Fun),
    init_consumers(Name, ConsumerCount - 1, Fun, [Consumer | Acc]).

init_consumer(Name, Fun) ->
    {ok, {ConsumerPid, ConsumerMonRef}} = npqueue_consumer:start_monitoring(Name, Fun),
    {ConsumerPid, ConsumerMonRef}.

send_to_consumer(Item, ConsumerPid) ->
    ConsumerPid ! {consume, Item}.
