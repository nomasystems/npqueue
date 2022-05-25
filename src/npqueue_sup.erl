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
-module(npqueue_sup).
-behaviour(supervisor).

%%% START/STOP EXPORTS
-export([start_link/5, stop/1]).

%%% INTERNAL EXPORTS
-export([init/1]).

%%% MACROS
-define(SUP_NAME(QueueName), erlang:binary_to_atom(<<QueueName/binary, "-npqueue_sup">>, utf8)).

%%%-----------------------------------------------------------------------------
%%% START/STOP EXPORTS
%%%-----------------------------------------------------------------------------
start_link(QueueName, PartitionCount, ConsumerCount, ConsumerFun, Rps) ->
    QueueNameBin = erlang:atom_to_binary(QueueName, utf8),
    SupName = ?SUP_NAME(QueueNameBin),
    {ok, Pid} = supervisor:start_link({local, SupName}, ?MODULE, [
        QueueName, PartitionCount, ConsumerCount, ConsumerFun, Rps
    ]),
    {ok, Pid}.

stop(QueueName) ->
    QueueNameBin = erlang:atom_to_binary(QueueName, utf8),
    case erlang:whereis(?SUP_NAME(QueueNameBin)) of
        undefined ->
            {error, {not_found, QueueName}};
        Pid ->
            erlang:exit(Pid, normal)
    end.

%%%-----------------------------------------------------------------------------
%%% INTERNAL EXPORTS
%%%-----------------------------------------------------------------------------
init([QueueName, PartitionCount, ConsumerCount, ConsumerFun, Rps]) ->
    {ok,
        {{one_for_one, 2, 10}, [
            partition_supervisor(QueueName, PartitionCount, ConsumerCount, ConsumerFun),
            server(QueueName, PartitionCount, ConsumerCount, ConsumerFun, Rps)
        ]}}.

%%%-----------------------------------------------------------------------------
%%% CHILD SPEC FUNCTIONS
%%%-----------------------------------------------------------------------------
supervisor(Id, Mod, Args) ->
    {Id, {Mod, start_link, Args}, transient, 10000, supervisor, [Mod]}.

worker(Id, Mod, Args) ->
    worker(Id, Mod, Args, transient).

worker(Id, Mod, Args, Restart) ->
    {Id, {Mod, start_link, Args}, Restart, 5000, worker, [Mod]}.

%%%-----------------------------------------------------------------------------
%%% INTERNAL FUNCTIONS
%%%-----------------------------------------------------------------------------
server(QueueName, PartitionCount, ConsumerCount, ConsumerFun, Rps) ->
    QueueNameBin = erlang:atom_to_binary(QueueName, utf8),
    Id = <<QueueNameBin/binary, "-npqueue_srv">>,
    worker(Id, npqueue_srv, [QueueName, PartitionCount, ConsumerCount, ConsumerFun, Rps]).

partition_supervisor(QueueName, PartitionCount, ConsumerCount, ConsumerFun) ->
    QueueNameBin = erlang:atom_to_binary(QueueName, utf8),
    Id = <<QueueNameBin/binary, "-npqueue_partition_sup">>,
    supervisor(Id, npqueue_partition_sup, [QueueName, PartitionCount, ConsumerCount, ConsumerFun]).
