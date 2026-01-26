"""Initial schema with clients table

Revision ID: 0001_initial
Revises:
Create Date: 2026-01-26
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "clients",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("first_name", sa.String(length=100), nullable=False),
        sa.Column("other_names", sa.String(length=100), nullable=True),
        sa.Column("surname", sa.String(length=100), nullable=False),
        sa.Column("phone_number", sa.String(length=20), nullable=False),
        sa.Column("client_code", sa.String(length=50), nullable=True),
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
        sa.UniqueConstraint("phone_number", name="uq_clients_phone_number"),
        sa.UniqueConstraint("client_code", name="uq_clients_client_code"),
    )
    op.create_index(
        "ix_clients_name", "clients", ["first_name", "surname"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_clients_name", table_name="clients")
    op.drop_table("clients")
