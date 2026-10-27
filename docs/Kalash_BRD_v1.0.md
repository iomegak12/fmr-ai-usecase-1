# Business Requirements Document
## Kalash – Savings Goal Planner (Release 1)

---

## 1. Document Control

| Item | Details |
|---|---|
| Document Title | Business Requirements Document – Kalash Savings Goal Planner |
| Product | Kalash |
| Release | Release 1 |
| Prepared By | Kalash Financial Services |
| Prepared For | [Client Name] |
| Version | 1.0 – Draft for Review |
| Date | 26 October 2026 |
| Status | Draft for Review |

---

## 2. Executive Summary

Kalash is a savings goal planner for retail customers. It helps customers set clear savings goals, record what they save, and see how close they are to each goal.

Release 1 focuses on the essentials. Customers can:

- create and manage multiple goals
- record deposits and withdrawals against each goal
- see their progress and the suggested monthly saving for each goal
- be alerted visually when a goal falls behind schedule

Release 1 is a planning and tracking product. It records the customer's savings activity and does not move money or connect to bank accounts.

We kindly request the client's review of this document, along with a decision on the open item listed in Section 17.

---

## 3. Business Background and Problem Statement

Many retail customers want to save for specific goals, such as a new phone, a holiday or an emergency fund. In practice, they often face the following challenges:

- Savings are kept as one general amount, so it is hard to see how much belongs to each goal.
- Customers are unsure how much they need to save each month to reach a goal on time.
- Customers often realise too late that they have fallen behind.
- Many existing options are tied to a specific bank account or investment product, which can feel complex for simple goal tracking.

Kalash addresses these challenges with a simple, focused way to plan and track savings goals.

---

## 4. Product Vision and Objectives

### 4.1 Vision

To help every customer turn their savings intentions into achieved goals, one deposit at a time.

### 4.2 Objectives for Release 1

1. Allow customers to create and manage multiple savings goals.
2. Allow customers to record deposits and withdrawals against each goal.
3. Show clear progress for every goal.
4. Guide customers on how much to save each month to stay on track.
5. Highlight goals that are behind schedule or past their target date.
6. Keep the experience simple, accurate and easy to understand.

---

## 5. Business Value and Advantages

### 5.1 Value to Customers

- **Clarity:** Each goal has its own target, balance and progress, so customers always know where they stand.
- **Guidance:** The suggested monthly saving turns a large target into a manageable monthly amount.
- **Early awareness:** The off-track and overdue indicators help customers correct course in good time.
- **Flexibility:** Customers can hold several goals at once and record savings at their own pace.
- **Simplicity:** No investment products, interest calculations or complex terms to understand.

### 5.2 Value to the Business

- **Focused first release:** Release 1 does not move money, which keeps it simple to deliver and lowers operational risk.
- **Customer engagement:** Goal tracking encourages customers to return regularly to record their progress.
- **Strong foundation:** Release 1 establishes the core goal and transaction model on which future capabilities can be built.
- **Brand positioning:** Kalash, meaning a sacred pot and a symbol of abundance, gives the product a culturally meaningful and memorable identity.

---

## 6. Market Position and Competitive Landscape

### 6.1 Market Overview

Goal-based saving is an established and growing category in India. Current offerings generally fall into three groups:

- **Micro-savings apps** that save small, frequent amounts into digital gold
- **Digital banking apps** that offer savings pots within a bank or prepaid account
- **Traditional banks** that offer goal-based recurring deposits to their own account holders

### 6.2 Competitor Overview

| Offering | Type | Key Characteristics |
|---|---|---|
| Jar | Micro-savings app | Daily, weekly or monthly savings into digital gold, including automatic round-ups on UPI payments. Also offers goal tracking. |
| Gullak | Micro-savings app | Automated digital gold savings plans, with the option to redeem savings as gold coins or jewellery. |
| Jupiter (Pots) | Digital banking app | Savings pots for short- and medium-term goals, with targets, progress tracking and flexible contributions. Requires an account with the platform. |
| ICICI Bank (iWish) | Traditional bank | A flexible, goal-based recurring deposit that earns interest. Available to ICICI Bank savings account holders. |

