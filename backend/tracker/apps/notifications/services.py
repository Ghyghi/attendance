"""
Notification creation service.

Each function here corresponds to exactly one user-facing event and is
called from the view/serializer that causes that event. Centralizing the
copy (title/body text) here — rather than inlining Notification.objects
.create() calls at each call site — means there's one place to edit
wording later, and the call sites themselves stay simple, single-line
hooks that are easy to spot when reading the surrounding view code.

Events covered (per project spec):
  Teacher:
    - added_to_module:  teacher added to a classroom's `teachers` M2M
  Student:
    - added_to_module:  student added to a classroom's `students` M2M
    - session_started:  a session starts for a classroom they're enrolled in
    - status_changed:   a teacher overrides their attendance record's status
    - face_enrolled:    their face enrollment completes (5th event, added
                         alongside the original 4 as a small, clearly-scoped
                         "something happened to your account" notification)

Admins receive no notifications anywhere in this module, per project spec.
"""
from .models import Notification


def notify_added_to_module(user, classroom):
    """
    Fired when a user (teacher or student) is added to a classroom's
    teacher or student roster. Same notification shape for both roles —
    the role itself is implicit in who the recipient is, so the copy
    doesn't need to branch on it.
    """
    Notification.objects.create(
        recipient=user,
        kind=Notification.Kind.ADDED_TO_MODULE,
        title='Added to a module',
        body=f'You have been added to "{classroom.name}".',
    )


def notify_session_started(student, session):
    """
    Fired once per enrolled student when a teacher starts a new
    AttendanceSession for a classroom that student belongs to.
    Caller (SessionListCreateView) fans this out to every enrolled
    student — see that view for the loop.
    """
    Notification.objects.create(
        recipient=student,
        kind=Notification.Kind.SESSION_STARTED,
        title='Attendance session started',
        body=f'A session for "{session.classroom.name}" has started.',
        session=session,
    )


def notify_status_changed(record):
    """
    Fired when a teacher sets/changes a student's attendance record
    status — covers both TeacherOverrideRecordView (flipping an existing
    record's status) and TeacherMarkAbsentView (creating a new absent
    record for a student who never submitted). Both are teacher actions
    that determine the student's status for a session, so both notify.
    """
    Notification.objects.create(
        recipient=record.student,
        kind=Notification.Kind.STATUS_CHANGED,
        title='Attendance status changed',
        body=(
            f'Your status for "{record.session.classroom.name}" '
            f'was changed to {record.get_status_display()} by your teacher.'
        ),
        session=record.session,
    )


def notify_face_enrolled(student):
    """
    Fired when an admin successfully enrolls (or re-enrolls) a student's
    face via EnrollFaceView. Lets the student know their account is ready
    for face-verified attendance submission.
    """
    Notification.objects.create(
        recipient=student,
        kind=Notification.Kind.FACE_ENROLLED,
        title='Face enrollment complete',
        body='Your face has been enrolled. You can now submit attendance.',
    )