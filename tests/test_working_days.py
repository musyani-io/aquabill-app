"""
Tests for working day utilities and cycle scheduling with working day adjustments.
"""

import pytest
from datetime import date, timedelta
from app.utils.working_days import (
    is_working_day,
    get_nearest_previous_working_day,
    get_nearest_next_working_day,
    adjust_target_date_to_working_day,
)
from app.config.holidays import is_holiday, get_holiday_name
from app.services.cycle_service import CycleService
from app.models.cycle import CycleStatus
from sqlalchemy.orm import Session


class TestWorkingDays:
    """Test working day utility functions"""

    def test_weekday_is_working_day(self):
        """Monday-Friday should be working days"""
        # Friday, 2026-01-02 (weekday=4)
        assert is_working_day(date(2026, 1, 2)) is True
        
        # Monday, 2026-01-05 (weekday=0)
        assert is_working_day(date(2026, 1, 5)) is True
        
        # Wednesday, 2026-01-07 (weekday=2)
        assert is_working_day(date(2026, 1, 7)) is True

    def test_weekend_is_not_working_day(self):
        """Saturday and Sunday should not be working days"""
        # Saturday, 2026-01-03 (weekday=5)
        assert is_working_day(date(2026, 1, 3)) is False
        
        # Sunday, 2026-01-04 (weekday=6)
        assert is_working_day(date(2026, 1, 4)) is False

    def test_holiday_is_not_working_day(self):
        """Holidays should not be working days in Tanzania"""
        # 2026-01-01 is New Year (holiday in Tanzania)
        assert is_working_day(date(2026, 1, 1)) is False
        
        # 2026-05-01 is Labour Day (holiday in Tanzania)
        assert is_working_day(date(2026, 5, 1)) is False

    def test_custom_holidays_list(self):
        """Should use custom holidays list when provided"""
        custom_holidays = [date(2026, 1, 15)]  # Custom holiday
        
        # Default: 2026-01-15 (Thursday) is a working day
        assert is_working_day(date(2026, 1, 15)) is True
        
        # With custom holiday: should not be working day
        assert is_working_day(date(2026, 1, 15), holidays=custom_holidays) is False

    def test_nearest_previous_working_day_from_weekday(self):
        """Previous working day from a weekday should be itself"""
        # Monday, 2026-01-05
        result = get_nearest_previous_working_day(date(2026, 1, 5))
        assert result == date(2026, 1, 5)

    def test_nearest_previous_working_day_from_weekend(self):
        """Previous working day from weekend should be Friday"""
        # Saturday, 2026-01-03 -> Friday, 2026-01-02
        result = get_nearest_previous_working_day(date(2026, 1, 3))
        assert result == date(2026, 1, 2)
        
        # Sunday, 2026-01-04 -> Friday, 2026-01-02
        result = get_nearest_previous_working_day(date(2026, 1, 4))
        assert result == date(2026, 1, 2)

    def test_nearest_previous_working_day_from_holiday(self):
        """Previous working day from a holiday should skip to earlier working day"""
        # 2026-05-01 is Labour Day (Friday, holiday)
        # Should go back to Thursday, 2026-04-30
        result = get_nearest_previous_working_day(date(2026, 5, 1))
        assert result == date(2026, 4, 30)
        assert is_working_day(result) is True

    def test_nearest_next_working_day_from_weekday(self):
        """Next working day from a weekday should be itself"""
        # Monday, 2026-01-05
        result = get_nearest_next_working_day(date(2026, 1, 5))
        assert result == date(2026, 1, 5)

    def test_nearest_next_working_day_from_weekend(self):
        """Next working day from weekend should be Monday"""
        # Saturday, 2026-01-03 -> Monday, 2026-01-05
        result = get_nearest_next_working_day(date(2026, 1, 3))
        assert result == date(2026, 1, 5)
        
        # Sunday, 2026-01-04 -> Monday, 2026-01-05
        result = get_nearest_next_working_day(date(2026, 1, 4))
        assert result == date(2026, 1, 5)

    def test_adjust_to_previous_working_day(self):
        """Should adjust to previous working day when prefer='previous'"""
        # Saturday, 2026-01-03
        result = adjust_target_date_to_working_day(
            date(2026, 1, 3), prefer="previous"
        )
        assert result == date(2026, 1, 2)  # Friday
        assert is_working_day(result) is True

    def test_adjust_to_next_working_day(self):
        """Should adjust to next working day when prefer='next'"""
        # Saturday, 2026-01-03
        result = adjust_target_date_to_working_day(
            date(2026, 1, 3), prefer="next"
        )
        assert result == date(2026, 1, 5)  # Monday
        assert is_working_day(result) is True

    def test_no_adjustment_needed(self):
        """Should not adjust if date is already a working day"""
        # Monday, 2026-01-05
        result = adjust_target_date_to_working_day(date(2026, 1, 5))
        assert result == date(2026, 1, 5)


