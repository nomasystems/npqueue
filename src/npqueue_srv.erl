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
-module(npqueue_srv).

-behaviour(gen_server).

%%% START/STOP EXPORTS
-export([start_link/5]).

%%% INIT/TERMINATE EXPORTS
-export([init/1, terminate/2]).

%%% HANDLE MESSAGES EXPORTS
-export([handle_call/3, handle_cast/2, handle_info/2]).

%%% CODE UPDATE EXPORTS
-export([code_change/3]).

%%% MACROS
-define(SRV_NAME(Name), list_to_atom(atom_to_list(Name) ++ "_queue_srv")).

%%% RECORDS
-record(st, {
    name :: atom(),
    function :: function(),
    partition_count :: non_neg_integer()
}).

%%%-----------------------------------------------------------------------------
%%% START/STOP EXPORTS
%%%-----------------------------------------------------------------------------
start_link(Name, PartitionCount, ConsumerCount, ConsumerFun, Rps) ->
    SrvName = ?SRV_NAME(Name),
    gen_server:start_link(
        {local, SrvName}, ?MODULE, [Name, PartitionCount, ConsumerCount, ConsumerFun, Rps], []
    ).

%%%-----------------------------------------------------------------------------
%%% INIT/TERMINATE EXPORTS
%%%-----------------------------------------------------------------------------
init([QueueName, PartitionCount, ConsumerCount, ConsumerFun, Rps]) ->
    process_flag(trap_exit, true),
    nthrottle:start_throttling(QueueName, Rps),
    npqueue_conf:init(QueueName),
    npqueue_counters:init(QueueName),
    npqueue_conf:num_partitions(QueueName, PartitionCount),
    PartitionSrvs = init_partitions(QueueName, ConsumerCount, ConsumerFun, PartitionCount),
    npqueue_conf:partition_servers(QueueName, PartitionSrvs),
    nhooks:do(npqueue, 'init_queue', [QueueName]),
    {ok, #st{
        name = QueueName,
        function = ConsumerFun,
        partition_count = PartitionCount
    }}.

terminate(_Reason, St) ->
    Terminate = fun({_PartitionNum, PartitionSrvPid}) ->
        npqueue_partition_srv:stop(PartitionSrvPid)
    end,
    PartitionServers = npqueue_conf:partition_servers(St#st.name),
    PartitionServersList = maps:to_list(PartitionServers),
    lists:foreach(Terminate, PartitionServersList),
    nhooks:do(npqueue, 'terminate_queue', [St#st.name]),
    npqueue_counters:clear(St#st.name),
    npqueue_conf:clear(St#st.name),
    nthrottle:stop_throttling(St#st.name),
    ok.

%%%-----------------------------------------------------------------------------
%%% HANDLE MESSAGES EXPORTS
%%%-----------------------------------------------------------------------------
handle_call(Req, From, St) ->
    erlang:error(function_clause, [Req, From, St]).

handle_cast(Req, St) ->
    erlang:error(function_clause, [Req, St]).

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
init_partitions(Name, ConsumerCount, ConsumerFun, Count) ->
    init_partitions(Name, ConsumerCount, ConsumerFun, Count, #{}).

init_partitions(_Name, _ConsumerCount, _Fun, 0, Acc) ->
    Acc;
init_partitions(Name, ConsumerCount, Fun, Count, Acc) ->
    PartitionData = new_partition(Name, ConsumerCount, Count, Fun),
    init_partitions(Name, ConsumerCount, Fun, Count - 1, maps:put(Count, PartitionData, Acc)).

new_partition(QueueName, ConsumerCount, PartitionNum, Fun) ->
    QueueNameBin = erlang:atom_to_binary(QueueName),
    SupName = erlang:binary_to_atom(<<QueueNameBin/binary, "-npqueue_partition_sup">>, utf8),
    {ok, PartitionSrvPid} = supervisor:start_child(SupName, [
        QueueName, PartitionNum, ConsumerCount, Fun
    ]),
    PartitionSrvPid.
