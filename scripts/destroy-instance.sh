#!/bin/sh

set -eu
# shellcheck source=common.sh
. "$(dirname -- "$0")/common.sh"

print_help() {
    cat <<HELP
Usage:
  $0
      Interactive: list the instances, then choose to delete all, delete
      some, or exit.
  $0 <name> --confirm
      Delete one lab container.
  $0 --all --confirm
      Delete every lab container.
  $0 --help

Options:
  --delete-folders   Also delete each instance's folder under instances/
                     (its source, archive, restore and exports folders).
                     Without it the folders are kept.

Deleting a container removes it and its P5 configuration. Only containers
labelled as P5 Local Lab resources are touched. A media folder mounted
read-only at /media is on the host and is never deleted.

Instances that exist:
HELP
    print_instances_overview
}

# Prints none, running, stopped or foreign for the container named \$1.
container_state() {
    if ! STATE_JSON=$("$CONTAINER_BIN" inspect "$1" 2>/dev/null); then
        echo none
        return 0
    fi
    if ! printf '%s\n' "$STATE_JSON" | \
        grep -Eq '"com\.matx\.p5-local-lab\.managed"[[:space:]]*:[[:space:]]*"true"'; then
        echo foreign
        return 0
    fi
    if printf '%s\n' "$STATE_JSON" | \
        grep -Eq '"(state|status)"[[:space:]]*:[[:space:]]*"running"'; then
        echo running
    else
        echo stopped
    fi
}

# Kilobytes used by an instance folder, 0 when it does not exist.
folder_kb() {
    if [ -d "$P5_LAB_ROOT/instances/$1" ]; then
        du -sk "$P5_LAB_ROOT/instances/$1" 2>/dev/null | awk '{print $1 + 0}'
    else
        echo 0
    fi
}

human_kb() {
    awk -v kb="$1" 'BEGIN {
        if (kb >= 1048576) printf "%.1f GB", kb / 1048576
        else if (kb >= 1024) printf "%.0f MB", kb / 1024
        else printf "%d KB", kb
    }'
}

# Stops (if running) and deletes the lab container named $1.
# Returns 0 deleted, 10 no such container, 11 not a lab container, 1 failed.
destroy_container() {
    DESTROY_STATE=$(container_state "$1")
    case "$DESTROY_STATE" in
        none) return 10 ;;
        foreign) return 11 ;;
        running)
            "$CONTAINER_BIN" stop --time 30 "$1" || return 1
            ;;
    esac
    "$CONTAINER_BIN" delete "$1" || return 1
}

