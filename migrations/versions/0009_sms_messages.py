"""create sms_messages and sms_delivery_history tables

Revision ID: 0009_sms_messages
Revises: 0008_audit_logs
Create Date: 2026-01-26

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '0009_sms_messages'
down_revision: Union[str, None] = '0008_audit_logs'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create SMS message tables with retry logic"""
    
    # Drop enums if they already exist (safe in dev environments, cascade removes dependent columns if any)
    op.execute("DROP TYPE IF EXISTS smsstatus CASCADE")
    op.execute("DROP TYPE IF EXISTS smsdeliverystatus CASCADE")
    
    # Ensure enums exist (idempotent)
    op.execute(
        """
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'smsstatus') THEN
                CREATE TYPE smsstatus AS ENUM ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'BOUNCED');
            END IF;
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'smsdeliverystatus') THEN
                CREATE TYPE smsdeliverystatus AS ENUM ('PENDING', 'SENT', 'DELIVERED', 'FAILED', 'RETRY_SCHEDULED');
            END IF;
        END$$;
        """
    )
    
    # Create sms_messages table
    op.create_table(
        'sms_messages',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('idempotency_key', sa.String(length=100), nullable=False),
        sa.Column('phone_number', sa.String(length=20), nullable=False),
        sa.Column('message_body', sa.Text(), nullable=False),
        sa.Column('sms_type', sa.String(length=50), nullable=False),
        sa.Column('client_id', sa.Integer(), nullable=False),
        sa.Column('meter_assignment_id', sa.Integer(), nullable=True),
        sa.Column('cycle_id', sa.Integer(), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='PENDING'),
        sa.Column('retry_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('max_retries', sa.Integer(), nullable=False, server_default='3'),
        sa.Column('last_attempt_at', sa.DateTime(), nullable=True),
        sa.Column('next_retry_at', sa.DateTime(), nullable=True),
        sa.Column('gateway_reference', sa.String(length=100), nullable=True),
        sa.Column('gateway_response', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('sent_at', sa.DateTime(), nullable=True),
        sa.Column('error_reason', sa.Text(), nullable=True),
        sa.Column('metadata', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['client_id'], ['clients.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['meter_assignment_id'], ['meter_assignments.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['cycle_id'], ['cycles.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create indexes for SMS messages
    op.create_index('ix_sms_messages_id', 'sms_messages', ['id'])
    op.create_index('ix_sms_messages_idempotency_key', 'sms_messages', ['idempotency_key'], unique=True)
    op.create_index('ix_sms_messages_phone_number', 'sms_messages', ['phone_number'])
    op.create_index('ix_sms_messages_client_id', 'sms_messages', ['client_id'])
    op.create_index('ix_sms_messages_status', 'sms_messages', ['status'])
    op.create_index('ix_sms_messages_next_retry_at', 'sms_messages', ['next_retry_at'])
    op.create_index('ix_sms_messages_created_at', 'sms_messages', ['created_at'])
    op.create_index('ix_sms_messages_gateway_reference', 'sms_messages', ['gateway_reference'], unique=True)
    
    # Create sms_delivery_history table
    op.create_table(
        'sms_delivery_history',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('sms_message_id', sa.Integer(), nullable=False),
        sa.Column('attempt_number', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(length=25), nullable=False, server_default='PENDING'),
        sa.Column('gateway_name', sa.String(length=50), nullable=True),
        sa.Column('gateway_request', sa.Text(), nullable=True),
        sa.Column('gateway_response', sa.Text(), nullable=True),
        sa.Column('gateway_status_code', sa.Integer(), nullable=True),
        sa.Column('callback_received', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('callback_status', sa.String(length=50), nullable=True),
        sa.Column('callback_received_at', sa.DateTime(), nullable=True),
        sa.Column('attempted_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('error_code', sa.String(length=50), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['sms_message_id'], ['sms_messages.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create indexes for delivery history
    op.create_index('ix_sms_delivery_history_id', 'sms_delivery_history', ['id'])
    op.create_index('ix_sms_delivery_history_sms_message_id', 'sms_delivery_history', ['sms_message_id'])
    op.create_index('ix_sms_delivery_history_status', 'sms_delivery_history', ['status'])
    op.create_index('ix_sms_delivery_history_attempted_at', 'sms_delivery_history', ['attempted_at'])


def downgrade() -> None:
    """Drop SMS tables"""
    op.drop_index('ix_sms_delivery_history_attempted_at', table_name='sms_delivery_history')
    op.drop_index('ix_sms_delivery_history_status', table_name='sms_delivery_history')
    op.drop_index('ix_sms_delivery_history_sms_message_id', table_name='sms_delivery_history')
    op.drop_index('ix_sms_delivery_history_id', table_name='sms_delivery_history')
    op.drop_table('sms_delivery_history')
    
    op.drop_index('ix_sms_messages_gateway_reference', table_name='sms_messages')
    op.drop_index('ix_sms_messages_created_at', table_name='sms_messages')
    op.drop_index('ix_sms_messages_next_retry_at', table_name='sms_messages')
    op.drop_index('ix_sms_messages_status', table_name='sms_messages')
    op.drop_index('ix_sms_messages_client_id', table_name='sms_messages')
    op.drop_index('ix_sms_messages_phone_number', table_name='sms_messages')
    op.drop_index('ix_sms_messages_idempotency_key', table_name='sms_messages')
    op.drop_index('ix_sms_messages_id', table_name='sms_messages')
    op.drop_table('sms_messages')
    
    op.execute('DROP TYPE smsdeliverystatus')
    op.execute('DROP TYPE smsstatus')
