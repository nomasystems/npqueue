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
-module(npqueue_partition_srv_SUITE).

%%% EXTERNAL EXPORTS
-compile([export_all, nowarn_export_all]).

%%%-----------------------------------------------------------------------------
%%% SUITE EXPORTS
%%%-----------------------------------------------------------------------------
all() ->
    [
        handle_unmatched_call,
        handle_unmatched_cast,
        handle_unmatched_message
    ].

%%%-----------------------------------------------------------------------------
%%% INIT SUITE EXPORTS
%%%-----------------------------------------------------------------------------
init_per_suite(Conf) ->
    nct_util:setup_suite(Conf).

%%%-----------------------------------------------------------------------------
%%% END SUITE EXPORTS
%%%-----------------------------------------------------------------------------
end_per_suite(Conf) ->
    nct_util:teardown_suite(Conf).

%%%-----------------------------------------------------------------------------
%%% TEST CASES
%%%-----------------------------------------------------------------------------
handle_unmatched_call() ->
    [{userdata, [{doc, "Tests that the process crashes if called with an unmatched parameter"}]}].

handle_unmatched_call(_Conf) ->
    {ok, Pid} = npqueue_partition_srv:start_link(handle_call, 1, 1, fun io:format/1),
    unlink(Pid),
    catch gen_server:call(Pid, unmatched_call),
    false = is_process_alive(Pid),
    ok.

handle_unmatched_cast() ->
    [{userdata, [{doc, "Tests that the process crashes if cast with an unmatched parameter"}]}].

handle_unmatched_cast(_Conf) ->
    {ok, Pid} = npqueue_partition_srv:start_link(handle_cast, 1, 1, fun io:format/1),
    unlink(Pid),
    Ref = erlang:monitor(process, Pid),
    ok = gen_server:cast(Pid, unmatched_cast),
    receive
        {'DOWN', Ref, _, _, _} -> ok
    after 1000 -> throw(cast_timeout)
    end,
    ok.

handle_unmatched_message() ->
    [{userdata, [{doc, "Tests that the process skips unmatched messages"}]}].

handle_unmatched_message(_Conf) ->
    {ok, Pid} = npqueue_partition_srv:start_link(handle_info, 1, 1, fun io:format/1),
    Pid ! unmatched_message,
    ok = npqueue_partition_srv:stop(Pid).
