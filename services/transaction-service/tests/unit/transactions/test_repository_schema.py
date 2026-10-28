from unittest.mock import MagicMock
from uuid import uuid4

import pytest
from pydantic import ValidationError
from sqlalchemy import inspect
from sqlalchemy.dialects import postgresql

from app.transactions.models import Transaction
from app.transactions.repository import TransactionRepository
from app.transactions.schemas import CreateTransactionRequest, UpdateTransactionRequest


@pytest.mark.parametrize("value", [0, -1, 1.0, 1.5, "1", True, None, 2**63])
def test_amounts_are_strict_positive_bigints(value):
    with pytest.raises(ValidationError):
        CreateTransactionRequest(goalId=uuid4(), type="DEPOSIT", amount=value)
    with pytest.raises(ValidationError):
        UpdateTransactionRequest(amount=value)


def test_unknown_or_immutable_fields_rejected_and_upper_bound_allowed():
    assert UpdateTransactionRequest(amount=2**63 - 1).amount == 2**63 - 1
    for values in (
        {},
        {"amount": 1, "transactionDate": "2027-01-01"},
        {"amount": 1, "type": "DEPOSIT"},
    ):
        with pytest.raises(ValidationError):
            UpdateTransactionRequest(**values)
    with pytest.raises(ValidationError):
        CreateTransactionRequest(goalId=uuid4(), type="UNKNOWN", amount=1)


def test_model_has_optimistic_locking_and_no_cross_database_foreign_key():
    mapper = inspect(Transaction)
    assert mapper.version_id_col.name == "version"
    assert not Transaction.__table__.foreign_keys
    assert Transaction.__table__.c.amount.type.python_type is int
    assert {"transactions_amount_check", "transactions_type_check"} <= {
        constraint.name for constraint in Transaction.__table__.constraints
    }


async def test_history_query_filters_orders_and_pages_with_orm(session):
    goal = uuid4()
    session.scalar.return_value = 0
    session.scalars.return_value = MagicMock(all=MagicMock(return_value=[]))
    assert await TransactionRepository(session).history(goal, 2, 20) == ([], 0)
    query = session.scalars.await_args.args[0]
    compiled = query.compile(dialect=postgresql.dialect())
    assert "created_at DESC, transactions.transaction_id DESC" in str(compiled)
    assert goal in compiled.params.values()
    assert 40 in compiled.params.values() and 20 in compiled.params.values()


async def test_missing_count_is_an_error_not_empty_success(session):
    session.scalar.return_value = None
    with pytest.raises(RuntimeError, match="no result"):
        await TransactionRepository(session).history(uuid4(), 0, 20)
