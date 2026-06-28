"""
Shared short-ID generator for primary keys across every app.

Design notes:
  - 7-digit numeric string IDs (e.g. "4821093"), NOT UUIDs. A real UUID is
    36 characters; this is a deliberately short, human-readable identifier
    space at the user's explicit request.
  - 10,000,000 possible values (0000000-9999999). Collision probability
    is non-trivial as a table grows (birthday-paradox math: ~50% chance
    of at least one collision once a table passes roughly 3,800 rows),
    so this is NOT a fire-and-forget random.choices() call — it actually
    queries the target model for uniqueness and retries on collision.
  - Leading zeros are preserved (it's a CharField, not an IntegerField).

IMPORTANT — why this is NOT a closure-returning factory:
  An earlier version of this module had `make_short_id_default(app, model)`
  return a nested closure (`def _default(): ...`) to capture the app/model
  per call site. That breaks Django's makemigrations: when a CharField's
  `default=` is a closure, Django's migration serializer cannot write an
  import statement for it (a closure isn't independently importable —
  it only exists inside one specific call to the factory) and
  makemigrations fails with:
      ValueError: Could not find function _default in apps.common.id_generator.
  The fix is `functools.partial`, which Django's MigrationWriter has
  explicit, built-in support for serializing: it writes out a reference
  to the underlying module-level function (`generate_short_id` below)
  plus its bound arguments, both of which ARE independently importable/
  serializable. `generate_short_id` itself must stay a plain top-level
  function for this to work — do not nest it inside another function.
"""
import random
from functools import partial

SHORT_ID_LENGTH = 7
SHORT_ID_MAX_VALUE = 10 ** SHORT_ID_LENGTH  # 10,000,000
MAX_GENERATION_ATTEMPTS = 20


def _generate_candidate() -> str:
    """A single random 7-digit numeric string, zero-padded."""
    return str(random.randint(0, SHORT_ID_MAX_VALUE - 1)).zfill(SHORT_ID_LENGTH)


def generate_short_id(app_label: str, model_name: str) -> str:
    """
    Generates a unique 7-digit short ID for the given model, retrying on
    collision against the live table.

    Must remain a top-level, module-scoped function (not nested inside
    another function/closure) — see module docstring for why. Always
    called via functools.partial(generate_short_id, app_label, model_name)
    so the result is itself a serializable, importable default.

    Bootstrap guard: this default is evaluated by Django's built-in
    `check_user_model` system check (and by any other code that
    instantiates a bare, unsaved model instance), which runs
    automatically before `makemigrations`, `migrate`, and most other
    management commands — including on a completely fresh database,
    before that first `migrate` has created the table this function
    wants to query for collisions. Without this guard, that pre-flight
    check itself raises `OperationalError: no such table`, which blocks
    `migrate` from ever running on a fresh checkout — a chicken-and-egg
    failure that has nothing to do with real ID collisions (an empty,
    not-yet-existing table can't contain a collision). When the table
    doesn't exist yet, skip the collision check and return a random
    candidate directly; once the table exists, the normal collision-
    checked path below applies as usual.
    """
    from django.apps import apps
    from django.db import connection
    from django.db.utils import OperationalError

    model = apps.get_model(app_label, model_name)

    if model._meta.db_table not in connection.introspection.table_names():
        return _generate_candidate()

    for _ in range(MAX_GENERATION_ATTEMPTS):
        candidate = _generate_candidate()
        try:
            exists = model.objects.filter(pk=candidate).exists()
        except OperationalError:
            # Table existence can change between the check above and this
            # query (e.g. mid-migration); fail safe to "no collision" rather
            # than crash a bootstrap that the table-names check missed.
            return candidate
        if not exists:
            return candidate

    # Exhausting 20 attempts at random 7-digit collision avoidance means
    # the table is approaching saturation of the entire 10,000,000-value
    # space — at that point collisions are no longer a rare-event
    # problem and the ID length itself needs to grow. Failing loudly
    # here is intentional: a silently-reused ID would corrupt data (two
    # rows fighting over one PK), which is far worse than a clear,
    # diagnosable error at creation time.
    raise RuntimeError(
        f'Could not generate a unique {SHORT_ID_LENGTH}-digit short ID '
        f'for {app_label}.{model_name} after {MAX_GENERATION_ATTEMPTS} '
        f'attempts. The ID space may be approaching saturation — '
        f'consider increasing SHORT_ID_LENGTH.'
    )


def make_short_id_default(app_label: str, model_name: str):
    """
    Returns a functools.partial bound to (app_label, model_name) —
    NOT a closure — suitable for a CharField's `default=`. Django's
    migration serializer knows how to write this out as importable
    Python source (a reference to generate_short_id plus its two
    string arguments), which is exactly why it must be a partial and
    not a nested function.
    """
    return partial(generate_short_id, app_label, model_name)