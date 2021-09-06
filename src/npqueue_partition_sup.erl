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
-module(npqueue_partition_sup).
-behaviour(supervisor).

%%% INCLUDE FILES
-include_lib("kernel/include/logger.hrl").

%%% START/STOP EXPORTS
-export([start_link/4]).

%%% INTERNAL EXPORTS
-export([init/1]).

%%% MACROS

%%%-----------------------------------------------------------------------------
%%% START/STOP EXPORTS
%%%-----------------------------------------------------------------------------
start_link(QueueName, PartitionCount, ConsumerCount, ConsumerFun) ->
    QueueNameBin = erlang:atom_to_binary(QueueName),
    SupName = erlang:binary_to_atom(<<QueueNameBin/binary, "-npqueue_partition_sup">>, utf8),
    supervisor:start_link({local, SupName}, ?MODULE, [
        QueueName, PartitionCount, ConsumerCount, ConsumerFun
    ]).

%%%-----------------------------------------------------------------------------
%%% INTERNAL EXPORTS
%%%-----------------------------------------------------------------------------
init([_QueueName, _PartitionCount, _ConsumerCount, _ConsumerFun]) ->
    {ok, {{simple_one_for_one, 2, 10}, [worker(npqueue_partition_srv, npqueue_partition_srv, [])]}}.

%%%-----------------------------------------------------------------------------
%%% CHILD SPEC FUNCTIONS
%%%-----------------------------------------------------------------------------
worker(Id, Mod, Args) ->
    worker(Id, Mod, Args, transient).

worker(Id, Mod, Args, Restart) ->
    {Id, {Mod, start_link, Args}, Restart, 5000, worker, [Mod]}.

%%%-----------------------------------------------------------------------------
%%% INTERNAL FUNCTIONS
%%%-----------------------------------------------------------------------------
