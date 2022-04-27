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
-module(npqueue_consumer).

%%% INCLUDE FILES
-include_lib("kernel/include/logger.hrl").

%%% START/STOP EXPORTS
-export([start_monitoring/2]).

%%% INTERNAL EXPORTS
-export([wait_for_consuming/3]).

%%%-----------------------------------------------------------------------------
%%% START/STOP EXPORTS
%%%-----------------------------------------------------------------------------
start_monitoring(QueueName, Fun) ->
    {Pid, MonRef} = erlang:spawn_opt(?MODULE, wait_for_consuming, [self(), QueueName, Fun], [
        monitor, {fullsweep_after, 10}
    ]),
    {ok, {Pid, MonRef}}.

%%%-----------------------------------------------------------------------------
%%% INTERNAL FUNCTIONS
%%%-----------------------------------------------------------------------------
wait_for_consuming(Parent, QueueName, Fun) ->
    npqueue_partition_srv:consumer_waiting(Parent, self()),
    receive
        {consume, Item} ->
            npqueue_counters:counter_out_add(QueueName),
            consume(Item, QueueName, Fun);
        {exit, Reason} ->
            exit(Reason);
        {exit, Reason, From} ->
            From ! {self(), exit},
            exit(Reason)
    end,
    wait_for_consuming(Parent, QueueName, Fun).

consume(Item, QueueName, Fun) ->
    case nthrottle:throttle(QueueName, {self(), throttle_consume}) of
        ok ->
            do_consume(Item, QueueName, Fun);
        rps_exceeded ->
            receive
                throttle_consume ->
                    do_consume(Item, QueueName, Fun)
            end
    end.

do_consume(Item, QueueName, Fun) ->
    try
        Fun(Item)
    catch
        Class:Reason:Stacktrace ->
            ?LOG_ERROR("Error consuming the queue ~p. Error: ~p:~p. Stacktrace: ~p", [
                QueueName,
                Class,
                Reason,
                Stacktrace
            ]),
            erlang:raise(Class, Reason, Stacktrace)
    end.
