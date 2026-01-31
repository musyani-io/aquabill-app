"""add_cycle_target_date_override_fields

Revision ID: c5bfaead4c30
Revises: 84c23bf8fa9a
Create Date: 2026-01-31 00:22:24.780145

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'c5bfaead4c30'
down_revision = '84c23bf8fa9a'
branch_labels = None
depends_on = None


def upgrade():
    # Add new columns to cycles table
    op.add_column('cycles', sa.Column('proposed_target_date', sa.Date(), nullable=True,
                                      comment='Original proposed target date before admin override (NULL if no override)'))
    op.add_column('cycles', sa.Column('overridden_by', sa.String(length=100), nullable=True,
                                      comment='Admin username who overrode the target date (NULL if no override)'))
    op.add_column('cycles', sa.Column('override_reason', sa.String(length=500), nullable=True,
                                      comment='Reason for target date override (NULL if no override)'))


def downgrade():
    # Remove columns from cycles table
    op.drop_column('cycles', 'override_reason')
    op.drop_column('cycles', 'overridden_by')
    op.drop_column('cycles', 'proposed_target_date')