*Competitor information is based on publicly available sources as of October 2026.*

### 6.3 Kalash Positioning

Kalash is positioned as a **simple, independent goal planner** that puts clarity first.

- **Not tied to an investment product:** Customers can plan goals without having to buy gold or open a deposit.
- **Clear guidance:** Every goal shows the suggested monthly saving and whether it is on track, in plain terms.
- **Easy to start:** A focused set of features with a short learning curve.

### 6.4 Considerations

Several competitors offer automated saving, returns on savings, or direct money movement. Kalash Release 1 deliberately leaves these out so it can focus on planning and tracking. They may be considered for future releases, subject to the client's direction.

---

## 7. Stakeholders and Roles

| Stakeholder | Role |
|---|---|
| Retail Customer | The end user of Kalash. Creates and manages savings goals, records deposits and withdrawals, and tracks progress. |

---

## 8. Target Users

Kalash Release 1 is designed for **retail customers** in India who:

- want to save toward one or more personal goals
- prefer a simple way to track progress without investment complexity
- are comfortable using a digital application
- would benefit from guidance on how much to save each month

Young, digitally active customers are a key audience, and this is reflected in the product's modern and approachable identity.

---

## 9. Release 1 Scope

### 9.1 In Scope

| Area | Capabilities |
|---|---|
| Goal Management | Create, edit, cancel and delete goals; hold multiple goals at the same time |
| Deposits and Withdrawals | Record deposits and withdrawals; edit and delete transactions; view transaction history |
| Progress and Insights | Progress percentage and remaining amount; suggested monthly saving; off-track indicator; overdue indicator; overview of all goals |
| Currency | Indian Rupee (INR) only, in whole rupees |

### 9.2 Out of Scope

The following are not part of Release 1:

- Notifications, reminders and alerts outside the application
- Linking to real bank accounts or any real money movement
- Automatic or recurring deposits
- Interest or returns calculation
- Currencies other than INR
- Any other features not listed in Section 9.1

---

## 10. Goal Status Lifecycle

### 10.1 Goal Statuses

| Status | Description |
|---|---|
| Active | The goal is open. The customer can deposit, withdraw and edit. |
| Achieved | The balance has reached or exceeded the target amount. |
| Cancelled | The customer has closed the goal. It is kept for reference and cannot be changed. |

**Overdue** is an indicator, not a separate status. An overdue goal remains Active and is marked as overdue.

### 10.2 Status Transitions

| From | To | When |
|---|---|---|
| (New) | Active | The customer creates a goal |
| Active | Achieved | The balance reaches or exceeds the target amount, through a deposit or a transaction edit or deletion |
| Achieved | Active | A withdrawal brings the balance below the target amount |
| Achieved | Active | The customer raises the target amount above the current balance |
| Active | Cancelled | The customer cancels a goal with a balance of ₹0 |
| Cancelled | (Removed) | The customer permanently deletes the goal |

A Cancelled goal cannot return to Active.

---

## 11. Business Rules

### 11.1 Goals

| Rule ID | Rule |
|---|---|
| BR-01 | A customer may hold multiple goals at the same time. |
| BR-02 | Each goal must have a name, a target amount and a target date. |
| BR-03 | A goal name must be unique across all of the customer's goals, including Achieved and Cancelled goals. |
| BR-04 | The target amount must be in whole rupees and greater than ₹0. There is no upper limit. |
| BR-05 | The target date must be a future date, from the next day onward. This applies both when creating and when editing a goal. |
| BR-06 | When the target amount is edited, the new target must be greater than the goal's current balance. |

### 11.2 Deposits and Withdrawals

