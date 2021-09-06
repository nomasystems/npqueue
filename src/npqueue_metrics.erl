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
-module(npqueue_metrics).

-behaviour(nmetrics_module).

-dialyzer(no_undefined_callbacks).

%%% INCLUDE FILES

%%% BEHAVIOUR CALLBACKS
-export([init/0, terminate/0, metrics/0]).

%%% EXTERNAL EXPORTS
-export([add_queue/1, delete_queue/1, metrics_enabled/0, register/0]).

%%%===================================================================
%%% nmetris_module callbacks
%%%===================================================================
init() ->
    ok.

terminate() ->
    ok.

metrics() ->
    lists:flatten([queues_info()]).

%%%===================================================================
%%% EXTERNAL EXPORTS
%%%===================================================================
add_queue(Queue) ->
    case metrics_enabled() of
        true ->
            OldQueues = persistent_term:get({npqueue, registered_queues}, []),
            NewQueues = [Queue | OldQueues],
            persistent_term:put({npqueue, registered_queues}, NewQueues);
        _ ->
            ok
    end.

delete_queue(Queue) ->
    case metrics_enabled() of
        true ->
            OldQueues = persistent_term:get({npqueue, registered_queues}, []),
            NewQueues = lists:delete(Queue, OldQueues),
            persistent_term:put({npqueue, registered_queues}, NewQueues);
        _ ->
            ok
    end.

%%%===================================================================
%%% Internal functions
%%%===================================================================
queues_info() ->
    Queues = persistent_term:get({npqueue, registered_queues}, []),
    lists:map(fun queue_info/1, Queues).

queue_info(Queue) ->
    Rps =
        case npqueue:rps(Queue) of
            {ok, Atom} when is_atom(Atom) ->
                atom_to_binary(Atom, utf8);
            {ok, Val} ->
                Val;
            _ ->
                <<"error">>
        end,

    Fields = [
        {<<"length">>, npqueue:len(Queue)},
        {<<"rps">>, Rps},
        {<<"total.in">>, npqueue:total_in(Queue)},
        {<<"total.out">>, npqueue:total_out(Queue)}
    ],
    nMetric:tag_set(
        nMetric:field_set(
            nMetric:measurement(
                nMetric:new(),
                <<"erlang.mem_queue">>
            ),
            Fields
        ),
        [{<<"queueName">>, atom_to_binary(Queue, utf8)}, {<<"libraryName">>, <<"npqueue">>}]
    ).

metrics_enabled() ->
    case application:get_env(nmetrics, enabled, undefined) of
        undefined ->
            false;
        Other ->
            Other
    end.

register() ->
    case metrics_enabled() of
        true ->
            nmetrics:register_module(?MODULE),
            ok;
        _ ->
            ok
    end.
