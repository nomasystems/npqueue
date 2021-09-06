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
-module(npqueue_counters).

%%% INCLUDE FILES

%%% EXTERNAL EXPORTS
-export([
    init/1,
    clear/1,
    is_empty/1,
    counter_in/1,
    counter_out/1,
    counter_in_add/1,
    counter_out_add/1,
    len/1
]).

%%% MACROS
-define(COUNTERS_KEY(QueueName), {'npqueue_counters', QueueName}).
-define(COUNTER_IN_INDEX, 1).
-define(COUNTER_OUT_INDEX, 2).

%%%-----------------------------------------------------------------------------
%%% EXTERNAL EXPORTS
%%%-----------------------------------------------------------------------------
init(QueueName) ->
    CountersRef = counters:new(2, [write_concurrency]),
    Key = ?COUNTERS_KEY(QueueName),
    persistent_term:put(Key, CountersRef).

clear(QueueName) ->
    Key = ?COUNTERS_KEY(QueueName),
    persistent_term:erase(Key).

counter_in(QueueName) ->
    CountersRef = counters(QueueName),
    counters:get(CountersRef, ?COUNTER_IN_INDEX).

counter_out(QueueName) ->
    CountersRef = counters(QueueName),
    counters:get(CountersRef, ?COUNTER_OUT_INDEX).

counter_in_add(QueueName) ->
    CountersRef = counters(QueueName),
    counters:add(CountersRef, ?COUNTER_IN_INDEX, 1).

counter_out_add(QueueName) ->
    CountersRef = counters(QueueName),
    counters:add(CountersRef, ?COUNTER_OUT_INDEX, 1).

len(QueueName) ->
    CounterOut = counter_out(QueueName),
    CounterIn = counter_in(QueueName),
    CounterIn - CounterOut.

is_empty(QueueName) ->
    Len = len(QueueName),
    Len == 0.

%%%-----------------------------------------------------------------------------
%%% INTERNAL FUNCTIONS
%%%-----------------------------------------------------------------------------
counters(QueueName) ->
    Key = ?COUNTERS_KEY(QueueName),
    persistent_term:get(Key).
