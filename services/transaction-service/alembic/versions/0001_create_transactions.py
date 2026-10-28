"""Create versioned transaction history (LLD Section 9.2, BR-07/09)."""

import sqlalchemy as sa

from alembic import op

revision = "0001_create_transactions"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create the table, last-line validation constraints and history index using op only."""
    op.create_table(
        "transactions",
        sa.Column("transaction_id", sa.Uuid(), nullable=False),
        sa.Column("goal_id", sa.Uuid(), nullable=False),
        sa.Column("type", sa.String(10), nullable=False),
        sa.Column("amount", sa.BigInteger(), nullable=False),
        sa.Column("transaction_date", sa.Date(), nullable=False),
        sa.Column("version", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.PrimaryKeyConstraint("transaction_id", name="pk_transactions"),
        sa.CheckConstraint("amount > 0", name="transactions_amount_check"),
        sa.CheckConstraint("type IN ('DEPOSIT', 'WITHDRAWAL')", name="transactions_type_check"),
    )
    op.create_index(
        "ix_transactions_goal_created", "transactions", ["goal_id", sa.column("created_at").desc()]
    )


def downgrade() -> None:
    """Remove only this revision's index and table; all transaction history is lost."""
    op.drop_index("ix_transactions_goal_created", table_name="transactions")
    op.drop_table("transactions")
