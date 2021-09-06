%%% Copyright 2021 Nomasystems, S.L. http://www.nomasystems.com
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
-module(npqueue_router).

%%% IN/OUT EXPORTS
-export([in/2, in/3]).

%%% MACROS

%%%-----------------------------------------------------------------------------
%%% IN/OUT EXPORTS
%%%-----------------------------------------------------------------------------
in(QueueName, Item) ->
    in(QueueName, Item, fun default_partition_selector/2).

in(QueueName, Item, PartitionSelectorFun) ->
    try
        npqueue_counters:counter_in_add(QueueName),
        SrvPid = route(QueueName, Item, PartitionSelectorFun),
        npqueue_partition_srv:in(SrvPid, Item)
    catch
        error:badarg ->
            {error, {wrong_queue, QueueName}};
        Error:Cause:Args ->
            ct:print("Error: ~p ~n Cause: ~p ~n Args:~p", [Error, Cause, Args])
    end.

%%%-----------------------------------------------------------------------------
%%% INTERNAL FUNCTIONS
%%%-----------------------------------------------------------------------------
route(Name, Item, PartitionSelector) ->
    NumPartitions = npqueue_conf:num_partitions(Name),
    PartitionNum = PartitionSelector(NumPartitions, Item),
    SrvPid = npqueue_conf:partition_server(Name, PartitionNum),
    SrvPid.

default_partition_selector(NumPartitions, _Item) ->
    rand:uniform(NumPartitions).
