#!/usr/bin/env bats
bats_load_library "bats-support"
bats_load_library "bats-assert"
bats_require_minimum_version 1.5.0

setup_file() {
  GIT_ROOT=$(git rev-parse --show-toplevel)
  export TEST_DIR="$GIT_ROOT/tests"
  export SKUST_BIN="$GIT_ROOT/skustomize"
  export SOPS_AGE_KEY_FILE="$TEST_DIR/age/key.txt"
  TEMPDIR=$(mktemp -d)
  export TEMPDIR
  cp "$TEST_DIR"/secrets.yaml "$TEMPDIR"
  cd "$TEST_DIR"
}

teardown_file() {
  rm -rf "$TEMPDIR"
}

setup() {
  . "$SKUST_BIN"
}

@test "it should parse global flags only" {
  parse_flags -h --stack-trace
  assert_equal "${GLOBAL_FLAGS[*]}" "-h --stack-trace"
  assert_equal "$SUB_COMMAND" ""
  assert_equal "${SUB_FLAGS[*]}" ""
  assert_equal "$WORKDIR" "."
}

@test 'it should parse flags for sub command' {
  parse_flags build --as-current-user --enable-exec --stack-trace
  assert_equal "${GLOBAL_FLAGS[*]}" "--stack-trace"
  assert_equal "$SUB_COMMAND" "build"
  assert_equal "${SUB_FLAGS[*]}" "--as-current-user --enable-exec"
  assert_equal "$WORKDIR" "."
}

@test 'it should parse global and sub flags for sub command' {
  parse_flags --stack-trace build --as-current-user --enable-exec -e xx=yy abc/def
  assert_equal "${GLOBAL_FLAGS[*]}" "--stack-trace"
  assert_equal "$SUB_COMMAND" "build"
  assert_equal "${SUB_FLAGS[*]}" "--as-current-user --enable-exec -e xx=yy abc/def"
  assert_equal "$WORKDIR" "abc/def"
}

@test 'it should parse global and sub flags for sub command1' {
  parse_flags --stack-trace build --as-current-user abc/def --enable-exec -e xx=yy
  assert_equal "${GLOBAL_FLAGS[*]}" "--stack-trace"
  assert_equal "$SUB_COMMAND" "build"
  assert_equal "${SUB_FLAGS[*]}" "--as-current-user abc/def --enable-exec -e xx=yy"
  assert_equal "$WORKDIR" "abc/def"
}

@test "it should generate secrets from encrypted file in current folder" {
  run --separate-stderr "$SKUST_BIN" build
  private_key=$(yq '.data.privateKey|@base64d' <<<"$output")
  assert_equal "$private_key" "$(<ssh/private.key)"
  public_key=$(yq '.data.publicKey|@base64d' <<<"$output")
  assert_equal "$public_key" "$(<ssh/public.key)"
  assert_success
}

@test "it should generate secrets from encrypted file in given folder" {
  run --separate-stderr "$SKUST_BIN" build $TEMPDIR
  private_key=$(yq '.data.privateKey|@base64d' <<<"$output")
  assert_equal "$private_key" "$(<ssh/private.key)"
  public_key=$(yq '.data.publicKey|@base64d' <<<"$output")
  assert_equal "$public_key" "$(<ssh/public.key)"
  assert_success
}

@test "it should exit with error if no key in sops url" {
  cat >$TEMPDIR/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
secretGenerator:
  - name: test-secret
    files:
      - ref+sops://secrets.yaml
EOF
  run "$SKUST_BIN" build $TEMPDIR
  assert_failure
  assert_output --partial "invalid literal source ref+sops://$TEMPDIR/secrets.yaml, expected key=value"
}

@test "it should exit with error if two folders given" {
  run "$SKUST_BIN" build folder1 folder2
  assert_failure
  assert_output "Error: specify one path to kustomization.yaml"
}
