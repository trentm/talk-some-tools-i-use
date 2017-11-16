
# slide: some tools I use

XXX link to slides on trentm.com, and repo


# HISTORY

# slide: History: json and sdc-imgapi

Writing tools at Joyent started for me with `json` and `sdc-imgapi`.
This is how you used to list IMGAPI's images:

    $ curl -i -sS -H accept:application/json http://10.99.99.14/images
    [{"name":"smartos","version":"1.6.3","uuid":...

# slide: History: *json* and sdc-imgapi

    $ curl -sS -H accept:application/json http://10.99.99.14/images
    [{"name":"smartos","version":"1.6.3","uuid":...

    $ curl ... http://10.99.99.14/images | nicerest
    [
      {
        "name": "smartos",
        "version": "1.6.3",
    ...

Add streaming, filtering, lookups, etc. -> `s/nicerest/json/`.
"Because screw SEO." -- Jim Pick

http://trentm.com/json/

# slide: History: json and *sdc-imgapi*

    $ curl -sS -H accept:application/json http://10.99.99.14/images
    [{"name":"smartos","version":"1.6.3","uuid":...

    $ sdc-imgapi /images
    [
      {
        "name": "smartos",
        "version": "1.6.3",
    ...



# ISSUES

# slide: The story

We'll walk through fixing a (made up) bug in PAPI.


# slide: `jirash issue create PROJECT`

Basically every Joyent change should have a JIRA issue, so let's create one:

    $ npm install -g jirash
    $ jirash issue create PAPI
    ... write title and desc in $EDITOR ...

*Caveat*: This was broken by the jira.joyent.us update.
I'll fix it in TRITON-12.


# slide: `jirash issue get ISSUE`

Or perhaps the issue already exists and you just want to look it up:

    $ jirash issue get PAPI-144
    PAPI-144 that thing is broken (doogle -> trent.mick, ...)

Shortcut:

    $ jirash PAPI-144
    PAPI-144 that thing is broken



# CORES

# slide: `thoth debug DUMP`

Debugging. Now you have to figure out what is going on.

Perhaps there is a core file in thoth:

    $ thoth debug DUMP

# slide: manta dead drop

Perhaps someone has a core file to give you, but not where thoth can be used.
You can give them a Manta dead drop link to which to upload:

Example:

    $ msign -e $(date -v+1d "+%s") -m PUT /trent.mick/stor/tmp/the.core
    https://us-east.manta.joyent.com/trent.mick/stor/tmp/the.core?alg...

Then that someone can:

    curl -k -T the.core \
        'https://us-east.manta.joyent.com/trent.mick/stor/tmp/the.core?alg...'

# slide: `mdb ...`

And then you can debug it with mdb:

    mlogin /trent.mick/stor/tmp/the.core
    mdb $MANTA_INPUT_FILE


# slide: Recent crashes in JPC and SPC

You could also look for recent crashes in JPC and SPC

    thoth info mtime=1d \
        | json -g -e '
            this.short = this.id.slice(0,12);
            this.isotime = new Date(this.time * 1000).toISOString();
            this.fmri = this.properties.fmri || "-";
            this.dc = (this.properties.sysinfo && this.properties.sysinfo.Datacenter_Name || "(unknown dc)");
            this.host = (this.properties.sysinfo && this.properties.sysinfo.Hostname || "(unknown hostname)");' -a short isotime dc host fmri cmd ticket


# slide: BONUS: `tabula --flip`

You don't have a core.

    $ npm install -g tabula
    $ tabula --flip
    (╯°□°)╯︵ ┻━┻

(Note: "tabula" is also the table outputting lib that sdcadm,
triton, and other tools use.)


# LOGS

# slide: `bunyan`

You can try to look at logs, in the zone:

    ssh coal
    sdc-login -l papi

    bunyan `svcs -L papi`                   # recent
    bunyan /var/log/sdc/upload/papi*.log    # rotated logs
    tail -f `svcs -L papi` | bunyan         # live
    bunyan -p papi                          # live, trace-level

https://github.com/trentm/node-bunyan#readme

# slide: search hourly logs in Manta

Or you can search hourly logs uploaded to Manta.
E.g., search cloudapi logs for throttling cases:

    mfind -t o /admin/stor/logs/$dc/cloudapi-808{1,2,3,4}/$DATE \
        | mjob create -o \
            -m "(grep '\"Throttling\"' || true)" \
            -r cat

I've wrapped up a few types of log and data dump searches for time
ranges in scripts here:
    https://mo.joyent.com/trentops/blob/master/jobs

# slide: `mantash`

$ pip install manta

$ mantash
[trent.mick@us-east.manta.joyent.com /trent.mick/stor]$ cd /admin/stor/logs
[/admin/stor/logs]$ ls
...
us-east-1
us-east-2
...
[/admin/stor/logs]$ cd us-east-1/
[/admin/stor/logs/us-east-1]$ ls
adminui
...
papi
...

[/admin/stor/logs/us-east-1]$ cd papi/2017/10/10/10
[/admin/stor/logs/us-east-1/papi/2017/10/10/10]$ ls
1da304f0-ab1d-414b-92c7-d137e4d790e8.log
9c372d11-20f4-47bf-8317-acfc7e730093.log
bb7e07f7-19de-44af-ac8b-0f48e658944c.log

[/admin/stor/logs/us-east-1/papi/2017/10/10/10]$ ls -al
   object  5323155  1da304f0-ab1d-414b-92c7-d137e4d790e8.log
   object  1984347  9c372d11-20f4-47bf-8317-acfc7e730093.log
   object   887341  bb7e07f7-19de-44af-ac8b-0f48e658944c.log

[/admin/stor/logs/us-east-1/papi/2017/10/10/10]$ login 1da<TAB>


# slide: bunyan -> core

Or you could get a core at a specific log line:

    log.debug({...}, 'MoveImageFile: start');

Like this:

    dtrace -w -n 'bunyan62267:::log-debug
        /strstr(copyinstr(arg0), "MoveImageFile: start") != NULL/
        { stop(); system("gcore %d; prun %d", pid, pid); exit(0); }'

http://dtrace.org/blogs/dap/2013/10/14/stopping-a-broken-program-in-its-tracks/
https://github.com/trentm/node-bunyan/issues/470


# DEV: COAL

# slide: `make coal-and-open`

You'll probably want to test in a COAL, or a TritonDC setup on
hardware, if you have access to some. Let's build a COAL.

Build a COAL:

    git checkout git@github.com:joyent/sdc-headnode.git
    cd sdc-headnode
    make coal-and-open

# slide: COAL setup

To test your COAL, you might need more than the base install. Like:

    sdcadm post-setup common-external-nics  # AdminUI and IMGAPI

# slide: COAL setup

To test your COAL, you might need more than the base install. Like:

    sdcadm post-setup common-external-nics
    sdcadm post-setup dev-headnode-prov

# slide: COAL setup

To test your COAL, you might need more than the base install. Like:

    sdcadm post-setup common-external-nics
    sdcadm post-setup dev-headnode-prov
    sdcadm post-setup cloudapi

# slide: COAL setup

To test your COAL, you might need more than the base install. Like:

    sdcadm post-setup common-external-nics
    sdcadm post-setup dev-headnode-prov
    sdcadm post-setup cloudapi
    sdcadm post-setup docker

# slide: COAL setup

To test your COAL, you might need more than the base install. Like:

    sdcadm post-setup common-external-nics
    sdcadm post-setup dev-headnode-prov
    sdcadm post-setup cloudapi
    sdcadm post-setup docker
    sdcadm post-setup cns
    ...

# slide: COAL setup

To test your COAL, you might need more than the base install. Like:

    sdcadm post-setup common-external-nics
    sdcadm post-setup dev-headnode-prov
    sdcadm post-setup cloudapi
    sdcadm post-setup docker
    sdcadm post-setup cns
    sdcadm post-setup cmon

# slide: COAL setup

To test your COAL, you might need more than the base install. Like:

    sdcadm post-setup common-external-nics
    sdcadm post-setup dev-headnode-prov
    sdcadm post-setup cloudapi
    sdcadm post-setup docker
    sdcadm post-setup cns
    sdcadm post-setup cmon
    sdcadm post-setup fabrics && ... && reboot

# slide: COAL setup

To test your COAL, you might need more than the base install. Like:

    sdcadm post-setup common-external-nics
    sdcadm post-setup dev-headnode-prov
    sdcadm post-setup cloudapi
    sdcadm post-setup docker
    sdcadm post-setup cns
    sdcadm post-setup cmon
    sdcadm post-setup fabrics && ... && reboot
    sdc-useradm create -A login=trentm userpassword=secret123

# slide: COAL setup

To test your COAL, you might need more than the base install. Like:

    sdcadm post-setup common-external-nics
    sdcadm post-setup dev-headnode-prov
    sdcadm post-setup cloudapi
    sdcadm post-setup docker
    sdcadm post-setup cns
    sdcadm post-setup cmon
    sdcadm post-setup fabrics && ... && reboot
    sdc-useradm create -A login=trentm userpassword=secret123
    ...

# slide: `coal-post-setup.sh`

"coal-post-setup.sh" does all this for you:

    git clone git@github.com:joyent/trentops.git
    trentops/bin/coal-post-setup.sh -A


# DEV

# slide: giddyup

    $ cd sdc-papi
    $ alias giddyup
    alias giddyup='git fetch -p -a origin
        && git pull --rebase origin $(git rev-parse --abbrev-ref HEAD)
        && git submodule update --init'
    $ giddyup
    ...

# slide: rsync-to HEADNODE

A number of repos have a ./tools/rsync-to script to copy local
(non-binary) file changes to a headnode service instance.

Update my PAPI in COAL:

    $ ./tools/rsync-to coal      # or nightly-1


# slide: run test suites

The Globe Theatre repo typically has a script to drive any service's
test suite *that you can run from your computer*:

    $ git clone git@github.com:globe-theatre.git
    $ globe-theatre/bin/stage-test-papi coal

Handy if you don't really know how to run the test suite for
the repo you are working on.

# slide: `moray_massage_object`

https://mo.joyent.com/trentops/blob/master/bin/moray_massage_object

    $ ssh coal
    $ sdc-login -l moray
    $ moray_massage_object \
        sdc_packages \
        ebe3b369-0e82-e29f-cbff-cf74c41ed148 \
        -e 'this.name += "XXX"'
    --- /tmp/.moray_massage_object.81280.before
    +++ /tmp/.moray_massage_object.81280.after
    @@ -2,7 +2,7 @@
       "bucket": "sdc_packages",
       "key": "ebe3b369-0e82-e29f-cbff-cf74c41ed148",
       "value": {
    -    "name": "sample-8G",
    +    "name": "sample-8GXXX",


# slide: TRY_BRANCH builds

You can get a build of your changes with which to test in COAL.

Commit to a feature branch:

    git checkout -b PAPI-123
    git commit -am "$(jirash PAPI-123)"
    git push origin

Tell Jenkins to build it for you:

- https://jenkins.joyent.us/job/papi/build
- set `TRY_BUILD=PAPI-123`

# slide: `updates-imgadm`

This will build PAPI and put it in the "experimental" channel
of updates.joyent.com.

`updates-imgadm` is the tool to work with updates.jo:

    git clone git@github.com:joyent/sdc-imgapi-cli.git
    cd sdc-imgapi-cli
    make
    ./bin/updates-imgadm help

(This is already installed in any headnode GZ.)


# slide: `updates-imgadm -C experimental list name=SERVICE`

    $ updates-imgadm -C experimental list name=papi
    UUID      NAME  VERSION
    ...
    98735caa  papi  PAPI-123-20170510T184849Z-g296378b


# slide: `sdcadm up -C experimental SERVICE@IMAGE`

Update to this PAPI in your COAL:

    ssh coal
    sdcadm up -C experimental papi   # uses latest one

Or a specific UID

    sdcadm up -C experimental papi@98735caa-998a-485f-97af-1fbbbec80376


# slide: `triton`

    $ npm install -g triton

Hint: "coal-post-setup.sh" from early created a "coal"
profile for you.

    $ triton profile set coal

Create an instance:

    $ triton instance create IMAGE PACKAGE
    ...

Etc.

# slide: `triton cloudapi ...`

https://apidocs.joyent.com/cloudapi/
Call raw CloudAPI REST endpoints for debugging:

    $ triton cloudapi /--ping
    {
        "ping": "pong",
        "cloudapi": {
            "versions": [
                ...
                "8.0.0"
            ]
        }
    }

Not `triton cloudapi /ping`. That's a real account in JPC.


# slide: BONUS: `triton badger`


# CR

# slide: `grr ISSUE`

https://github.com/joyent/grr

    $ npm install -g joyent-grr

Move to your working copy and tell grr which issue:

    $ cd sdc-papi
    $ grr PAPI-144
    Issue: PAPI-144 that thing is broken

    Make commits and run `grr` in this branch to create a CR.


# slide: `grr`

Commit:

    $ git commit -am "fix that thing"
    [PAPI-144 b2af153] fix that thing
     1 file changed, 1 insertion(+), 1 deletion(-)

And `grr` creates the CR:

    $ grr
    Issue: PAPI-144 that thing is broken
    New commits (1):
        b2af153 fix that thing
    Creating CR:
        ...
    CR created: 2947 patchset 1 <https://cr.joyent.us/2947>

It handles the CR commit message for you.


# slide: `grr` with more commits

Your work needs another fix:

    $ git commit -am "bumpver for the fix"
    [PAPI-144 7c3543f] bumpver for the fix
     1 file changed, 1 insertion(+), 1 deletion(-)

`grr` will create a new patchset (handling the squash for you):

    $ grr
    Issue: PAPI-144 that thing is broken
    New commits (1):
        7c3543f bumpver for the fix
    Updating CR 2947:
        ...
    CR updated: 2947 patchset 2 <https://cr.joyent.us/2947>


# BONUS

# slide: col80

    function col80 ()
    {
        perl -pe 's/^(.{80})(.*?)$/$1\e[1;31;43m$2\e[0m/'
    }

XXX img


# slide: jirash issue ls FILTER

    $ jirash filter ls
    ID     NAME                                       OWNER.NAME
    ...
    10325  RELENG: open issues                        trent.mick
    11527  Triton high prio open issues               trent.mick
    11370  Triton tickets created in the last 7 days  orlando
    10183  me: open issues                            trent.mick
    11371  rfd67                                      trent.mick

    $ jirash issue ls last  # ... in the last 7 days
    KEY          SUMMARYCLIPPED                            ASSIGNEE
    ZAPI-811     vms.volumes.tests stalls in nightly-1 a…  ...
    PUBAPI-1460  nightly1-080-test-cloudapi fails in vol…  ...
    PORTAL-3195  There is no validation message when use…  ...

# slide: ripgrep

    https://github.com/BurntSushi/ripgrep/

# slide: add account to the operator group

    sdc-ufds modify --attribute uniquemember \
        --value "$(sdc-useradm get $LOGIN | json dn)" \
        --type add "cn=operators, ou=groups, o=smartdc"

# slide: set root password via Ur

sdc-oneachnode -n $THENODE 'sed -I .bak -e "s|root:.*:14897|root:\$5\$NaWW7lz.\$bVr5l8mtuhjVWbI3/0DT/i78T.g3tWdJ9QYOib.fmVA:14897|" /etc/shadow'

# slide: dump the UFDS/LDAP tree

    sdc-ldap search objectclass=* dn | grep dn \
        | /usr/perl5/bin/perl -pe '$_ = length($_) . " $_"' \
        | sort -n \
        | awk '{$1=""; $2=""; print}' \
        | /usr/perl5/bin/perl -e 'while (<>) { s/^\s+//s; chomp; print join(" ", reverse(split(", ", $_))), "\n" }' \
        | sort

# slide: mmsay

    mmlog mib | mmsay

# slide: say-scrum

    cd ../triton-dev
    ./bin/say-scrum


# DONE


# slide: all the nodes ... in git

XXX details on getting all joyent repos, RFD ref, engadm ref

    grep NODE_PREBUILT_VERSION */Makefile | awk -F '(/|=)' '{print $1 " " $3}' | awk '{printf("%-10s %s\n", $2, $1)}' | sort

XXX hound equiv link?


# slide: all the nodes ... in coal

    find / -name "node" -type f -perm -o+x -ls > /var/tmp/nodes.txt 2>/dev/null
    grep "/node" /var/tmp/nodes.txt | while read line; do
        node=$(echo ${line} | awk '{ print $11 }');
        echo "# ${node}"
        strings ${node} | sed -e "s/^node //" | grep "^v[0-9]*\.[0-9]" | head -1
    done

XXX If using this... refine it to give a report.

# slide: all the nodes ... in service

Perhaps: all nodes in Joyent prod:
    report.jo
    images.jo
    datasets.jo
    mo.jo
    updates.jo

Would be nice to have 0.12 in there.


# slide: which zookeeper is the current leader?

[root@headnode (nightly-1) ~]# sdcadm insts binder -o alias,ip -H | while read alias ip; do echo -n "$alias: "; echo stat | nc $ip 2181 | grep Mode; done
binder2: Mode: follower
binder1: Mode: leader
binder0: Mode: follower

# slide: kthxbai

    XXX run through a few repos to show savings

# slide: set root password via Ur

sdc-oneachnode -n $THENODE 'sed -I .bak -e "s|root:.*:14897|root:\$5\$NaWW7lz.\$bVr5l8mtuhjVWbI3/0DT/i78T.g3tWdJ9QYOib.fmVA:14897|" /etc/shadow'

# slide: dump the UFDS/LDAP tree

    sdc-ldap search objectclass=* dn | grep dn \
        | /usr/perl5/bin/perl -pe '$_ = length($_) . " $_"' \
        | sort -n \
        | awk '{$1=""; $2=""; print}' \
        | /usr/perl5/bin/perl -e 'while (<>) { s/^\s+//s; chomp; print join(" ", reverse(split(", ", $_))), "\n" }' \
        | sort
