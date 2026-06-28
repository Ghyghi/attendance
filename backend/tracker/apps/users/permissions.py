from rest_framework.permissions import BasePermission


class IsAdmin(BasePermission):
    """Only users with role='admin' are allowed."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_admin)


class IsTeacher(BasePermission):
    """Only users with role='teacher' are allowed."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_teacher)


class IsStudent(BasePermission):
    """Only users with role='student' are allowed."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.is_student)


class IsAdminOrTeacher(BasePermission):
    """Admins and teachers are allowed."""
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            (request.user.is_admin or request.user.is_teacher)
        )

class IsAdminOrTeacherOrStudent(BasePermission):
    """Everyone in the school is allowed"""
    def has_permission(self, request, view):
        return bool(
            request.user and
            request.user.is_authenticated and
            (request.user.is_admin or request.user.is_teacher or request.user.is_student)
        )


class IsSameSchool(BasePermission):
    """
    Object-level permission: the requesting user must belong
    to the same school as the object being accessed.
    The object must have a .school_id (or .school) attribute.
    """
    def has_object_permission(self, request, view, obj):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.school_id is None:
            return False
        # Compare by ID only — avoids ambiguity between FK instances
        # and raw ids, and avoids an extra query to resolve obj.school.
        # NOTE: this == comparison works identically whether school_id is
        # an int (old schema) or a 7-digit short-ID string (new schema) —
        # no type-specific logic exists here to break.
        obj_school_id = getattr(obj, 'school_id', None)
        if obj_school_id is None:
            obj_school = getattr(obj, 'school', None)
            obj_school_id = obj_school.id if obj_school else None
        return obj_school_id is not None and obj_school_id == request.user.school_id