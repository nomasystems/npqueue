{logdir, "log"}.
{config, "test.cfg"}.
{define, 'TestDir', ".."}.
{suites, 'TestDir', all}.
{ct_hooks, [{cth_surefire, [{path, "report.xml"}]}]}.
{skip_cases, test, npqueue_SUITE, [performance], "Not needed for ci"}.