| Rule ID | Rule |
|---|---|
| BR-07 | All transaction amounts must be in Indian Rupees, in whole rupees, and greater than ₹0. |
| BR-08 | Deposits and withdrawals are records only. No real money is moved. |
| BR-09 | Each transaction is dated automatically with the current date. Past or future dates cannot be entered. |
| BR-10 | Deposits can be recorded only on Active goals. |
| BR-11 | A deposit larger than the remaining amount is accepted. The balance may then exceed the target amount. |
| BR-12 | Withdrawals can be recorded on Active and Achieved goals, up to the current balance. |
| BR-13 | Transactions can be edited or deleted only on Active goals. |
| BR-14 | No action may reduce a goal's balance below ₹0. |

### 11.3 Goal Status

| Rule ID | Rule |
|---|---|
| BR-15 | A goal becomes Achieved automatically when its balance reaches or exceeds the target amount. |
| BR-16 | An Achieved goal returns to Active when a withdrawal brings its balance below the target amount, or when the target amount is raised above the balance. |
| BR-17 | On an Achieved goal, only two actions are permitted: recording a withdrawal and raising the target amount. |
| BR-18 | A goal can be cancelled only when it is Active and its balance is ₹0. |
| BR-19 | A Cancelled goal is read-only and cannot be reactivated. |
| BR-20 | Only Cancelled goals can be permanently deleted. |
| BR-21 | An Active goal is marked Overdue when its target date has passed and its balance is below the target amount. An Overdue goal remains Active. The customer may continue to deposit, withdraw, edit (including setting a new target date) or cancel it. |

### 11.4 Progress and Insights

| Rule ID | Rule |
|---|---|
| BR-22 | Progress percentage = (balance ÷ target amount) × 100. Remaining amount = target amount − balance, shown as ₹0 when the target has been met or exceeded. |
| BR-23 | Suggested monthly saving = remaining amount ÷ months left until the target date, rounded up to the next whole rupee. If less than one month remains, or the goal is Overdue, the suggested monthly saving equals the full remaining amount. |
| BR-24 | An Active goal is marked Off-track when its progress percentage is lower than the percentage of time elapsed between its creation date and its target date. An Overdue goal is therefore always Off-track as well. |
| BR-25 | The overview lists all of the customer's goals, sorted by nearest target date first. |

---

## 12. Use Case User Stories

### Goal Management

#### KAL-BUC-00001 – Create a Savings Goal

**User Story:** As a retail customer, I want to create a savings goal with a name, target amount and target date, so that I can save with a clear purpose.

**Related Rules:** BR-01, BR-02, BR-03, BR-04, BR-05

**Acceptance Criteria:**

- **AC1 – Successful creation**
  - **Given** I enter a unique goal name, a target amount in whole rupees greater than ₹0, and a future target date
  - **When** I save the goal
  - **Then** the goal is created with a status of Active and a balance of ₹0
- **AC2 – Duplicate name**
  - **Given** I already have a goal with the same name, in any status
  - **When** I try to save the new goal
  - **Then** the goal is not created and I am informed that the name is already in use
- **AC3 – Invalid target amount**
  - **Given** I enter a target amount of ₹0 or less, or an amount with paise
  - **When** I try to save the goal
  - **Then** the goal is not created and I am informed of the correct amount format
- **AC4 – Invalid target date**
  - **Given** I enter today's date or a past date as the target date
  - **When** I try to save the goal
  - **Then** the goal is not created and I am informed that the target date must be a future date
- **AC5 – Multiple goals**
  - **Given** I already have one or more goals
  - **When** I create another valid goal
  - **Then** the new goal is added alongside my existing goals

---

#### KAL-BUC-00002 – Edit a Savings Goal

**User Story:** As a retail customer, I want to edit my goal's details, so that the goal reflects my current plans.

**Related Rules:** BR-03, BR-04, BR-05, BR-06, BR-16, BR-17

**Acceptance Criteria:**

- **AC1 – Edit an Active goal**
  - **Given** I have an Active goal
  - **When** I change its name, target amount or target date to valid values
  - **Then** the changes are saved
- **AC2 – Target below or equal to balance**
  - **Given** I have an Active goal with a balance of ₹5,000
  - **When** I try to change the target amount to ₹5,000 or less
  - **Then** the change is not saved and I am informed that the target must be greater than the current balance
