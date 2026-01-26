"""Add max_meter_value field to meter_assignments for rollover handling.

Revision ID: 0010_meter_assignment_max_value
Revises: 0009_sms_messages
Create Date: 2026-01-26 12:00:00.000000

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "0010_meter_assignment_max_value"
down_revision = "0009_sms_messages"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add max_meter_value column to meter_assignments
    op.add_column(
        "meter_assignments",
        sa.Column(
            "max_meter_value",
            sa.Numeric(precision=9, scale=4),
            nullable=True,
            comment="Meter rollover limit (e.g., 999999.9999). NULL if unknown.",
        ),
    )

    # Add constraint for positive values
    op.create_check_constraint(
        "ck_assignment_max_meter_value_positive",
        "meter_assignments",
        "max_meter_value IS NULL OR max_meter_value > 0",
    )


def downgrade() -> None:
    op.drop_constraint("ck_assignment_max_meter_value_positive", "meter_assignments")
    op.drop_column("meter_assignments", "max_meter_value")
