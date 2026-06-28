from django.urls import path
from .views import (
    SessionListCreateView, SessionDetailView,
    SessionRecordsView, SubmitAttendanceView,
    StudentAttendanceHistoryView, StudentModuleStatsView,
    TeacherMarkAbsentView, TeacherOverrideRecordView,
    AbsentStudentsView,
)

urlpatterns = [
    # Teacher: manage sessions
    path('sessions/',                                       SessionListCreateView.as_view(),  name='session-list'),
    path('sessions/<int:pk>/',                              SessionDetailView.as_view(),      name='session-detail'),
    path('sessions/<int:session_id>/records/',              SessionRecordsView.as_view(),     name='session-records'),

    # Teacher: absent-student helpers
    path('sessions/<int:session_id>/absent-students/',      AbsentStudentsView.as_view(),     name='session-absent-students'),
    path('sessions/<int:session_id>/mark-absent/',          TeacherMarkAbsentView.as_view(),  name='session-mark-absent'),

    # Teacher: override a single record's status
    path('records/<int:record_id>/override/',               TeacherOverrideRecordView.as_view(), name='record-override'),

    # Student: submit attendance
    path('submit/',                                         SubmitAttendanceView.as_view(),   name='submit-attendance'),
    path('history/',                                        StudentAttendanceHistoryView.as_view(), name='attendance-history'),
    path('module-stats/',                                   StudentModuleStatsView.as_view(), name='module-stats'),
]