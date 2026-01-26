"""create cycles table

Revision ID: 0004
Revises: 0003
Create Date: 2026-01-26

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '0004_cycles'
down_revision: Union[str, None] = '0003_meter_assignments'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create cycles table with state machine constraints"""
    
    # Create enum type for cycle status
    op.execute("""
        CREATE TYPE cyclestatus AS ENUM (
            'OPEN', 'PENDING_REVIEW', 'APPROVED', 'CLOSED', 'ARCHIVED'
        )
    """)
    
    # Create cycles table
    op.create_table(
        'cycles',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('end_date', sa.Date(), nullable=False),
        sa.Column('target_date', sa.Date(), nullable=False, comment='Deadline for reading submissions'),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='OPEN'),
        sa.Column('created_at', sa.Date(), nullable=False, server_default=sa.text('CURRENT_DATE')),
        sa.Column('updated_at', sa.Date(), nullable=False, server_default=sa.text('CURRENT_DATE')),
        sa.PrimaryKeyConstraint('id', name='pk_cycles'),
        sa.CheckConstraint('start_date < end_date', name='ck_cycle_dates_valid'),
        sa.CheckConstraint('target_date >= start_date', name='ck_cycle_target_after_start'),
        sa.CheckConstraint('target_date <= end_date', name='ck_cycle_target_before_end'),
        sa.CheckConstraint(
            "status IN ('OPEN', 'PENDING_REVIEW', 'APPROVED', 'CLOSED', 'ARCHIVED')",
            name='ck_cycle_status_valid'
        )
    )
    
    # Create indexes
    op.create_index('ix_cycles_id', 'cycles', ['id'])
    op.create_index('ix_cycles_start_date', 'cycles', ['start_date'])
    op.create_index('ix_cycles_end_date', 'cycles', ['end_date'])
    op.create_index('ix_cycles_status', 'cycles', ['status'])


def downgrade() -> None:
    """Drop cycles table and enum type"""
    op.drop_index('ix_cycles_status', table_name='cycles')
    op.drop_index('ix_cycles_end_date', table_name='cycles')
    op.drop_index('ix_cycles_start_date', table_name='cycles')
    op.drop_index('ix_cycles_id', table_name='cycles')
    op.drop_table('cycles')
    op.execute('DROP TYPE cyclestatus')
