#!/bin/sh
# Tests destroy-instance.sh against a fake `container` CLI in a throwaway copy
# of the project. Needs no Apple container runtime and touches nothing real.
#
#   ./scripts/test-destroy-instance.sh

set -eu

SRC_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/p5-destroy-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT INT TERM

PASS=0
FAIL=0
check() {
    # check "description" command...
    CHECK_DESC=$1
    shift
    if "$@"; then
        PASS=$((PASS + 1))
        echo "  ok    $CHECK_DESC"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL  $CHECK_DESC"
    fi
}
exists() { [ -e "$1" ]; }
absent() { [ ! -e "$1" ]; }
# Prints the exit code of a command, with output discarded.
rc_of() {
    RC_OF=0
    "$@" >/dev/null 2>&1 || RC_OF=$?
    echo "$RC_OF"
}
state_is() { [ "$(cat "$FAKE_STATE/$1" 2>/dev/null || echo gone)" = "$2" ]; }

# --- Fake container CLI: one state file per container -------------------
FAKE_STATE="$WORK/state"
export FAKE_STATE
mkdir -p "$FAKE_STATE"
cat >"$WORK/fake-container" <<'FAKE'
#!/bin/sh
cmd=$1
name=${2:-}
[ "$cmd" = stop ] && name=${4:-}
f="$FAKE_STATE/$name"
case "$cmd" in
    inspect)
        [ -f "$f" ] || exit 1
        read -r st <"$f"
        case "$st" in
            foreign) printf '{"configuration":{"labels":{}},"status":"running"}\n' ;;
            *) printf '{"configuration":{"labels":{"com.matx.p5-local-lab.managed":"true"}},"status":"%s"}\n' "$st" ;;
        esac
        ;;
    stop) echo stopped >"$f" ;;
    delete) rm -f "$f" ;;
    *) exit 2 ;;
esac
FAKE
chmod +x "$WORK/fake-container"
export P5_CONTAINER_BIN="$WORK/fake-container"

reset_lab() {
    rm -rf "$WORK/lab" "$FAKE_STATE"
    mkdir -p "$WORK/lab" "$FAKE_STATE"
    cp -R "$SRC_ROOT/scripts" "$SRC_ROOT/versions" "$SRC_ROOT/VERSION" "$WORK/lab/" 2>/dev/null || \
        cp -R "$SRC_ROOT/scripts" "$SRC_ROOT/versions" "$WORK/lab/"
    for n in p5-lab-01 p5-lab-02 p5-lab-03 p5-lab-04; do
        mkdir -p "$WORK/lab/instances/$n/archive"
        echo data >"$WORK/lab/instances/$n/archive/file.p5b"
    done
    echo running >"$FAKE_STATE/p5-lab-01"
    echo stopped >"$FAKE_STATE/p5-lab-02"
    # p5-lab-03: folder only, no container
    echo foreign >"$FAKE_STATE/p5-lab-04"
}
D="$WORK/lab/scripts/destroy-instance.sh"
I="$WORK/lab/instances"

echo "single name"
reset_lab
"$D" p5-lab-01 --confirm >/dev/null
check "running container stopped and deleted" absent "$FAKE_STATE/p5-lab-01"
check "folder kept by default" exists "$I/p5-lab-01/archive/file.p5b"
reset_lab
"$D" p5-lab-02 --confirm --delete-folders >/dev/null
check "--delete-folders removes the folder" absent "$I/p5-lab-02"
reset_lab
check "missing container is an error" test "$(rc_of "$D" p5-lab-03 --confirm)" = 1
check "non-lab container refused" test "$(rc_of "$D" p5-lab-04 --confirm)" = 1
check "non-lab container left alone" state_is p5-lab-04 foreign
check "needs --confirm" test "$(rc_of "$D" p5-lab-01)" = 2

echo "--all"
reset_lab
RC=0
"$D" --all --confirm >/dev/null 2>&1 || RC=$?
check "exit code is non-zero when one was skipped" test "$RC" -ne 0
check "lab containers deleted" absent "$FAKE_STATE/p5-lab-01"
check "stopped container deleted" absent "$FAKE_STATE/p5-lab-02"
check "non-lab container survives --all" state_is p5-lab-04 foreign
check "folders kept without --delete-folders" exists "$I/p5-lab-03/archive/file.p5b"
reset_lab
"$D" --all --confirm --delete-folders >/dev/null 2>&1 || true
check "--all --delete-folders removes lab folders" absent "$I/p5-lab-01"
check "folder-only instance removed too" absent "$I/p5-lab-03"
check "non-lab container's folder kept" exists "$I/p5-lab-04"

echo "interactive menu"
reset_lab
printf 'q\n' | P5_LAB_NO_TTY_CHECK=1 "$D" >/dev/null
check "q exits and deletes nothing" state_is p5-lab-01 running
reset_lab
printf '\n' | P5_LAB_NO_TTY_CHECK=1 "$D" >/dev/null
check "empty input exits and deletes nothing" state_is p5-lab-02 stopped
reset_lab
printf '1 2\nno\nq\n' | P5_LAB_NO_TTY_CHECK=1 "$D" >/dev/null
check "wrong confirmation deletes nothing" state_is p5-lab-01 running
reset_lab
printf '9\nq\n' | P5_LAB_NO_TTY_CHECK=1 "$D" >/dev/null 2>&1
check "out-of-range number deletes nothing" state_is p5-lab-01 running
reset_lab
printf '1,2\nyes\nn\n' | P5_LAB_NO_TTY_CHECK=1 "$D" >/dev/null
check "picked containers deleted" absent "$FAKE_STATE/p5-lab-02"
check "unpicked container kept" test -z "$(cat "$FAKE_STATE/p5-lab-03" 2>/dev/null)"
check "folders kept when answering n" exists "$I/p5-lab-01/archive/file.p5b"
reset_lab
printf '1-2\nyes\ny\n' | P5_LAB_NO_TTY_CHECK=1 "$D" >/dev/null
check "range picks both and folders go on y" absent "$I/p5-lab-02"
check "range leaves the third folder" exists "$I/p5-lab-03"
reset_lab
printf 'a\nyes\nq\n' | P5_LAB_NO_TTY_CHECK=1 "$D" >/dev/null
check "'a' needs the words delete all" state_is p5-lab-01 running
reset_lab
printf 'a\ndelete all\ny\n' | P5_LAB_NO_TTY_CHECK=1 "$D" >/dev/null 2>&1 || true
check "delete all removes lab containers" absent "$FAKE_STATE/p5-lab-01"
check "delete all removes folders on y" absent "$I/p5-lab-02"
check "delete all leaves the non-lab container" state_is p5-lab-04 foreign
reset_lab
check "menu refuses to run without a terminal" test "$(rc_of "$D" </dev/null)" = 2

echo
echo "Passed: $PASS. Failed: $FAIL."
[ "$FAIL" -eq 0 ]
