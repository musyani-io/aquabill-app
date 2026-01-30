"""
Working day utility functions for cycle scheduling in Tanzania.

Implements working day (business day) calculations where weekends are
Saturday and Sunday, and holidays are automatically detected for Tanzania.
"""

from datetime import date, timedelta
from typing import List, Optional

from app.config.holidays import is_holiday


def is_working_day(
    check_date: date, 
    holidays: Optional[List[date]] = None,
) -> bool:
    """
    Check if a date is a working day (not weekend or holiday) in Tanzania.

    Working days: Monday (0) to Friday (4)
    Weekends: Saturday (5), Sunday (6)

    Args:
        check_date: Date to check
        holidays: List of custom holiday dates (overrides default Tanzania holidays)

    Returns:
        True if the date is a working day, False otherwise
    """
    # Check if it's a weekend (Saturday=5, Sunday=6)
    if check_date.weekday() >= 5:  # Saturday or Sunday
        return False

    # If custom holidays provided, use those
    if holidays is not None:
        if check_date in holidays:
            return False
    else:
        # Otherwise use automatic holiday detection for Tanzania
        if is_holiday(check_date):
            return False

    return True


def get_nearest_previous_working_day(
    target_date: date, 
    holidays: Optional[List[date]] = None,
) -> date:
    """
    Get the nearest previous working day from a target date in Tanzania.

    If the target date is a working day, returns the target date.
    If the target date is a weekend or holiday, moves backward until finding a working day.

    Args:
        target_date: The target date
        holidays: List of custom holiday dates (overrides default Tanzania holidays)

    Returns:
        The nearest previous working day
    """
    current = target_date

    # Move backward until we find a working day
    max_iterations = 365  # Safety limit to prevent infinite loop
    iterations = 0

    while not is_working_day(current, holidays) and iterations < max_iterations:
        current -= timedelta(days=1)
        iterations += 1

    return current


def get_nearest_next_working_day(
    target_date: date, 
    holidays: Optional[List[date]] = None,
) -> date:
    """
    Get the nearest next working day from a target date in Tanzania.

    If the target date is a working day, returns the target date.
    If the target date is a weekend or holiday, moves forward until finding a working day.

    Args:
        target_date: The target date
        holidays: List of custom holiday dates (overrides default Tanzania holidays)

    Returns:
        The nearest next working day
    """
    current = target_date

    # Move forward until we find a working day
    max_iterations = 365  # Safety limit to prevent infinite loop
    iterations = 0

    while not is_working_day(current, holidays) and iterations < max_iterations:
        current += timedelta(days=1)
        iterations += 1

    return current


def adjust_target_date_to_working_day(
    target_date: date, 
    prefer: str = "previous", 
    holidays: Optional[List[date]] = None,
) -> date:
    """
    Adjust a target date to the nearest working day in Tanzania.

    This is used for cycle scheduling when the target reading date
    falls on a weekend or holiday.

    Args:
        target_date: The proposed target date
        prefer: 'previous' (default) to prefer working day before holiday,
                'next' to prefer working day after holiday
        holidays: List of custom holiday dates (overrides default Tanzania holidays)

    Returns:
        The adjusted target date (a working day)
    """
    if is_working_day(target_date, holidays):
        return target_date

    if prefer == "previous":
        return get_nearest_previous_working_day(target_date, holidays)
    else:
        return get_nearest_next_working_day(target_date, holidays)
