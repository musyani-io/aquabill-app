"""Add meter fields to clients table

Revision ID: 0012_clients_meter_fields
Revises: 0011_authentication
Create Date: 2026-01-28 16:30:00.000000

"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "0012_clients_meter_fields"
down_revision = "0011_authentication"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add meter fields to clients table
    op.add_column(
        "clients",
        sa.Column("meter_serial_number", sa.String(50), nullable=False, unique=True),
    )
    op.add_column(
        "clients", sa.Column("initial_meter_reading", sa.Float, nullable=False)
    )

    # Create unique constraint for meter_serial_number
    op.create_unique_constraint(
        "uq_clients_meter_serial", "clients", ["meter_serial_number"]
    )


def downgrade() -> None:
    # Remove the columns and constraint
    op.drop_constraint("uq_clients_meter_serial", "clients", type_="unique")
    op.drop_column("clients", "initial_meter_reading")
    op.drop_column("clients", "meter_serial_number")
