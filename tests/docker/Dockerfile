# check=skip=SecretsUsedInArgOrEnv
# closio-agent's tests in a Linux container (D93): `bash tests/run.sh --docker`. The same bash as the Mac (3.2.57), plus
# the tools the scripts and tests use. A program starts here in about a millisecond (on the Mac, the security software
# makes it 12 to 80 ms), so the whole suite runs in about a minute. The few tools that differ between macOS and Linux
# (sed, stat, date, fold, script) are replaced by shims (shims/) that take the macOS form and run the Linux tool, so the
# scripts and tests stay as they are; they replace the tools in place, so a script that sets its own PATH gets them too.
# Built by tests/run.sh when missing (its tag is the hash of this folder); it stays on this Mac, never pushed anywhere.
FROM bash:3.2
RUN apk add --no-cache git jq python3 curl perl perl-utils coreutils findutils grep sed gawk diffutils \
      util-linux procps ncurses nodejs tzdata \
 && ln -sf /usr/local/bin/bash /bin/bash \
 && adduser -D -u 1000 -h /home/tester tester
COPY shims/ /tmp/shims/
RUN mkdir -p /usr/local/closio-real \
 && mv /bin/sed /usr/local/closio-real/sed && mv /usr/bin/script /usr/local/closio-real/script \
 && for t in sed stat date script; do rm -f "/bin/$t" "/usr/bin/$t"; done && rm -f /usr/bin/fold \
 && install -m 755 /tmp/shims/sed /tmp/shims/stat /tmp/shims/date /bin/ \
 && install -m 755 /tmp/shims/script /tmp/shims/fold /usr/bin/ \
 && rm -rf /tmp/shims
# USER: the Mac always sets it, Docker doesn't. safe.directory: the mounted folder belongs to the Mac's user, not to tester.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 TMPDIR=/tmp USER=tester \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0=*
USER tester
WORKDIR /work