# Deletes instances/<name>. Refuses anything that is not a real directory
# directly under this project's instances/ folder.
remove_instance_folder() {
    FOLDER_PATH="$P5_LAB_ROOT/instances/$1"
    case "$1" in
        ""|.|..|*/*) return 1 ;;
    esac
    [ -d "$FOLDER_PATH" ] || return 0
    [ ! -L "$FOLDER_PATH" ] || return 1
    rm -rf -- "$FOLDER_PATH"
}

# Deletes the named instances. DELETE_FOLDERS=1 also removes their folders.
# Failures are counted and the run continues; returns 1 if any occurred.
destroy_instances() {
    DONE_CONTAINERS=0
    DONE_FOLDERS=0
    SKIPPED=0
    FAILED=0
    for DESTROY_NAME in "$@"; do
        DESTROY_RC=0
        destroy_container "$DESTROY_NAME" || DESTROY_RC=$?
        case "$DESTROY_RC" in
            0)
                echo "Deleted container $DESTROY_NAME."
                DONE_CONTAINERS=$((DONE_CONTAINERS + 1))
                ;;
            10)
                echo "No container for $DESTROY_NAME."
                ;;
            11)
                echo "Refusing to delete $DESTROY_NAME: it is not labelled as a P5 Local Lab container." >&2
                SKIPPED=$((SKIPPED + 1))
                continue
                ;;
            *)
                echo "Failed to delete container $DESTROY_NAME; its folder was left alone." >&2
                FAILED=$((FAILED + 1))
                continue
                ;;
        esac
        if [ "${DELETE_FOLDERS:-0}" -eq 1 ]; then
            if remove_instance_folder "$DESTROY_NAME"; then
                echo "Deleted $P5_LAB_ROOT/instances/$DESTROY_NAME"
                DONE_FOLDERS=$((DONE_FOLDERS + 1))
            else
                echo "Could not delete $P5_LAB_ROOT/instances/$DESTROY_NAME" >&2
                FAILED=$((FAILED + 1))
            fi
        else
            echo "Preserved $P5_LAB_ROOT/instances/$DESTROY_NAME"
        fi
    done
    echo
    echo "Containers deleted: $DONE_CONTAINERS. Folders deleted: $DONE_FOLDERS. Skipped: $SKIPPED. Failed: $FAILED."
    [ "$FAILED" -eq 0 ] && [ "$SKIPPED" -eq 0 ]
}

# Instance folder names that are valid instance names, one per line.
valid_instance_names() {
    for VALID_NAME in $(instance_names); do
        case "$VALID_NAME" in
            ""|*[!a-z0-9-]*) continue ;;
        esac
        echo "$VALID_NAME"
    done
}

# Reads a yes/no answer. Anything but y or yes is no.
ask_yes_no() {
    printf '%s [y/N] ' "$1"
    read -r ANSWER || ANSWER=""
    case "$ANSWER" in
        y|Y|yes|YES|Yes) return 0 ;;
    esac
    return 1
}

# Turns "1 3", "1,3" or "2-4" into instance names. Sets SELECTED_NAMES, or
# returns 1 after saying what was wrong.
resolve_selection() {
    SELECTION_INPUT=$(printf '%s' "$1" | tr ',' ' ')
    SELECTED_NAMES=""
    SELECTED_INDEXES=" "
    for SELECTION_TOKEN in $SELECTION_INPUT; do
        case "$SELECTION_TOKEN" in
            *-*)
                RANGE_FROM=${SELECTION_TOKEN%-*}
                RANGE_TO=${SELECTION_TOKEN#*-}
                ;;
            *)
                RANGE_FROM=$SELECTION_TOKEN
                RANGE_TO=$SELECTION_TOKEN
                ;;
        esac
        case "$RANGE_FROM$RANGE_TO" in
            ""|*[!0-9]*)
                echo "Not a number or range: $SELECTION_TOKEN" >&2
                return 1
                ;;
        esac
        if [ "$RANGE_FROM" -lt 1 ] || [ "$RANGE_TO" -gt "$MENU_COUNT" ] || [ "$RANGE_FROM" -gt "$RANGE_TO" ]; then
            echo "Pick numbers from 1 to $MENU_COUNT: $SELECTION_TOKEN" >&2
            return 1
        fi
        RANGE_I=$RANGE_FROM
        while [ "$RANGE_I" -le "$RANGE_TO" ]; do
            case "$SELECTED_INDEXES" in
                *" $RANGE_I "*) ;;
                *) SELECTED_INDEXES="$SELECTED_INDEXES$RANGE_I " ;;
            esac
            RANGE_I=$((RANGE_I + 1))
        done
    done
    for PICKED in $SELECTED_INDEXES; do
        SELECTED_NAMES="$SELECTED_NAMES $(printf '%s\n' "$MENU_NAMES" | sed -n "${PICKED}p")"
    done
    [ -n "$SELECTED_NAMES" ]
}

interactive_menu() {
    if [ ! -t 0 ] && [ -z "${P5_LAB_NO_TTY_CHECK:-}" ]; then
        echo "The interactive menu needs a terminal. Use: $0 <name> --confirm or $0 --all --confirm" >&2
        exit 2
    fi

    MENU_NAMES=$(valid_instance_names)
    if [ -z "$MENU_NAMES" ]; then
        echo "No instances exist under $P5_LAB_ROOT/instances."
        exit 0
    fi
    MENU_COUNT=$(printf '%s\n' "$MENU_NAMES" | wc -l | tr -d ' ')

    while :; do
        echo
        printf '   %-4s %-24s %-10s %s\n' "#" "INSTANCE" "CONTAINER" "FOLDER"
        MENU_INDEX=0
        MENU_TOTAL_KB=0
        for MENU_NAME in $MENU_NAMES; do
            MENU_INDEX=$((MENU_INDEX + 1))
            MENU_STATE=$(container_state "$MENU_NAME")
            MENU_KB=$(folder_kb "$MENU_NAME")
            MENU_TOTAL_KB=$((MENU_TOTAL_KB + MENU_KB))
            [ "$MENU_STATE" != "foreign" ] || MENU_STATE="not-lab"
            printf '   %-4s %-24s %-10s %s\n' "$MENU_INDEX)" "$MENU_NAME" "$MENU_STATE" "$(human_kb "$MENU_KB")"
        done
        echo
        echo "  a    Delete all $MENU_COUNT instances ($(human_kb "$MENU_TOTAL_KB") of folders)"
        echo "  1 3  Delete these (numbers, or a range such as 2-4)"
        echo "  q    Exit"
        printf 'Choose: '
        read -r CHOICE || CHOICE="q"
        case "$CHOICE" in
            ""|q|Q|quit|exit|x)
                echo "Nothing deleted."
                exit 0
                ;;
            a|A|all)
                SELECTED_NAMES=" $(printf '%s' "$MENU_NAMES" | tr '\n' ' ')"
                CONFIRM_WORD="delete all"
                ;;
            *)
                if ! resolve_selection "$CHOICE"; then
                    continue
                fi
                CONFIRM_WORD="yes"
                ;;
        esac

        echo
        echo "This will delete the container for:"
        SELECTED_KB=0
        for PICKED_NAME in $SELECTED_NAMES; do
            PICKED_KB=$(folder_kb "$PICKED_NAME")
            SELECTED_KB=$((SELECTED_KB + PICKED_KB))
            echo "  $PICKED_NAME  ($(container_state "$PICKED_NAME"), folder $(human_kb "$PICKED_KB"))"
        done
        echo "Containers running now are stopped first. Instance folders are kept unless you say otherwise next."
        printf 'Type "%s" to continue, anything else goes back to the menu: ' "$CONFIRM_WORD"
        read -r TYPED || TYPED=""
        if [ "$TYPED" != "$CONFIRM_WORD" ]; then
            echo "Cancelled; nothing deleted."
            continue
        fi

        DELETE_FOLDERS=0
        if ask_yes_no "Also delete these instances' folders ($(human_kb "$SELECTED_KB")), including their archive and restore data?"; then
            DELETE_FOLDERS=1
        fi
        echo
        # shellcheck disable=SC2086
        destroy_instances $SELECTED_NAMES || exit 1
        exit 0
    done
}

DELETE_FOLDERS=0
CONFIRMED=0
ALL=0
INSTANCE_NAME=""
for ARG in "$@"; do
    case "$ARG" in
        -h|--help|help)
            print_help
            exit 0
            ;;
        --confirm) CONFIRMED=1 ;;
        --all) ALL=1 ;;
        --delete-folders) DELETE_FOLDERS=1 ;;
        -i|--interactive) ;;
        -*)
            echo "Unknown option: $ARG. Run $0 --help." >&2
            exit 2
            ;;
        *)
            if [ -n "$INSTANCE_NAME" ]; then
                echo "Only one instance name can be given. Use --all for every instance." >&2
                exit 2
            fi
            INSTANCE_NAME=$ARG
            ;;
    esac
done

if [ -z "$INSTANCE_NAME" ] && [ "$ALL" -eq 0 ]; then
    interactive_menu
    exit 0
fi

if [ -n "$INSTANCE_NAME" ] && [ "$ALL" -eq 1 ]; then
    echo "Give an instance name or --all, not both." >&2
    exit 2
fi

if [ "$CONFIRMED" -ne 1 ]; then
    echo "Usage: $0 <name> --confirm | --all --confirm | (no arguments for the menu)" >&2
    echo "This deletes the container's writable P5 configuration layer." >&2
    echo "The bind-mounted instance folder is preserved unless --delete-folders is given." >&2
    exit 2
fi

if [ "$ALL" -eq 1 ]; then
    ALL_NAMES=$(valid_instance_names)
    if [ -z "$ALL_NAMES" ]; then
        echo "No instances exist under $P5_LAB_ROOT/instances."
        exit 0
    fi
    # shellcheck disable=SC2086
    destroy_instances $ALL_NAMES
    exit $?
fi

validate_instance_name "$INSTANCE_NAME"
SINGLE_RC=0
destroy_container "$INSTANCE_NAME" || SINGLE_RC=$?
case "$SINGLE_RC" in
    0) ;;
    10)
        echo "Container not found: $INSTANCE_NAME" >&2
        exit 1
        ;;
    11)
        echo "Refusing to delete $INSTANCE_NAME: it is not labelled as a P5 Local Lab container." >&2
        exit 1
        ;;
    *)
        echo "Failed to delete container $INSTANCE_NAME." >&2
        exit 1
        ;;
esac
echo "Deleted container $INSTANCE_NAME."
if [ "$DELETE_FOLDERS" -eq 1 ]; then
    if remove_instance_folder "$INSTANCE_NAME"; then
        echo "Deleted $P5_LAB_ROOT/instances/$INSTANCE_NAME"
    else
        echo "Could not delete $P5_LAB_ROOT/instances/$INSTANCE_NAME" >&2
        exit 1
    fi
else
    echo "Preserved $P5_LAB_ROOT/instances/$INSTANCE_NAME"
fi
