"""create anomalies and conflicts tables

Revision ID: 0006
Revises: 0005
Create Date: 2026-01-26

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '0006'
down_revision: Union[str, None] = '0005'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create anomalies and conflicts tables for audit trail and conflict resolution"""
    
    # Create anomalies table
    op.create_table(
        'anomalies',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('anomaly_type', sa.String(length=50), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=False),
        sa.Column('severity', sa.String(length=20), nullable=False, server_default='INFO'),
        sa.Column('meter_assignment_id', sa.Integer(), nullable=False),
        sa.Column('cycle_id', sa.Integer(), nullable=False),
        sa.Column('reading_id', sa.Integer(), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='DETECTED'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('acknowledged_at', sa.DateTime(), nullable=True),
        sa.Column('acknowledged_by', sa.String(length=100), nullable=True, comment='Admin ID who acknowledged'),
        sa.Column('resolved_at', sa.DateTime(), nullable=True),
        sa.Column('resolved_by', sa.String(length=100), nullable=True, comment='Admin ID who resolved'),
        sa.Column('resolution_notes', sa.String(length=500), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['meter_assignment_id'], ['meter_assignments.id'], name='fk_anomalies_meter_assignment', ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['cycle_id'], ['cycles.id'], name='fk_anomalies_cycle', ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['reading_id'], ['readings.id'], name='fk_anomalies_reading', ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id', name='pk_anomalies'),
        sa.CheckConstraint(
            "anomaly_type IN ('NEGATIVE_CONSUMPTION', 'DOUBLE_SUBMISSION', 'LATE_SUBMISSION', "
            "'MISSING_BASELINE', 'MISSING_READING', 'ROLLOVER_WITHOUT_LIMIT')",
            name='ck_anomaly_type_valid'
        ),
        sa.CheckConstraint("severity IN ('INFO', 'WARNING', 'CRITICAL')", name='ck_anomaly_severity_valid'),
        sa.CheckConstraint("status IN ('DETECTED', 'ACKNOWLEDGED', 'RESOLVED')", name='ck_anomaly_status_valid'),
        sa.CheckConstraint(
            "(status = 'DETECTED' AND acknowledged_at IS NULL AND acknowledged_by IS NULL) OR "
            "(status IN ('ACKNOWLEDGED', 'RESOLVED') AND acknowledged_at IS NOT NULL AND acknowledged_by IS NOT NULL)",
            name='ck_anomaly_ack_consistency'
        ),
        sa.CheckConstraint(
            "(status != 'RESOLVED') OR (resolved_at IS NOT NULL AND resolved_by IS NOT NULL)",
            name='ck_anomaly_resolution_consistency'
        )
    )
    
    # Create conflicts table
    op.create_table(
        'conflicts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('conflict_type', sa.String(length=50), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=False),
        sa.Column('severity', sa.String(length=20), nullable=False, server_default='MEDIUM'),
        sa.Column('meter_assignment_id', sa.Integer(), nullable=False),
        sa.Column('cycle_id', sa.Integer(), nullable=True),
        sa.Column('reading_id', sa.Integer(), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='OPEN'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.Column('assigned_to', sa.String(length=100), nullable=True, comment='Admin email/ID assigned to resolve'),
        sa.Column('assigned_at', sa.DateTime(), nullable=True),
        sa.Column('resolved_at', sa.DateTime(), nullable=True),
        sa.Column('resolved_by', sa.String(length=100), nullable=True, comment='Admin ID who resolved'),
        sa.Column('resolution_notes', sa.String(length=500), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('now()')),
        sa.ForeignKeyConstraint(['meter_assignment_id'], ['meter_assignments.id'], name='fk_conflicts_meter_assignment', ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['cycle_id'], ['cycles.id'], name='fk_conflicts_cycle', ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['reading_id'], ['readings.id'], name='fk_conflicts_reading', ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id', name='pk_conflicts'),
        sa.CheckConstraint(
            "conflict_type IN ('READING_ROLLOVER', 'MISSING_BASELINE', 'DUPLICATE_READING', 'OUT_OF_WINDOW')",
            name='ck_conflict_type_valid'
        ),
        sa.CheckConstraint("severity IN ('LOW', 'MEDIUM', 'HIGH')", name='ck_conflict_severity_valid'),
        sa.CheckConstraint("status IN ('OPEN', 'ASSIGNED_TO_ADMIN', 'RESOLVED', 'ARCHIVED')", name='ck_conflict_status_valid'),
        sa.CheckConstraint(
            "(status = 'OPEN' AND assigned_to IS NULL AND assigned_at IS NULL) OR "
            "(status IN ('ASSIGNED_TO_ADMIN', 'RESOLVED', 'ARCHIVED') AND assigned_to IS NOT NULL AND assigned_at IS NOT NULL)",
            name='ck_conflict_assignment_consistency'
        ),
        sa.CheckConstraint(
            "(status != 'RESOLVED') OR (resolved_at IS NOT NULL AND resolved_by IS NOT NULL)",
            name='ck_conflict_resolution_consistency'
        )
    )
    
    # Create indexes
    op.create_index('ix_anomalies_id', 'anomalies', ['id'])
    op.create_index('ix_anomalies_meter_assignment_id', 'anomalies', ['meter_assignment_id'])
    op.create_index('ix_anomalies_cycle_id', 'anomalies', ['cycle_id'])
    op.create_index('ix_anomalies_status', 'anomalies', ['status'])
    
    op.create_index('ix_conflicts_id', 'conflicts', ['id'])
    op.create_index('ix_conflicts_meter_assignment_id', 'conflicts', ['meter_assignment_id'])
    op.create_index('ix_conflicts_cycle_id', 'conflicts', ['cycle_id'])
    op.create_index('ix_conflicts_status', 'conflicts', ['status'])


def downgrade() -> None:
    """Drop anomalies and conflicts tables"""
    op.drop_index('ix_conflicts_status', table_name='conflicts')
    op.drop_index('ix_conflicts_cycle_id', table_name='conflicts')
    op.drop_index('ix_conflicts_meter_assignment_id', table_name='conflicts')
    op.drop_index('ix_conflicts_id', table_name='conflicts')
    op.drop_table('conflicts')
    
    op.drop_index('ix_anomalies_status', table_name='anomalies')
    op.drop_index('ix_anomalies_cycle_id', table_name='anomalies')
    op.drop_index('ix_anomalies_meter_assignment_id', table_name='anomalies')
    op.drop_index('ix_anomalies_id', table_name='anomalies')
    op.drop_table('anomalies')