- **AC3 – Raise target on an Achieved goal**
  - **Given** I have an Achieved goal
  - **When** I raise the target amount above the current balance
  - **Then** the change is saved and the goal returns to Active
- **AC4 – Other edits on an Achieved goal**
  - **Given** I have an Achieved goal
  - **When** I try to change its name or target date
  - **Then** the change is not permitted
- **AC5 – Edit a Cancelled goal**
  - **Given** I have a Cancelled goal
  - **When** I try to edit it
  - **Then** the change is not permitted, as Cancelled goals are read-only

---

#### KAL-BUC-00003 – Cancel a Savings Goal

**User Story:** As a retail customer, I want to cancel a goal I no longer wish to pursue, so that it stops appearing as an open goal while remaining available for reference.

**Related Rules:** BR-18, BR-19

**Acceptance Criteria:**

- **AC1 – Successful cancellation**
  - **Given** I have an Active goal with a balance of ₹0
  - **When** I cancel the goal
  - **Then** its status changes to Cancelled and it becomes read-only
- **AC2 – Balance not zero**
  - **Given** I have an Active goal with a balance greater than ₹0
  - **When** I try to cancel the goal
  - **Then** the goal is not cancelled and I am informed that the balance must first be withdrawn to ₹0
- **AC3 – No reactivation**
  - **Given** I have a Cancelled goal
  - **When** I look for an option to reactivate it
  - **Then** no such option is available

---

#### KAL-BUC-00004 – Delete a Cancelled Goal

**User Story:** As a retail customer, I want to permanently delete a cancelled goal, so that I can keep my goal list tidy.

**Related Rules:** BR-20

**Acceptance Criteria:**

- **AC1 – Delete a Cancelled goal**
  - **Given** I have a Cancelled goal
  - **When** I delete the goal
  - **Then** the goal and its transaction history are permanently removed
- **AC2 – Delete a goal in another status**
  - **Given** I have an Active or Achieved goal
  - **When** I try to delete the goal
  - **Then** deletion is not permitted

---

### Deposits and Withdrawals

#### KAL-BUC-00005 – Record a Deposit

**User Story:** As a retail customer, I want to record an amount I have saved toward a goal, so that my progress stays up to date.

**Related Rules:** BR-07, BR-08, BR-09, BR-10, BR-11, BR-15

**Acceptance Criteria:**

- **AC1 – Successful deposit**
  - **Given** I have an Active goal
  - **When** I record a deposit in whole rupees greater than ₹0
  - **Then** the deposit is recorded with today's date and the goal balance increases by that amount
- **AC2 – Deposit reaches the target**
  - **Given** I have an Active goal with a target of ₹10,000 and a balance of ₹9,000
  - **When** I record a deposit of ₹1,000 or more
  - **Then** the deposit is accepted and the goal becomes Achieved
- **AC3 – Deposit on an Achieved or Cancelled goal**
  - **Given** I have an Achieved or Cancelled goal
  - **When** I try to record a deposit
  - **Then** the deposit is not permitted
- **AC4 – Invalid amount**
  - **Given** I have an Active goal
  - **When** I enter a deposit of ₹0 or less, or an amount with paise
  - **Then** the deposit is not recorded and I am informed of the correct amount format

---

#### KAL-BUC-00006 – Record a Withdrawal

**User Story:** As a retail customer, I want to record a withdrawal from a goal, so that my balance reflects money I have taken out.

**Related Rules:** BR-07, BR-08, BR-09, BR-12, BR-14, BR-16

**Acceptance Criteria:**

- **AC1 – Successful withdrawal**
  - **Given** I have an Active goal with a balance of ₹4,000
  - **When** I record a withdrawal of ₹4,000 or less, in whole rupees
  - **Then** the withdrawal is recorded with today's date and the balance decreases by that amount
