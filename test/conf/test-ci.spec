%%% -*- mode:erlang -*-
{config, "test.conf"}.
{alias, test, ".."}.
{suites, test, all}.
%{skip_suites, test, [npqueue_SUITE], "Skip"}.
{skip_cases, test, npqueue_SUITE, [performance], "Not needed for ci"}.