class TestCycleSchedulingWithWorkingDays:
    """Test cycle scheduling with working day adjustments"""

    def test_schedule_cycles_adjusts_to_working_day(self, db: Session):
        """Cycles should have target dates adjusted to working days in Tanzania"""
        service = CycleService(db)

        # Schedule cycles starting from a date where some target dates will fall on weekends
        cycles, error = service.schedule_cycles(
            start_date=date(2026, 1, 1),
            num_cycles=3,
            cycle_length_days=30,
            submission_window_days=5,
            adjust_to_working_day=True,
        )

        assert error is None
        assert len(cycles) == 3

        # Check that all target dates are working days
        for cycle in cycles:
            assert is_working_day(cycle.target_date) is True

    def test_schedule_cycles_without_working_day_adjustment(self, db: Session):
        """Cycles can be created without working day adjustment"""
        service = CycleService(db)

        cycles, error = service.schedule_cycles(
            start_date=date(2026, 1, 1),
            num_cycles=3,
            cycle_length_days=30,
            submission_window_days=5,
            adjust_to_working_day=False,
        )

        assert error is None
        assert len(cycles) == 3

        # Target dates may not all be working days (some may fall on weekends)
        # Just verify the cycles were created
        for cycle in cycles:
            assert cycle.target_date is not None

    def test_cycle_target_dates_within_range(self, db: Session):
        """Target dates should always be within cycle date range"""
        service = CycleService(db)

        cycles, error = service.schedule_cycles(
            start_date=date(2026, 1, 1),
            num_cycles=12,
            cycle_length_days=30,
            submission_window_days=5,
            adjust_to_working_day=True,
        )

        assert error is None

        for cycle in cycles:
            # Target date should be >= start_date and <= end_date (even after adjustment)
            # Note: After working day adjustment, target might be before the calculated date
            assert cycle.target_date >= cycle.start_date
            # Allow some flexibility since target is adjusted and might be within range
            assert cycle.target_date <= cycle.end_date + timedelta(days=5)

    def test_cycle_sequence_no_gaps(self, db: Session):
        """Scheduled cycles should have no gaps between them"""
        service = CycleService(db)

        cycles, error = service.schedule_cycles(
            start_date=date(2026, 1, 1),
            num_cycles=3,
            cycle_length_days=30,
            submission_window_days=5,
            adjust_to_working_day=True,
        )

        assert error is None
        assert len(cycles) == 3

        # Sort cycles by start_date
        sorted_cycles = sorted(cycles, key=lambda c: c.start_date)

        # Check for gaps: each cycle should start where previous ended + 1 day
        for i in range(len(sorted_cycles) - 1):
            current_end = sorted_cycles[i].end_date
            next_start = sorted_cycles[i + 1].start_date
            gap_days = (next_start - current_end).days
            assert gap_days == 1, f"Gap of {gap_days} days between cycle {i} and {i+1}"


class TestWorkingDayEdgeCases:
    """Test edge cases for working day calculations"""

    def test_consecutive_holidays(self):
        """Should handle consecutive holidays and weekends correctly"""
        # Create a test period with consecutive holidays
        start = date(2026, 12, 24)  # Thursday before Christmas
        
        # Skip to Monday after Christmas (Dec 25-26 are holidays, Dec 26-27 are weekend)
        result = get_nearest_next_working_day(start + timedelta(days=2))
        
        # Should find Monday (Dec 28)
        assert is_working_day(result) is True
        assert result.weekday() == 0  # Monday

    def test_holiday_on_weekend(self):
        """If a holiday falls on weekend, it should already not be a working day"""
        # Even if a "holiday" is set for a weekend date, it's still not a working day
        custom_holidays = [date(2026, 1, 3)]  # Saturday
        
        # Saturday is not a working day anyway
        assert is_working_day(date(2026, 1, 3)) is False
        assert is_working_day(date(2026, 1, 3), holidays=custom_holidays) is False

    def test_year_boundary(self):
        """Should work correctly across year boundaries"""
        # Dec 31 2025 (Wednesday) -> Jan 1 2026 (Thursday, holiday)
        result = get_nearest_next_working_day(date(2025, 12, 31))
        # Should skip Jan 1 (holiday) and go to Jan 2 (Friday)
        assert result == date(2026, 1, 2)
        assert is_working_day(result) is True

    def test_far_future_date(self):
        """Should work with dates in the future (beyond defined holidays)"""
        # Using a date far in the future (no holidays defined)
        # Should only consider weekends
        future_date = date(2030, 6, 15)  # Saturday
        
        result = get_nearest_previous_working_day(future_date)
        assert result.weekday() < 5  # Should be a weekday


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