- **AC2 – Withdrawal exceeds balance**
  - **Given** I have a goal with a balance of ₹4,000
  - **When** I try to withdraw more than ₹4,000
  - **Then** the withdrawal is not recorded and I am informed that it cannot exceed the current balance
- **AC3 – Withdrawal from an Achieved goal, balance falls below target**
  - **Given** I have an Achieved goal with a target of ₹10,000 and a balance of ₹10,000
  - **When** I record a withdrawal of ₹1,000
  - **Then** the balance becomes ₹9,000 and the goal returns to Active
- **AC4 – Withdrawal from an Achieved goal, balance stays at or above target**
  - **Given** I have an Achieved goal with a target of ₹10,000 and a balance of ₹12,000
  - **When** I record a withdrawal of ₹2,000 or less
  - **Then** the goal remains Achieved
- **AC5 – Withdrawal from a Cancelled goal**
  - **Given** I have a Cancelled goal
  - **When** I try to record a withdrawal
  - **Then** the withdrawal is not permitted

---

#### KAL-BUC-00007 – Edit a Transaction

**User Story:** As a retail customer, I want to correct the amount of a deposit or withdrawal I entered by mistake, so that my balance is accurate.

**Related Rules:** BR-07, BR-13, BR-14, BR-15

**Acceptance Criteria:**

- **AC1 – Successful edit**
  - **Given** I have a deposit or withdrawal on an Active goal
  - **When** I change its amount to a valid whole-rupee amount greater than ₹0
  - **Then** the change is saved and the goal balance is recalculated
- **AC2 – Edit would make the balance negative**
  - **Given** I have an Active goal
  - **When** I edit a transaction in a way that would bring the balance below ₹0
  - **Then** the change is not saved and I am informed why
- **AC3 – Edit reaches the target**
  - **Given** I have an Active goal
  - **When** I edit a transaction so that the balance reaches or exceeds the target amount
  - **Then** the change is saved and the goal becomes Achieved
- **AC4 – Edit on a goal that is not Active**
  - **Given** I have an Achieved or Cancelled goal
  - **When** I try to edit one of its transactions
  - **Then** the change is not permitted

---

#### KAL-BUC-00008 – Delete a Transaction

**User Story:** As a retail customer, I want to delete a deposit or withdrawal I recorded in error, so that my history and balance are correct.

**Related Rules:** BR-13, BR-14, BR-15

**Acceptance Criteria:**

- **AC1 – Successful deletion**
  - **Given** I have a deposit or withdrawal on an Active goal
  - **When** I delete it
  - **Then** it is removed from the history and the goal balance is recalculated
- **AC2 – Deletion would make the balance negative**
  - **Given** I have an Active goal
  - **When** I try to delete a deposit and doing so would bring the balance below ₹0
  - **Then** the deletion is not permitted and I am informed why
- **AC3 – Deletion reaches the target**
  - **Given** I have an Active goal
  - **When** I delete a withdrawal and the balance then reaches or exceeds the target amount
  - **Then** the deletion is saved and the goal becomes Achieved
- **AC4 – Deletion on a goal that is not Active**
  - **Given** I have an Achieved or Cancelled goal
  - **When** I try to delete one of its transactions
  - **Then** the deletion is not permitted

---

#### KAL-BUC-00009 – View Transaction History

**User Story:** As a retail customer, I want to see all deposits and withdrawals for a goal, so that I understand how my balance has changed.

**Related Rules:** BR-09, BR-19

**Acceptance Criteria:**

- **AC1 – View history**
  - **Given** I have a goal with recorded transactions
  - **When** I open its transaction history
  - **Then** I see each transaction's type (deposit or withdrawal), amount and date
- **AC2 – No transactions**
  - **Given** I have a goal with no recorded transactions
  - **When** I open its transaction history
  - **Then** I am informed that no transactions have been recorded yet
- **AC3 – Cancelled goal history**
  - **Given** I have a Cancelled goal
  - **When** I open its transaction history
  - **Then** I can view it but cannot change it

---

### Progress and Insights

#### KAL-BUC-00010 – View Goal Progress

