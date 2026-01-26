"""add meter_assignments table

Revision ID: 0003_meter_assignments
Revises: 0002_meters
Create Date: 2026-01-26
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "0003_meter_assignments"
down_revision = "0002_meters"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "meter_assignments",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("meter_id", sa.Integer(), nullable=False),
        sa.Column("client_id", sa.Integer(), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column(
            "status",
            sa.Enum("ACTIVE", "INACTIVE", name="assignmentstatus"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["meter_id"], ["meters.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["client_id"], ["clients.id"], ondelete="RESTRICT"),
        sa.CheckConstraint("start_date IS NOT NULL", name="ck_assignment_start_date"),
        sa.CheckConstraint(
            "(end_date IS NULL AND status = 'ACTIVE') OR (end_date IS NOT NULL AND status = 'INACTIVE')",
            name="ck_assignment_active_no_end_date",
        ),
    )
    op.create_index(
        "ix_meter_assignments_id", "meter_assignments", ["id"], unique=False
    )
    op.create_index(
        "ix_meter_assignments_meter_id", "meter_assignments", ["meter_id"], unique=False
    )
    op.create_index(
        "ix_meter_assignments_client_id",
        "meter_assignments",
        ["client_id"],
        unique=False,
    )
    # Partial unique index: only one ACTIVE assignment per meter
    op.execute(
        """
        CREATE UNIQUE INDEX ix_meter_assignments_active 
        ON meter_assignments (meter_id, status) 
        WHERE status = 'ACTIVE'
        """
    )


def downgrade() -> None:
    op.drop_index("ix_meter_assignments_active", table_name="meter_assignments")
    op.drop_index("ix_meter_assignments_client_id", table_name="meter_assignments")
    op.drop_index("ix_meter_assignments_meter_id", table_name="meter_assignments")
    op.drop_index("ix_meter_assignments_id", table_name="meter_assignments")
    op.drop_table("meter_assignments")
    op.execute("DROP TYPE assignmentstatus")
