CREATE TABLE goals (
    goal_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    target_amount BIGINT NOT NULL,
    target_date DATE NOT NULL,
    balance BIGINT NOT NULL DEFAULT 0,
    status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE',
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_goals PRIMARY KEY (goal_id),
    CONSTRAINT goals_target_amount_check CHECK (target_amount > 0),
    CONSTRAINT goals_balance_check CHECK (balance >= 0),
    CONSTRAINT goals_status_check CHECK (status IN ('ACTIVE', 'ACHIEVED', 'CANCELLED'))
);

CREATE UNIQUE INDEX ux_goals_name_ci ON goals (lower(btrim(name)));
CREATE INDEX ix_goals_target_date ON goals (target_date, created_at);
