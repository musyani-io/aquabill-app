"""
Holiday configuration using the Python holidays library.

Automatically detects public holidays for Tanzania using the `holidays` library.
No hardcoding needed - handles variable holidays like Easter automatically.
"""

from datetime import date
from typing import List, Optional
import holidays as holidays_lib


def get_holidays(year: Optional[int] = None) -> List[date]:
    """
    Get the holiday list for Tanzania and a specific year.
    
    Uses the Python holidays library to automatically detect holidays.
    
    Args:
        year: Specific year to get holidays for. If None, returns combined
              holidays for current and next 2 years (for future-proofing)
    
    Returns:
        List of holiday dates for Tanzania
    
    Examples:
        >>> get_holidays()  # Tanzania, 2024-2026
        >>> get_holidays(2026)  # Tanzania, just 2026
    """
    holiday_list = []
    
    if year is None:
        # Get holidays for current year and next 2 years for future-proofing
        import datetime
        current_year = datetime.date.today().year
        years = [current_year, current_year + 1, current_year + 2]
    else:
        years = [year]
    
    # Create a Tanzania holidays instance for the specified years
    tz_holidays = holidays_lib.Tanzania(years=years)
    
    # Extract all holiday dates
    holiday_list = list(tz_holidays.keys())
    
    # Remove duplicates and sort
    return sorted(list(set(holiday_list)))


def is_holiday(check_date: date) -> bool:
    """
    Check if a specific date is a holiday in Tanzania.
    
    Args:
        check_date: Date to check
    
    Returns:
        True if the date is a holiday, False otherwise
    
    Examples:
        >>> is_holiday(date(2026, 1, 1))  # New Year - True
        >>> is_holiday(date(2026, 1, 5))  # Random weekday - False
    """
    tz_holidays = holidays_lib.Tanzania(years=check_date.year)
    return check_date in tz_holidays


def get_holiday_name(check_date: date) -> Optional[str]:
    """
    Get the name of a holiday on a specific date in Tanzania.
    
    Args:
        check_date: Date to check
    
    Returns:
        Holiday name if the date is a holiday, None otherwise
    
    Examples:
        >>> get_holiday_name(date(2026, 1, 1))  # 'New Year's Day'
        >>> get_holiday_name(date(2026, 1, 5))  # None
    """
    tz_holidays = holidays_lib.Tanzania(years=check_date.year)
    return tz_holidays.get(check_date)