**User Story:** As a retail customer, I want to see how much of my goal I have saved and how much remains, so that I know how close I am.

**Related Rules:** BR-22

**Acceptance Criteria:**

- **AC1 – Progress shown**
  - **Given** I have a goal with a target of ₹20,000 and a balance of ₹5,000
  - **When** I view the goal
  - **Then** I see a progress of 25% and a remaining amount of ₹15,000
- **AC2 – Target met or exceeded**
  - **Given** I have a goal with a balance equal to or greater than its target
  - **When** I view the goal
  - **Then** the remaining amount is shown as ₹0

---

#### KAL-BUC-00011 – View Suggested Monthly Saving

**User Story:** As a retail customer, I want to see how much I should save each month, so that I can reach my goal on time.

**Related Rules:** BR-23

**Acceptance Criteria:**

- **AC1 – Suggested amount**
  - **Given** I have an Active goal with a remaining amount of ₹10,000 and 3 months left until the target date
  - **When** I view the goal
  - **Then** I see a suggested monthly saving of ₹3,334 (₹10,000 ÷ 3, rounded up to the next whole rupee)
- **AC2 – Less than one month left**
  - **Given** I have an Active goal with less than one month left until the target date
  - **When** I view the goal
  - **Then** the suggested monthly saving equals the full remaining amount
- **AC3 – Overdue goal**
  - **Given** I have an Overdue goal
  - **When** I view the goal
  - **Then** the suggested monthly saving equals the full remaining amount

---

#### KAL-BUC-00012 – Identify Off-track Goals

**User Story:** As a retail customer, I want to know when a goal is falling behind schedule, so that I can save more before it is too late.

**Related Rules:** BR-24

**Acceptance Criteria:**

- **AC1 – Goal is off-track**
  - **Given** I have an Active goal where 50% of the time to the target date has passed and my progress is 30%
  - **When** I view the goal
  - **Then** the goal is marked Off-track
- **AC2 – Goal is on track**
  - **Given** I have an Active goal where 50% of the time to the target date has passed and my progress is 50% or more
  - **When** I view the goal
  - **Then** the goal is not marked Off-track

---

#### KAL-BUC-00013 – Identify Overdue Goals

**User Story:** As a retail customer, I want to know when a goal has passed its target date without being reached, so that I can decide whether to extend it, keep saving or cancel it.

**Related Rules:** BR-05, BR-21

**Acceptance Criteria:**

- **AC1 – Goal becomes overdue**
  - **Given** I have an Active goal whose balance is below the target amount
  - **When** its target date passes
  - **Then** the goal remains Active and is marked Overdue
- **AC2 – Continue saving**
  - **Given** I have an Overdue goal
  - **When** I record a deposit
  - **Then** the deposit is accepted
- **AC3 – Extend the target date**
  - **Given** I have an Overdue goal
  - **When** I set a new future target date
  - **Then** the change is saved and the goal is no longer marked Overdue

---

#### KAL-BUC-00014 – View All-Goals Overview

**User Story:** As a retail customer, I want to see all my goals in one place, so that I can understand my overall savings position at a glance.

**Related Rules:** BR-01, BR-25

**Acceptance Criteria:**

- **AC1 – Overview content**
  - **Given** I have one or more goals
  - **When** I open the overview
  - **Then** I see every goal with its name, status, balance, target amount, progress and any Off-track or Overdue indicator
- **AC2 – Default order**
  - **Given** I have several goals with different target dates
  - **When** I open the overview
  - **Then** the goals are listed with the nearest target date first
- **AC3 – No goals**
  - **Given** I have not created any goals
  - **When** I open the overview
  - **Then** I am informed that no goals exist yet and invited to create one

---

### Goal Status

#### KAL-BUC-00015 – Automatic Goal Achievement

**User Story:** As a retail customer, I want my goal to be marked as achieved automatically when I reach the target, so that I can celebrate my progress without extra steps.

**Related Rules:** BR-11, BR-15, BR-17

**Acceptance Criteria:**

