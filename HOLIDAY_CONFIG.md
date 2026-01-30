# Holiday Configuration Guide

## Overview

The aquabill app uses the Python `holidays` library to automatically detect public holidays for any country. **No hardcoding needed!** The system automatically handles:

- Fixed holidays (New Year, Christmas, etc.)
- Variable holidays (Easter, Ascension Day, etc.)
- Country-specific holiday rules
- Lunar calendar holidays where applicable
- Custom holidays (optional)

## Supported Countries

Any country supported by the `holidays` library! Common examples:

- **Tanzania** (`tz`) - Default
- **Kenya** (`ke`)
- **Uganda** (`ug`)
- **South Africa** (`za`)
- **USA** (`us`)
- **India** (`in`)
- And [many more](https://github.com/vacanza/python-holidays#supported-countries)

## How It Works

### 1. Backend (Python)

**Holiday Functions** (`app/config/holidays.py`):

- `is_holiday(date, country)` - Check if date is a holiday
- `get_holiday_name(date, country)` - Get the holiday name
- `get_holidays(country, year)` - Get all holidays for a year

```python
from app.config.holidays import is_holiday, get_holiday_name

# Check if a date is a holiday
if is_holiday(date(2026, 1, 1), 'tz'):
    print("New Year's Day")

# Get holiday name
name = get_holiday_name(date(2026, 1, 1), 'tz')
print(name)  # "New Year's Day"

# Get all holidays for a year
holidays = get_holidays('ke', 2026)
```

**Working Day Functions** (`app/utils/working_days.py`):

- All functions automatically use the `holidays` library
- No need to manage holiday lists

```python
from app.utils.working_days import is_working_day, adjust_target_date_to_working_day

# Use Tanzania holidays (default)
is_working_day(date(2026, 1, 25), country='tz')

# Use Kenya holidays
is_working_day(date(2026, 1, 25), country='ke')

# Adjust date to working day
adjusted = adjust_target_date_to_working_day(
    date(2026, 1, 25),
    country='ke'
)
```

### 2. API Endpoint

**POST /cycles/schedule**

Country parameter passed in request:

```bash
curl -X POST http://localhost:8000/cycles/schedule \
  -H "Content-Type: application/json" \
  -d '{
    "start_date": "2026-01-01",
    "num_cycles": 12,
    "country": "tz"
  }'
```

Supported values: Any ISO 3166-1 alpha-2 country code (e.g., `tz`, `ke`, `ug`, `za`)

### 3. Frontend (Flutter)

**ScheduleCyclesRequest** (`mobile/lib/data/remote/cycle_api_client.dart`):

```dart
final request = ScheduleCyclesRequest(
  startDate: DateTime(2026, 1, 1),
  numCycles: 12,
  country: 'tz',
);
```

**UI Dialog** (`mobile/lib/ui/cycle_management_screen.dart`):

- Dropdown selector for country
- Passes country to API request

## Adding a New Country

**Just use the country code!** No configuration needed.

```python
# Python
is_working_day(date(2026, 1, 25), country='ug')  # Uganda
is_working_day(date(2026, 1, 25), country='za')  # South Africa

# API
POST /cycles/schedule with "country": "ug"

# Flutter
ScheduleCyclesRequest(..., country: 'ug')
```

The `holidays` library automatically handles all holidays for that country.

## Advanced: Custom Holidays

For cases where you need to add custom holidays on top of the detected ones:

```python
from app.utils.working_days import is_working_day

# Use custom holidays list
custom_holidays = [date(2026, 1, 15)]  # Your custom holiday
is_working_day(date(2026, 1, 15), holidays=custom_holidays)  # Will use custom list
```

## Testing

Run holiday tests:

```bash
pytest tests/test_working_days.py -v
```

Tests cover:

- Weekday/weekend detection
- Holiday detection (automatic)
- Working day calculations (previous/next)
- Cycle scheduling with adjustments
- Multiple countries (Tanzania, Kenya)
- Edge cases

## How Holidays Are Detected

The `holidays` library uses:

1. **ISO/International Standards** for fixed holidays
2. **Country-specific legislation** for national holidays
3. **Easter calculations** for movable Christian holidays
4. **Lunar calendars** for Islamic/Buddhist holidays (where applicable)

For Tanzania, it includes:

- New Year's Day (Jan 1)
- Zanzibar Revolution Day (Jan 12)
- Good Friday, Easter Monday (variable)
- Labour Day (May 1)
- Saba Saba Day (Jul 7)
- Independence Day (Dec 9)
- Christmas (Dec 25)
- Boxing Day (Dec 26)
- And others recognized by the government

For Kenya, it includes:

- New Year's Day (Jan 1)
- Good Friday, Easter Monday (variable)
- Labour Day (May 1)
- Madaraka Day (Jun 15)
- Kenyatta Day (Oct 20)
- Christmas (Dec 25)
- Boxing Day (Dec 26)
- And others

## Troubleshooting

### "Country not supported" Error

The country code you used is not supported by the `holidays` library.

**Solution:** Check [supported countries list](https://github.com/vacanza/python-holidays#supported-countries)

### Holiday Dates Wrong

The `holidays` library might be using a different holiday list than expected.

**Solutions:**

1. Check the [holidays library documentation](https://github.com/vacanza/python-holidays)
2. Add custom holidays for your specific needs
3. File an issue on the holidays library GitHub

### No Holidays Detected

Make sure you're using the correct country code (ISO 3166-1 alpha-2):

- Tanzania: `tz` (not `tanzania`)
- Kenya: `ke` (not `kenya`)

```python
# ✅ Correct
is_holiday(date(2026, 1, 1), 'tz')

# ❌ Wrong
is_holiday(date(2026, 1, 1), 'tanzania')
```

## Performance Notes

- Holiday detection is cached by the `holidays` library
- No database queries needed
- Automatic caching of holiday lists per year/country
- Minimal memory footprint

## Why Use `holidays` Library?

**Benefits:**

- ✅ No hardcoding needed
- ✅ Automatically updated when library is updated
- ✅ Supports 200+ countries
- ✅ Handles variable holidays (Easter, lunar calendar)
- ✅ Actively maintained
- ✅ Widely used in production systems

**vs Hardcoding:**

- ❌ No need to manually update lists yearly
- ❌ No risk of missing holidays
- ❌ No maintenance burden
- ❌ Easily switch between countries

## Future Enhancements

1. **Custom Holiday Overrides:** Database table for admin to override holidays per tenant
2. **Holiday Calendar API:** Expose `/holidays` endpoint for frontend
3. **Regional Holidays:** Support province/state-level holidays
4. **Holiday Notifications:** Alert when holiday affects cycle dates

## References

- [Python Holidays Library](https://github.com/vacanza/python-holidays)
- [ISO 3166-1 Country Codes](https://en.wikipedia.org/wiki/ISO_3166-1)
- [Tanzania Public Holidays](https://en.wikipedia.org/wiki/Public_holidays_in_Tanzania)
- [Kenya Public Holidays](https://en.wikipedia.org/wiki/Public_holidays_in_Kenya)
