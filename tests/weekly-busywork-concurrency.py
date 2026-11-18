"""Exercise the installed cutoff SQL with two real PostgreSQL sessions waiting on an old action."""
import os
import select
import subprocess
import time

PSQL = ["psql", "-X", "-Atq", "-v", "ON_ERROR_STOP=1"]
PLAYER = "00000000-0000-4000-8000-000000000001"


def sql(query):
    return subprocess.run(
        [*PSQL, "-c", query], check=True, capture_output=True, text=True, timeout=15
    ).stdout.strip()


if os.environ.get("PGDATABASE") != "ih_busywork_test" or sql("select current_database()") != "ih_busywork_test":
    raise RuntimeError("disposable Busywork database required")

old_week = sql("select week_key(week_started()-interval '1 microsecond')")
sql(f"""
  DELETE FROM public.seasons WHERE week_key='{old_week}';
  UPDATE public.season_state SET current_week='{old_week}', mw='{old_week}', mhit=true;
  UPDATE public.players SET rate=0, week_pp=0, last_tick=week_started(), trophies=0;
""")
with subprocess.Popen(PSQL, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True) as old_action:
    old_action.stdin.write(f"""
      BEGIN;
      SET LOCAL test.busywork_week='{old_week}';
      SELECT (public.accrue('{PLAYER}')).id;
      UPDATE public.players SET week_pp=125 WHERE id='{PLAYER}';
    """)
    old_action.stdin.flush()
    if not select.select([old_action.stdout], [], [], 8)[0] or old_action.stdout.readline().strip() != PLAYER:
        old_action.kill()
        raise RuntimeError("old-week action did not acquire its scoring lock")

    workers = []
    try:
        for name in ("busywork_rollover_one", "busywork_rollover_two"):
            workers.append(subprocess.Popen(
                [*PSQL, "-c", "SELECT public.roll_week()"], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, env={**os.environ, "PGAPPNAME": name}
            ))
        deadline = time.monotonic() + 8
        while sql("""
            SELECT count(*) FROM pg_stat_activity
            WHERE application_name IN ('busywork_rollover_one','busywork_rollover_two')
              AND wait_event_type='Lock' AND wait_event='advisory'
        """) != "2":
            if time.monotonic() >= deadline:
                raise RuntimeError("rollovers did not both wait for the old-week action")
            time.sleep(0.05)

        old_action.stdin.write("COMMIT;\n\\q\n")
        old_action.stdin.flush()
        if old_action.wait(timeout=8):
            raise RuntimeError("old-week action failed")
        for worker in workers:
            _, error = worker.communicate(timeout=8)
            if worker.returncode:
                raise RuntimeError(error)
    finally:
        for worker in workers:
            if worker.poll() is None:
                worker.kill()
                worker.wait()
        if old_action.poll() is None:
            old_action.kill()

result = sql(f"""
  SELECT concat_ws(':', s.winner, s.top, p.trophies, p.week_pp)
  FROM public.seasons s JOIN public.players p ON p.id=s.winner WHERE s.week_key='{old_week}'
""")
if result != f"{PLAYER}:125:1:0":
    raise RuntimeError(f"waiting rollover failed to record the old action exactly once: {result}")

stale = subprocess.run(
    [*PSQL, "-c", f"SET test.busywork_week='{old_week}'; SELECT public.accrue('{PLAYER}');"],
    capture_output=True, text=True, timeout=8
)
if stale.returncode == 0 or "The office week changed" not in stale.stderr:
    raise RuntimeError("old-week request could mutate the new week")
print("PASS concurrent Busywork cutoff: waits for the old action, closes once, and rejects a stale action")
