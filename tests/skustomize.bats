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

@test "it should fail if kustomize and kubectl are not installed" {
  KUSTOMIZE_BIN="not-installed-kustomize" KUBECTL_BIN="not-installed-kubectl"
  run get_kust_bin
  assert_failure
  assert_output --partial "[ERROR]: can't find ${KUSTOMIZE_BIN} or ${KUBECTL_BIN} installed"
}

@test "it should use kubectl if kustomize is not installed" {
  KUSTOMIZE_BIN="not-installed-kustomize"
  get_kust_bin
  assert_equal $USE_KUBECTL true
  assert_equal $KUSTOMIZE_BIN "kubectl"
}

@test "it should use kustomize if kustomize is installed" {
  get_kust_bin
  assert_equal $USE_KUBECTL false
  assert_equal $KUSTOMIZE_BIN "kustomize"
}

@test "it should fail if yq or vals is not installed" {
  which() { false; }
  run check_deps
  assert_failure
  assert_output --partial "vals is required, download from"
}

@test "it should parse global flags only" {
  parse_flags -h --stack-trace
  assert_equal "${GLOBAL_FLAGS[*]}" "-h --stack-trace"
  assert_equal "$SUB_COMMAND" ""
  assert_equal "${SUB_FLAGS[*]}" ""
  assert_equal "$WORKDIR" "."
}

@test 'it should parse sub flags only' {
  parse_flags build --as-current-user --enable-exec
  assert_equal "${GLOBAL_FLAGS[*]}" ""
  assert_equal "$SUB_COMMAND" "build"
  assert_equal "${SUB_FLAGS[*]}" "--as-current-user --enable-exec"
  assert_equal "$WORKDIR" "."
}

@test 'it should parse global and sub flags both' {
  parse_flags --stack-trace build --as-current-user --enable-exec -e xx=yy abc/def
  assert_equal "${GLOBAL_FLAGS[*]}" "--stack-trace"
  assert_equal "$SUB_COMMAND" "build"
  assert_equal "${SUB_FLAGS[*]}" "--as-current-user --enable-exec -e xx=yy abc/def"
  assert_equal "$WORKDIR" "abc/def"
}

@test 'it should parse global and sub flags both with any order' {
  parse_flags build --as-current-user abc/def --enable-exec -e xx=yy --stack-trace
  assert_equal "${GLOBAL_FLAGS[*]}" "--stack-trace"
  assert_equal "$SUB_COMMAND" "build"
  assert_equal "${SUB_FLAGS[*]}" "--as-current-user abc/def --enable-exec -e xx=yy"
  assert_equal "$WORKDIR" "abc/def"
}

@test "it should generate secrets from valid uri with kustomize" {
  cat >$TEMPDIR/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
secretGenerator:
  - name: test-secret
    files:
      - privateKey=ref+sops://secrets.yaml#/privateKey
      - publicKey=ref+sops://$TEMPDIR/secrets.yaml#/publicKey
EOF
  run --separate-stderr "$SKUST_BIN" build $TEMPDIR
  private_key=$(yq '.data.privateKey|@base64d' <<<"$output")
  assert_equal "$private_key" "$(<ssh/private.key)"
  public_key=$(yq '.data.publicKey|@base64d' <<<"$output")
  assert_equal "$public_key" "$(<ssh/public.key)"
  assert_success
}

@test "it should generate secrets from valid uri with kubectl" {
  cat >$TEMPDIR/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
secretGenerator:
  - name: test-secret
    files:
      - privateKey=ref+sops://secrets.yaml#/privateKey
      - publicKey=ref+sops://$TEMPDIR/secrets.yaml#/publicKey
EOF

  KUSTOMIZE_BIN="not-installed-kustomize"
  run --separate-stderr "$SKUST_BIN" build $TEMPDIR
  private_key=$(yq '.data.privateKey|@base64d' <<<"$output")
  assert_equal "$private_key" "$(<ssh/private.key)"
  public_key=$(yq '.data.publicKey|@base64d' <<<"$output")
  assert_equal "$public_key" "$(<ssh/public.key)"
  assert_success
}

@test "it should fail if file/literal has no defined name" {
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
  assert_output --partial "[ERROR]: invalid files source: [ref+sops://secrets.yaml], expected key=value"
}

@test "it should fail if uri is invalid" {
  cat >$TEMPDIR/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
secretGenerator:
  - name: test-secret
    files:
      - key=ref+xxxx://secrets.yaml
EOF
  run "$SKUST_BIN" build $TEMPDIR
  assert_failure
  assert_output --partial "no provider registered for scheme"
}

@test "it should fail if uri has no fragement" {
  cat >$TEMPDIR/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
secretGenerator:
  - name: test-secret
    files:
      - key=ref+sops://secrets.yaml
EOF
  run "$SKUST_BIN" build $TEMPDIR
  assert_failure
  assert_output --partial "Error unmarshalling input json: invalid character"
}

@test "it should fail if gives two folders" {
  run "$SKUST_BIN" build folder1 folder2
  assert_failure
  assert_output --partial "specify one path to kustomization.yaml"
}

@test "it should fail if gives two kustomization files" {
  touch $TEMPDIR/kustomization.yaml $TEMPDIR/kustomization.yml
  run "$SKUST_BIN" build $TEMPDIR
  assert_failure
  assert_output --partial "Found multiple kustomization files under"
}

@test "it should show global help if gives global -h" {
  run "$SKUST_BIN" -h build
  assert_output --partial "Build a kustomization target from a directory or URL"
}

@test "it should show build help if gives -h to build" {
  run "$SKUST_BIN" build -h
  assert_output --partial "Build a set of KRM resources using a 'kustomization.yaml' file"
}
