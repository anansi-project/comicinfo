#!/bin/bash
# vi: et sts=4 sw=4 ts=4

REPO_ROOT=${0%/*}/..
SCHEMA_ROOT_DIRS=(
    "$REPO_ROOT/schema"
    "$REPO_ROOT/drafts"
)
TESTS_DIR=${0%/*}

GREEN=$'\e[1;32m'
RED=$'\e[1;31m'
YELLOW=$'\e[1;33m'
RESET=$'\e[0m'
COLOR=auto
FAIL_ON_WARNINGS=1

parse_args() {
    ARGS=()
    local NO_MORE_FLAGS
    NO_MORE_FLAGS=0
    for ARG; do
        # Assume arguments that don't begin with a - are supposed to be files
        # or other operands
        # (currently ignored)
        if [[ $NO_MORE_FLAGS -eq 0 && $ARG = -* ]]; then
            case "$ARG" in
                --color=*)
                    case "${ARG#*=}" in
                        [0NnFf]*|never)
                            COLOR=0
                            ;;
                        [1YyTt]*|always)
                            COLOR=1
                            ;;
                        auto)
                            COLOR=auto
                            ;;
                        *)
                            printf 'Unrecognized value: %s\n' \
                                "$ARG" \
                                >&2
                            exit 2
                            ;;
                    esac
                    ;;
                --ignore-warnings)
                    FAIL_ON_WARNINGS=0
                    ;;
                --)
                    NO_MORE_FLAGS=1
                    ;;
                *)
                    printf 'Unrecognized flag: %s\n' \
                        "$ARG" \
                        >&2
                    exit 2
                    ;;
            esac
        else
            ARGS+=("$ARG")
        fi
    done

    if [[ $COLOR = 'auto' ]]; then
        if [[ -t 1 ]]; then
            COLOR=1
        else
            COLOR=0
        fi
    fi
}

main() {
    parse_args "$@"
    assert_has_program xmllint
    assert_directory_exists "${SCHEMA_ROOT_DIRS[@]}"

    FAILURES=()
    WARNINGS=()
    TEST_COUNT=0
    test_version 'all'

    VERSIONS=()
    for SCHEMA_ROOT_DIR in "${SCHEMA_ROOT_DIRS[@]}"; do
        for VERSION_DIR in "$SCHEMA_ROOT_DIR"/*; do
            if [[ -d $VERSION_DIR ]]; then
                VERSIONS+=("${VERSION_DIR##*/}")
            fi
        done
    done
    for VERSION in "${VERSIONS[@]}"; do
        test_version "$VERSION"
    done

    printf '\n------------- Results -------------\n'
    printf '%d/%d tests passed\n' \
        "$(( TEST_COUNT - ${#FAILURES[@]} ))" \
        "$TEST_COUNT"

    FAILED=0
    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        printf_error '\nError: Validation errors occurred:\n'
        for MSG in "${FAILURES[@]}"; do
            printf_error -- '- %s\n' "$MSG"
        done
        FAILED=1
    else
        printf_success 'All tests passed\n'
    fi

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        printf_warning '\nWarning:\n'
        for MSG in "${WARNINGS[@]}"; do
            printf_warning -- '- %s\n' "$MSG"
        done
        if [[ $FAIL_ON_WARNINGS -ne 0 ]]; then
            FAILED=1
        fi
    fi
    return "$FAILED"
}

assert_directory_exists() {
    local \
        DIR \
        MISSING=()
    for DIR; do
        if [[ ! -d $DIR ]]; then
            MISSING+=("$DIR")
        fi
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        printf 'Error: Directories do not exist:\n' >&2
        for DIR in "${MISSING[@]}"; do
            printf -- '- %s\n' "$DIR" >&2
        done
        exit 2
    fi
}

assert_has_program() {
    local \
        BIN \
        MISSING=()
    for BIN; do
        if ! type -t "$BIN" &>/dev/null; then
            MISSING+=("$BIN")
        fi
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        printf 'Error: You are missing required programs:\n' >&2
        for BIN in "${MISSING[@]}"; do
            printf -- '- %s\n' "$BIN" >&2
        done
        exit 2
    fi
}

colorize() {
    local PAINT=$1
    shift
    if [[ $COLOR -ne 0 ]]; then
        printf '%s' "$PAINT"
        "$@"
        printf '%s' "$RESET"
    else
        "$@"
    fi
}

invalidate_against() {
    local OUT XML XSD=$1
    shift 1
    for XML; do
        ((++TEST_COUNT))
        if OUT=$(lint_xml "$XSD" "$XML" 2>&1); then
            # Passes validation --> error, print the message from xmllint
            printf '%s\n' "$OUT" >&2
            FAILURES+=("Errors in $XML weren't caught by $XSD")
        fi
    done
}

lint_xml() {
    local XSD=$1 XML=$2
    xmllint \
        --noout \
        --schema "$XSD" \
        "$XML"
}

printf_error() {
    colorize "$RED" printf "$@"
}

printf_success() {
    colorize "$GREEN" printf "$@"
}

printf_warning() {
    colorize "$YELLOW" printf "$@"
}

test_version() {
    local INVALID_DIR TEST VALID_DIR VERSION VERSION_DIR XSD XSD_DIRS
    VERSION=$1
    XSD_DIRS=()
    for SCHEMA_ROOT_DIR in "${SCHEMA_ROOT_DIRS[@]}"; do
        for VERSION_DIR in "$SCHEMA_ROOT_DIR"/*; do
            if [[ -d $VERSION_DIR ]]; then
                if [[ $VERSION = 'all' || ${VERSION_DIR##*/} = $VERSION ]]; then
                    XSD_DIRS+=("$VERSION_DIR")
                fi
            fi
        done
    done

    FOUND_VERSION_XSD=0
    for VERSION_DIR in "${XSD_DIRS[@]}"; do
        for XSD in "$VERSION_DIR"/*.xsd; do
            if [[ ! -f $XSD ]]; then
                WARNINGS+=("XSD '$XSD' cannot be located, or isn't a file")
                continue
            fi
            FOUND_VERSION_XSD=1

            VALID_DIR=$TESTS_DIR/$VERSION/valid
            INVALID_DIR=$TESTS_DIR/$VERSION/invalid
            if [[ -d $VALID_DIR ]]; then
                validate_against "$XSD" \
                    "$VALID_DIR"/*
            fi
            if [[ -d $INVALID_DIR ]]; then
                invalidate_against "$XSD" \
                    "$INVALID_DIR"/*
            fi
        done
    done

    if [[ $FOUND_VERSION_XSD -eq 0 ]]; then
        WARNINGS+=("XSD version $VERSION cannot be located")
    fi
}

validate_against() {
    local XML XSD=$1
    shift 1
    for XML; do
        ((++TEST_COUNT))
        if ! lint_xml "$XSD" "$XML"; then
            FAILURES+=("$XML fails validation against $XSD")
        fi
    done
}

main "$@"
