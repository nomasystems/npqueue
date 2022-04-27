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
-module(npqueue_conf).

%%% INCLUDE FILES

%%% EXTERNAL EXPORTS
-export([
    init/1,
    clear/1,
    num_partitions/1,
    num_partitions/2,
    partition_server/2,
    partition_servers/1,
    partition_servers/2
]).

%%% MACROS
-define(CONF_KEY(QueueName), {?MODULE, QueueName}).
-define(NUM_PARTITIONS_MAP_KEY, 'num_partitions').
-define(PARTITION_SERVERS_MAP_KEY, 'partition_servers').

%%%-----------------------------------------------------------------------------
%%% EXTERNAL EXPORTS
%%%-----------------------------------------------------------------------------
init(QueueName) ->
    Key = ?CONF_KEY(QueueName),
    Conf = #{?PARTITION_SERVERS_MAP_KEY => #{}},
    persistent_term:put(Key, Conf).

clear(QueueName) ->
    Key = ?CONF_KEY(QueueName),
    persistent_term:erase(Key).

num_partitions(Conf) when is_map(Conf) ->
    #{?NUM_PARTITIONS_MAP_KEY := NumPartitions} = Conf,
    NumPartitions;
num_partitions(QueueName) ->
    Conf = conf(QueueName),
    num_partitions(Conf).

num_partitions(QueueName, NumPartitions) ->
    Key = ?CONF_KEY(QueueName),
    Conf = persistent_term:get(Key),
    NewConf = Conf#{?NUM_PARTITIONS_MAP_KEY => NumPartitions},
    persistent_term:put(Key, NewConf).

partition_server(Conf, PartitionNum) when is_map(Conf) ->
    #{?PARTITION_SERVERS_MAP_KEY := PartitionServers} = Conf,
    #{PartitionNum := Server} = PartitionServers,
    Server;
partition_server(QueueName, PartitionNum) ->
    #{PartitionNum := Server} = partition_servers(QueueName),
    Server.

partition_servers(Conf) when is_map(Conf) ->
    #{?PARTITION_SERVERS_MAP_KEY := PartitionServers} = Conf,
    PartitionServers;
partition_servers(QueueName) ->
    Conf = conf(QueueName),
    partition_servers(Conf).

partition_servers(QueueName, PartitionServers) when is_map(PartitionServers) ->
    Key = ?CONF_KEY(QueueName),
    Conf = persistent_term:get(Key),
    NewConf = Conf#{?PARTITION_SERVERS_MAP_KEY => PartitionServers},
    persistent_term:put(Key, NewConf).

%%%-----------------------------------------------------------------------------
%%% INTERNAL FUNCTIONS
%%%-----------------------------------------------------------------------------
conf(QueueName) ->
    Key = ?CONF_KEY(QueueName),
    persistent_term:get(Key).
