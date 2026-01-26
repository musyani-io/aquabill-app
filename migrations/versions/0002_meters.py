"""add meters table

Revision ID: 0002_meters
Revises: 0001_initial
Create Date: 2026-01-26
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "0002_meters"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "meters",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("serial_number", sa.String(length=50), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("serial_number", name="uq_meters_serial_number"),
    )
    op.create_index("ix_meters_id", "meters", ["id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_meters_id", table_name="meters")
    op.drop_table("meters")
