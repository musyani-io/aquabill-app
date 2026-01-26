"""create readings table with precision and baseline tracking

Revision ID: 0005
Revises: 0004
Create Date: 2026-01-26

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '0005_readings'
down_revision: Union[str, None] = '0004_cycles'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create readings table with precision and baseline enforcement"""
    
    # Create enum type for reading type
    op.execute("""
        CREATE TYPE readingtype AS ENUM (
            'BASELINE', 'NORMAL'
        )
    """)
    
    # Create readings table
    op.create_table(
        'readings',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('meter_assignment_id', sa.Integer(), nullable=False),
        sa.Column('cycle_id', sa.Integer(), nullable=False),
        sa.Column('absolute_value', sa.Numeric(precision=9, scale=4), nullable=False),
        sa.Column('type', sa.String(length=20), nullable=False, server_default='NORMAL'),
        sa.Column('consumption', sa.Numeric(precision=9, scale=4), nullable=True, comment='Difference from previous reading. NULL for BASELINE'),
        sa.Column('has_rollover', sa.Boolean(), nullable=False, server_default='false', comment='True if meter value wrapped/reset'),
        sa.Column('submitted_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('submitted_by', sa.String(length=100), nullable=False, comment='User/operator ID who submitted'),
        sa.Column('submission_notes', sa.String(length=500), nullable=True),
        sa.Column('approved', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('approved_at', sa.DateTime(), nullable=True),
        sa.Column('approved_by', sa.String(length=100), nullable=True, comment='Admin ID who approved'),
        sa.Column('approval_notes', sa.String(length=500), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['meter_assignment_id'], ['meter_assignments.id'], name='fk_readings_meter_assignment', ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['cycle_id'], ['cycles.id'], name='fk_readings_cycle', ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id', name='pk_readings'),
        sa.CheckConstraint('absolute_value >= 0', name='ck_reading_value_non_negative'),
        sa.CheckConstraint('consumption >= 0 OR consumption IS NULL', name='ck_reading_consumption_non_negative'),
        sa.CheckConstraint("type IN ('BASELINE', 'NORMAL')", name='ck_reading_type_valid'),
        sa.CheckConstraint(
            "(approved = true AND approved_at IS NOT NULL AND approved_by IS NOT NULL) OR "
            "(approved = false AND approved_at IS NULL AND approved_by IS NULL)",
            name='ck_reading_approval_consistency'
        )
    )
    
    # Create indexes
    op.create_index('ix_readings_id', 'readings', ['id'])
    op.create_index('ix_readings_meter_assignment_id', 'readings', ['meter_assignment_id'])
    op.create_index('ix_readings_cycle_id', 'readings', ['cycle_id'])
    op.create_index('ix_readings_approved', 'readings', ['approved'])


def downgrade() -> None:
    """Drop readings table and enum type"""
    op.drop_index('ix_readings_approved', table_name='readings')
    op.drop_index('ix_readings_cycle_id', table_name='readings')
    op.drop_index('ix_readings_meter_assignment_id', table_name='readings')
    op.drop_index('ix_readings_id', table_name='readings')
    op.drop_table('readings')
    op.execute('DROP TYPE readingtype')
