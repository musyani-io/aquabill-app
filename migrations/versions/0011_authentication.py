"""Create admin_users and collector_users tables for authentication.

Revision ID: 0011_authentication
Revises: 0010_meter_assignment_max_value
Create Date: 2026-01-26 12:30:00.000000

"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "0011_authentication"
down_revision = "0010_meter_assignment_max_value"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create admin_users table
    op.create_table(
        "admin_users",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("username", sa.String(100), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("company_name", sa.String(255), nullable=False),
        sa.Column("company_phone", sa.String(20), nullable=False),
        sa.Column("role_at_company", sa.String(100), nullable=False),
        sa.Column("estimated_clients", sa.Integer(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("username", name="uq_admin_username"),
    )

    # Create collector_users table
    op.create_table(
        "collector_users",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("admin_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()
        ),
        sa.ForeignKeyConstraint(["admin_id"], ["admin_users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    # Create indexes
    op.create_index("ix_admin_users_username", "admin_users", ["username"])
    op.create_index("ix_collector_users_admin_id", "collector_users", ["admin_id"])


def downgrade() -> None:
    op.drop_index("ix_collector_users_admin_id", table_name="collector_users")
    op.drop_index("ix_admin_users_username", table_name="admin_users")
    op.drop_table("collector_users")
    op.drop_table("admin_users")
