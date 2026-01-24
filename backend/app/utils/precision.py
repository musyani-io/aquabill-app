"""Precision and rounding utilities."""

from decimal import Decimal, ROUND_HALF_UP


def round_to_4_decimals(value: float) -> float:
    """Round value to 4 decimal places."""
    d = Decimal(str(value))
    return float(d.quantize(Decimal('0.0001'), rounding=ROUND_HALF_UP))


def format_tza(amount: int) -> str:
    """Format amount in Tanzanian Shillings."""
    return f"TZS {amount:,}"


def consume_from_readings(previous: float, current: float, max_reading: float = 99999.9999) -> float:
    """
    Calculate consumption from previous and current readings.
    
    Handles meter rollover:
    - If current >= previous: consumption = current - previous
    - If current < previous and previous >= 90,000: rollover detected
    """
    previous = round_to_4_decimals(previous)
    current = round_to_4_decimals(current)
    
    if current >= previous:
        consumption = current - previous
    elif previous >= 90000:
        # Meter rollover
        consumption = (max_reading - previous) + current
    else:
        # Invalid: meter went backwards without rollover
        raise ValueError("Invalid reading: meter went backwards")
    
    return round_to_4_decimals(consumption)
