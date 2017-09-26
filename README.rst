=======
X-Stack
=======

"Build OpenStack via Xenial packages (eerily similar to DevStack, go figure, but only similar)"

A small number of projects that consume OpenStack APIs want to continue to test against
older OpenStack releases that are now EOL in the upstream CI.  The intent is to maintain
backward compatibility with older clouds that may not have been upgraded to recent
releases, so X-Stack is born!

The idea is to build a running all-in-one OpenStack very similar to a DevStack build,
but rather than build from sources we will use pre-existing distro packaging.  As
the Ubuntu Xenial Xerus LTS release includes OpenStack Mitaka packages, and wecurrently
use Xenial as the default OS in the OpenStack CI, we start there.  We anticipate this to
work at least as long as Xenial is in supported LTS status, currently scheduled to
EOL in April of 2021.

The code that makes up X-Stack looks an awful lot like DevStack largely because the initial
author (dtroyer) was also a long-time contributor to DevStack.  Many of the same reasons
for stealing bits from DevStack apply: shell script is a low-level common deployment
that can be used in nearly all deployemnt tools.

Specifically, X-Stack borrows a number of the support functions from DevStack's
``functions-common``, ``inc/*`` and ``lib/*`` files.

At this time, running X-Stack is a matter of running the individual x-*.sh scripts.
We are still in the 'creating the building blocks' phase.