- **AC1 – Target reached**
  - **Given** I have an Active goal
  - **When** its balance reaches or exceeds the target amount
  - **Then** the goal status changes to Achieved automatically
- **AC2 – Actions on an Achieved goal**
  - **Given** I have an Achieved goal
  - **When** I view the available actions
  - **Then** only recording a withdrawal and raising the target amount are available

---

#### KAL-BUC-00016 – Return an Achieved Goal to Active

**User Story:** As a retail customer, I want an achieved goal to become active again when its balance falls below the target or I raise the target, so that the goal status always reflects reality.

**Related Rules:** BR-06, BR-16

**Acceptance Criteria:**

- **AC1 – After a withdrawal**
  - **Given** I have an Achieved goal
  - **When** a withdrawal brings its balance below the target amount
  - **Then** the goal returns to Active
- **AC2 – After raising the target**
  - **Given** I have an Achieved goal
  - **When** I raise the target amount above the current balance
  - **Then** the goal returns to Active

---

## 13. Non-Functional Expectations

| Area | Expectation |
|---|---|
| Usability | The application is simple and intuitive for retail customers, uses clear language, and shows helpful messages whenever an action cannot be completed. |
| Performance | Everyday actions, such as creating a goal, recording a transaction or opening the overview, respond quickly and feel immediate to the customer. |
| Data Accuracy | Balances, progress percentages, remaining amounts, suggested monthly savings and indicators are always calculated correctly and consistently, in line with the business rules in Section 11. |
| Data Privacy and Security | Customer goal and transaction data is protected from unauthorised access and is used only to provide the Kalash service. |

---

## 14. Success Metrics

| Metric | Description |
|---|---|
| Goals Created per Customer | The average number of goals created by each customer |
| Goal Achievement Rate | The share of goals that reach Achieved status |
| Monthly Active Customers | The number of customers who use Kalash at least once in a calendar month |
| Deposit Frequency | The average number of deposits recorded per goal per month |

---

## 15. Assumptions

1. Customers record their deposits and withdrawals themselves. Kalash does not verify them against any bank account.
2. Customers use Kalash to plan and track savings only. Their actual funds are held outside the application.
3. All amounts are in Indian Rupees and in whole rupees.
4. The current date is used for dating transactions and for determining Overdue goals and time elapsed.

---

## 16. Constraints

1. Release 1 supports Indian Rupees only.
2. Release 1 does not integrate with banks, payment systems or any external financial service.
3. Release 1 does not send notifications, reminders or alerts outside the application.
4. Release 1 does not support automatic or recurring deposits.
5. Release 1 does not calculate interest or returns.
6. Transactions cannot be backdated or future-dated.

---

## 17. Open Items for Client Decision

| Item | Description | Options |
|---|---|---|
| User Access | How customers will access Kalash in Release 1 | (a) Single user without sign-in; (b) Customer sign-up and login, with each customer's goals kept separate |

We would be grateful for the client's decision on this item so that the requirements can be finalised.

---

## 18. Glossary

| Term | Meaning |
|---|---|
| Goal | A savings target the customer is working toward, with a name, target amount and target date |
| Target Amount | The total amount the customer wishes to save for a goal |
| Target Date | The date by which the customer wishes to reach the target amount |
| Balance | The total of deposits minus withdrawals recorded for a goal |
| Deposit | A record of an amount the customer has saved toward a goal |
| Withdrawal | A record of an amount the customer has taken out of a goal |
| Transaction | A deposit or a withdrawal |
| Active | A goal that is open for deposits, withdrawals and edits |
| Achieved | A goal whose balance has reached or exceeded its target amount |
| Cancelled | A goal closed by the customer and kept for reference only |
| Overdue | An indicator on an Active goal whose target date has passed before the target was reached |
| Off-track | An indicator on an Active goal whose progress is behind the time elapsed |
| Suggested Monthly Saving | The amount the customer should save each month to reach the target on time |
| Release 1 | The first release of Kalash, as described in this document |

---

*End of Document*
