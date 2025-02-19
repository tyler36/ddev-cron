setup() {
  set -eu -o pipefail

  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=~/tmp/ddev-cron
  mkdir -p $TESTDIR
  export PROJNAME=ddev-cron
  export DDEV_NON_INTERACTIVE=true
  ddev delete -Oy ${PROJNAME} || true
  cd "${TESTDIR}"
  ddev config --project-name=${PROJNAME}
  ddev start -y
  echo "# ddev started at $(date)" >&3
}

teardown() {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME}
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
}

health_checks() {
  # Make sure cron process is running.
  # We use `time_cron_checks` to check the example cron job is actually correctly implemented.
  # This is due to the need to test the health-check when there are no jobs added.
  ddev exec 'sudo killall -0 cron'
}

time_cron_checks() {
  # ASSERT time.log was written to
  grep UTC time.log

  # ASSERT job displays under current user's crontab
  ddev exec crontab -l | grep '* * * * * date | tee -a /var/www/html/time.log'
}

@test "install from directory" {
  set -eu -o pipefail
  cd ${TESTDIR}
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev add-on get ${DIR}
  # Set the example cron job as an actual cron job.
  mv ./.ddev/web-build/time.cron.example ./.ddev/web-build/time.cron
  ddev restart

  # The example runs every minute so we should wait at least the length.
  sleep 61

  # Check service works
  health_checks

  # Check example cron job works
  time_cron_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  echo "# ddev add-on get ddev/ddev-cron with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev add-on get ddev/ddev-cron
  # Set the example cron job as an actual cron job.
  mv ./.ddev/web-build/time.cron.example ./.ddev/web-build/time.cron
  ddev restart

  # The example runs every minute so we should wait at least the length.
  sleep 61

  # Check service works
  health_checks

  # Check example cron job works
  time_cron_checks
}

@test "services work when no valid jobs are present" {
  set -eu -o pipefail
  cd ${TESTDIR}
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev add-on get ${DIR}
  ddev restart

  # We should wait at least one cycle.
  sleep 61

  # Check service works
  health_checks
}
