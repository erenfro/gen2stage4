#!/usr/bin/env bats

load test_helper

setup() {
    f test/usr/bin/ping
    f test/usr/bin/lost+found
    f test/lost+found
    gen2stage4 -q -l -t test test
}

teardown() {
    rm -rf test test.tar.xz
}

@test "/usr/bin/ping is included" {
    assert_tar_includes test/usr/bin/ping
}

@test "/usr/bin/lost+found is included" {
    assert_tar_includes test/usr/bin/lost+found
}

@test "/lost+found is included" {
    assert_tar_includes test/lost+found
}

# vim: ft=bash
