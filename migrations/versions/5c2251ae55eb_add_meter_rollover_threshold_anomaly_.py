"""add_meter_rollover_threshold_anomaly_type

Revision ID: 5c2251ae55eb
Revises: f9b153e088ae
Create Date: 2026-01-30 17:41:02.301550

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '5c2251ae55eb'
down_revision = '0012_clients_meter_fields'
branch_labels = None
depends_on = None


def upgrade():
    """Add METER_ROLLOVER_THRESHOLD to anomaly type constraint"""
    # Drop old constraint
    op.drop_constraint('ck_anomaly_type_valid', 'anomalies', type_='check')
    
    # Add new constraint with METER_ROLLOVER_THRESHOLD
    op.create_check_constraint(
        'ck_anomaly_type_valid',
        'anomalies',
        "anomaly_type IN ('NEGATIVE_CONSUMPTION', 'DOUBLE_SUBMISSION', 'LATE_SUBMISSION', "
        "'MISSING_BASELINE', 'MISSING_READING', 'ROLLOVER_WITHOUT_LIMIT', 'METER_ROLLOVER_THRESHOLD')"
    )


def downgrade():
    """Remove METER_ROLLOVER_THRESHOLD from anomaly type constraint"""
    # Drop new constraint
    op.drop_constraint('ck_anomaly_type_valid', 'anomalies', type_='check')
    
    # Restore old constraint without METER_ROLLOVER_THRESHOLD
    op.create_check_constraint(
        'ck_anomaly_type_valid',
        'anomalies',
        "anomaly_type IN ('NEGATIVE_CONSUMPTION', 'DOUBLE_SUBMISSION', 'LATE_SUBMISSION', "
        "'MISSING_BASELINE', 'MISSING_READING', 'ROLLOVER_WITHOUT_LIMIT')"
    )
