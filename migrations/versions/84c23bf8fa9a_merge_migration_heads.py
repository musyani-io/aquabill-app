"""merge_migration_heads

Revision ID: 84c23bf8fa9a
Revises: 5c2251ae55eb, f9b153e088ae
Create Date: 2026-01-31 00:22:16.395374

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '84c23bf8fa9a'
down_revision = ('5c2251ae55eb', 'f9b153e088ae')
branch_labels = None
depends_on = None


def upgrade():
    pass


def downgrade():
    pass
