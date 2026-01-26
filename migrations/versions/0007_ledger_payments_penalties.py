"""create ledger, payments, penalties tables

Revision ID: 0007
Revises: 0006
Create Date: 2026-01-26

"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "0007_ledger_payments_penalties"
down_revision: Union[str, None] = "0006_anomalies_conflicts"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create ledger_entries, payments, penalties tables"""

    # ledger_entries
    op.create_table(
        "ledger_entries",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("meter_assignment_id", sa.Integer(), nullable=False),
        sa.Column("cycle_id", sa.Integer(), nullable=False),
        sa.Column(
            "entry_type", sa.String(length=20), nullable=False, server_default="CHARGE"
        ),
        sa.Column("amount", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column(
            "is_credit",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
            comment="True for credits (payments/adjustments)",
        ),
        sa.Column("description", sa.String(length=500), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")
        ),
        sa.Column(
            "created_by",
            sa.String(length=100),
            nullable=False,
            comment="Admin/user who recorded this entry",
        ),
        sa.ForeignKeyConstraint(
            ["meter_assignment_id"],
            ["meter_assignments.id"],
            name="fk_ledger_meter_assignment",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["cycle_id"], ["cycles.id"], name="fk_ledger_cycle", ondelete="RESTRICT"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_ledger_entries"),
        sa.CheckConstraint("amount >= 0", name="ck_ledger_amount_non_negative"),
        sa.CheckConstraint(
            "entry_type IN ('CHARGE', 'ADJUSTMENT', 'PAYMENT', 'PENALTY')",
            name="ck_ledger_type_valid",
        ),
    )
    op.create_index("ix_ledger_entries_id", "ledger_entries", ["id"])
    op.create_index(
        "ix_ledger_entries_meter_assignment_id",
        "ledger_entries",
        ["meter_assignment_id"],
    )
    op.create_index("ix_ledger_entries_cycle_id", "ledger_entries", ["cycle_id"])
    op.create_index("ix_ledger_entries_entry_type", "ledger_entries", ["entry_type"])

    # payments
    op.create_table(
        "payments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("client_id", sa.Integer(), nullable=False),
        sa.Column("meter_assignment_id", sa.Integer(), nullable=True),
        sa.Column("cycle_id", sa.Integer(), nullable=True),
        sa.Column("amount", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("reference", sa.String(length=100), nullable=True),
        sa.Column(
            "method",
            sa.String(length=50),
            nullable=True,
            comment="cash, mobile money, bank transfer",
        ),
        sa.Column("notes", sa.String(length=500), nullable=True),
        sa.Column(
            "recorded_by",
            sa.String(length=100),
            nullable=False,
            comment="User who recorded the payment",
        ),
        sa.Column(
            "received_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")
        ),
        sa.Column(
            "updated_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")
        ),
        sa.ForeignKeyConstraint(
            ["client_id"],
            ["clients.id"],
            name="fk_payments_client",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["meter_assignment_id"],
            ["meter_assignments.id"],
            name="fk_payments_meter_assignment",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["cycle_id"], ["cycles.id"], name="fk_payments_cycle", ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_payments"),
        sa.CheckConstraint("amount >= 0", name="ck_payment_amount_non_negative"),
    )
    op.create_index("ix_payments_id", "payments", ["id"])
    op.create_index("ix_payments_client_id", "payments", ["client_id"])
    op.create_index(
        "ix_payments_meter_assignment_id", "payments", ["meter_assignment_id"]
    )
    op.create_index("ix_payments_cycle_id", "payments", ["cycle_id"])
    op.create_index("ix_payments_reference", "payments", ["reference"])

    # penalties
    op.create_table(
        "penalties",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("meter_assignment_id", sa.Integer(), nullable=False),
        sa.Column("cycle_id", sa.Integer(), nullable=True),
        sa.Column("amount", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("reason", sa.String(length=200), nullable=False),
        sa.Column("notes", sa.String(length=500), nullable=True),
        sa.Column(
            "status", sa.String(length=20), nullable=False, server_default="APPLIED"
        ),
        sa.Column(
            "imposed_by",
            sa.String(length=100),
            nullable=False,
            comment="Admin who imposed the penalty",
        ),
        sa.Column(
            "imposed_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")
        ),
        sa.Column("waived_at", sa.DateTime(), nullable=True),
        sa.Column("waived_by", sa.String(length=100), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")
        ),
        sa.Column(
            "updated_at", sa.DateTime(), nullable=False, server_default=sa.text("now()")
        ),
        sa.ForeignKeyConstraint(
            ["meter_assignment_id"],
            ["meter_assignments.id"],
            name="fk_penalties_meter_assignment",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["cycle_id"], ["cycles.id"], name="fk_penalties_cycle", ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_penalties"),
        sa.CheckConstraint("amount >= 0", name="ck_penalty_amount_non_negative"),
        sa.CheckConstraint(
            "status IN ('APPLIED', 'WAIVED')", name="ck_penalty_status_valid"
        ),
        sa.CheckConstraint(
            "(status = 'APPLIED' AND waived_at IS NULL AND waived_by IS NULL) OR "
            "(status = 'WAIVED' AND waived_at IS NOT NULL AND waived_by IS NOT NULL)",
            name="ck_penalty_waive_consistency",
        ),
    )
    op.create_index("ix_penalties_id", "penalties", ["id"])
    op.create_index(
        "ix_penalties_meter_assignment_id", "penalties", ["meter_assignment_id"]
    )
    op.create_index("ix_penalties_cycle_id", "penalties", ["cycle_id"])
    op.create_index("ix_penalties_status", "penalties", ["status"])


def downgrade() -> None:
    """Drop ledger, payments, penalties tables"""
    op.drop_index("ix_penalties_status", table_name="penalties")
    op.drop_index("ix_penalties_cycle_id", table_name="penalties")
    op.drop_index("ix_penalties_meter_assignment_id", table_name="penalties")
    op.drop_index("ix_penalties_id", table_name="penalties")
    op.drop_table("penalties")

    op.drop_index("ix_payments_reference", table_name="payments")
    op.drop_index("ix_payments_cycle_id", table_name="payments")
    op.drop_index("ix_payments_meter_assignment_id", table_name="payments")
    op.drop_index("ix_payments_client_id", table_name="payments")
    op.drop_index("ix_payments_id", table_name="payments")
    op.drop_table("payments")

    op.drop_index("ix_ledger_entries_entry_type", table_name="ledger_entries")
    op.drop_index("ix_ledger_entries_cycle_id", table_name="ledger_entries")
    op.drop_index("ix_ledger_entries_meter_assignment_id", table_name="ledger_entries")
    op.drop_index("ix_ledger_entries_id", table_name="ledger_entries")
    op.drop_table("ledger_entries")
