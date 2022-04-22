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
-module(npqueue).

%%% START/STOP EXPORTS
-export([start_link/4, start_link/5, stop/1]).

%%% IN/OUT EXPORTS
-export([in/2, in/3]).

%%% UTIL EXPORTS
-export([is_empty/1, len/1, total_in/1, total_out/1, rps/1, rps/2]).

%%% NHOOKS EXPORTS
-export([hooks/0]).

%%%-----------------------------------------------------------------------------
%%% START/STOP EXPORTS
%%%-----------------------------------------------------------------------------
start_link(QueueName, PartitionCount, ConsumerCount, ConsumerFun) ->
    start_link(QueueName, PartitionCount, ConsumerCount, ConsumerFun, infinity).

start_link(QueueName, PartitionCount, ConsumerCount, ConsumerFun, Rps) when
    is_atom(QueueName),
    PartitionCount > 0,
    is_function(ConsumerFun),
    (is_integer(Rps) or is_float(Rps) or (Rps == infinity)),
    (Rps >= 0)
->
    npqueue_sup:start_link(QueueName, PartitionCount, ConsumerCount, ConsumerFun, Rps).

stop(ServerRef) ->
    npqueue_srv:stop(ServerRef).

%%%-----------------------------------------------------------------------------
%%% IN/OUT EXPORTS
%%%-----------------------------------------------------------------------------
in(QueueName, Item) ->
    npqueue_router:in(QueueName, Item).

in(QueueName, Item, PartitionSelectorFun) ->
    npqueue_router:in(QueueName, Item, PartitionSelectorFun).
%%%-----------------------------------------------------------------------------
%%% UTIL EXPORTS
%%%-----------------------------------------------------------------------------
is_empty(QueueName) ->
    npqueue_counters:is_empty(QueueName).

len(QueueName) ->
    npqueue_counters:len(QueueName).

total_in(QueueName) ->
    npqueue_counters:counter_in(QueueName).

total_out(QueueName) ->
    npqueue_counters:counter_out(QueueName).

rps(QueueName) ->
    nthrottle:rps(QueueName).

rps(QueueName, Rps) when
    is_atom(QueueName),
    (is_integer(Rps) or is_float(Rps) or (Rps == infinity)),
    (Rps >= 0)
->
    nthrottle:rps(QueueName, Rps).

hooks() ->
    [
        'init_queue',
        'terminate_queue'
    ].
