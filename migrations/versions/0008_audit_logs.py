"""create audit_logs table

Revision ID: 0008_audit_logs
Revises: 0007_ledger_payments_penalties
Create Date: 2026-01-26

"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "0008_audit_logs"
down_revision: Union[str, None] = "0007_ledger_payments_penalties"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create audit_logs table - immutable append-only log"""
    op.create_table(
        "audit_logs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("admin_username", sa.String(length=100), nullable=False),
        sa.Column("admin_id", sa.String(length=100), nullable=True),
        sa.Column(
            "action",
            sa.Enum(
                "READING_APPROVED",
                "READING_REJECTED",
                "READING_EDITED",
                "READING_DELETED",
                "CYCLE_CREATED",
                "CYCLE_STATE_CHANGED",
                "CYCLE_APPROVED",
                "CYCLE_CLOSED",
                "CYCLE_ARCHIVED",
                "CONFLICT_RESOLVED",
                "CONFLICT_ASSIGNED",
                "ANOMALY_ACKNOWLEDGED",
                "PENALTY_APPLIED",
                "PENALTY_WAIVED",
                "PAYMENT_RECORDED",
                "LEDGER_ADJUSTMENT",
                "METER_ASSIGNED",
                "METER_UNASSIGNED",
                "METER_CREATED",
                "CLIENT_CREATED",
                "CLIENT_UPDATED",
                "CLIENT_DELETED",
                "DATA_EXPORTED",
                "BACKUP_CREATED",
                "SETTINGS_CHANGED",
                name="auditaction",
            ),
            nullable=False,
        ),
        sa.Column("entity_type", sa.String(length=50), nullable=False),
        sa.Column("entity_id", sa.Integer(), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("metadata", sa.Text(), nullable=True),
        sa.Column("ip_address", sa.String(length=45), nullable=True),
        sa.Column(
            "timestamp",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    # Create indexes for common queries
    op.create_index("ix_audit_logs_id", "audit_logs", ["id"])
    op.create_index("ix_audit_logs_admin_username", "audit_logs", ["admin_username"])
    op.create_index("ix_audit_logs_action", "audit_logs", ["action"])
    op.create_index("ix_audit_logs_entity_type", "audit_logs", ["entity_type"])
    op.create_index("ix_audit_logs_entity_id", "audit_logs", ["entity_id"])
    op.create_index("ix_audit_logs_timestamp", "audit_logs", ["timestamp"])

    # Composite index for entity lookups
    op.create_index(
        "ix_audit_logs_entity_type_entity_id",
        "audit_logs",
        ["entity_type", "entity_id"],
    )


def downgrade() -> None:
    """Drop audit_logs table"""
    op.drop_index("ix_audit_logs_entity_type_entity_id", table_name="audit_logs")
    op.drop_index("ix_audit_logs_timestamp", table_name="audit_logs")
    op.drop_index("ix_audit_logs_entity_id", table_name="audit_logs")
    op.drop_index("ix_audit_logs_entity_type", table_name="audit_logs")
    op.drop_index("ix_audit_logs_action", table_name="audit_logs")
    op.drop_index("ix_audit_logs_admin_username", table_name="audit_logs")
    op.drop_index("ix_audit_logs_id", table_name="audit_logs")
    op.drop_table("audit_logs")
    op.execute("DROP TYPE auditaction")
